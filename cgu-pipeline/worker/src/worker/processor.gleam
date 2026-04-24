import gleam/bit_array
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import shared/work_items as transport
import worker/archive_crawl
import worker/config.{type Config}
import worker/master_client

pub type FetchedArtifact {
  FetchedArtifact(
    fetched_url: String,
    status_code: Option(Int),
    content_type: Option(String),
    body: BitArray,
    metadata_json: String,
  )
}

pub type Outcome {
  Completed(FetchedArtifact)
  Failed(error: String, retryable: Bool, backoff_seconds: Float)
  LeaseLost(detail: String)
}

pub fn process(config: Config, item: transport.ClaimedWorkItem) -> Outcome {
  case item.kind {
    transport.SnapshotCurrent | transport.SnapshotArchive ->
      process_archive(config, item)
  }
}

fn process_archive(config: Config, item: transport.ClaimedWorkItem) -> Outcome {
  case archive_target_dates(item) {
    [] ->
      Failed(
        json_failure([
          #("case", json.string("missing_archive_date")),
          #(
            "summary",
            json.string("snapshot work item is missing archive_date"),
          ),
          #("work_item_id", json.string(item.work_item_id)),
          #("requested_url", json.string(item.url)),
        ]),
        False,
        0.0,
      )
    [archive_date, ..rest] ->
      process_archive_dates(config, item, archive_date, rest)
  }
}

fn process_archive_dates(
  config: Config,
  item: transport.ClaimedWorkItem,
  archive_date: String,
  remaining_dates: List(String),
) -> Outcome {
  case
    archive_crawl.crawl_with_controls(
      url: item.url,
      at: archive_date,
      max_visits: config.archive_max_visits,
      checkpoint: fn() { renew_lease(config, item) },
      acquire_provider_slot: fn(provider_key) {
        acquire_provider_slot(config, provider_key)
      },
      report_provider_status: fn(provider_key, status_code) {
        report_provider_status(config, provider_key, status_code)
      },
    )
  {
    Ok(report) ->
      case report.visit {
        [first, ..] ->
          case archive_status_code(first) {
            Some(429) -> rate_limited(config, item.url, archive_date, first)
            _ ->
              case archive_attempted(first) {
                True -> {
                  let body = archive_body(first)
                  case bit_array.byte_size(body) {
                    0 ->
                      case remaining_dates {
                        [] ->
                          archive_empty_result(item.url, archive_date, report)
                        [next_date, ..rest] ->
                          process_archive_dates(config, item, next_date, rest)
                      }
                    _ ->
                      Completed(FetchedArtifact(
                        fetched_url: archive_fetched_url(first),
                        status_code: archive_status_code(first),
                        content_type: archive_content_type(first),
                        body:,
                        metadata_json: json.object([
                          #(
                            "archive_crawl",
                            archive_crawl.report_to_json(report),
                          ),
                        ])
                          |> json.to_string,
                      ))
                  }
                }
                False ->
                  case remaining_dates {
                    [] -> archive_empty_result(item.url, archive_date, report)
                    [next_date, ..rest] ->
                      process_archive_dates(config, item, next_date, rest)
                  }
              }
          }

        [] -> archive_empty_result(item.url, archive_date, report)
      }

    Error(archive_crawl.InvalidSeedUrl) ->
      Failed(
        json_failure([
          #("case", json.string("invalid_archive_seed_url")),
          #("summary", json.string("archive seed URL is not a valid HTTP URL")),
          #("work_item_id", json.string(item.work_item_id)),
          #("requested_url", json.string(item.url)),
          #("requested_archive_date", json.string(archive_date)),
        ]),
        False,
        0.0,
      )

    Error(archive_crawl.InvalidLimit) ->
      Failed(
        json_failure([
          #("case", json.string("invalid_config")),
          #(
            "summary",
            json.string("WORKER_ARCHIVE_MAX_VISITS must be greater than zero"),
          ),
          #("config_key", json.string("WORKER_ARCHIVE_MAX_VISITS")),
          #("configured_value", json.int(config.archive_max_visits)),
          #("work_item_id", json.string(item.work_item_id)),
          #("requested_url", json.string(item.url)),
          #("requested_archive_date", json.string(archive_date)),
        ]),
        False,
        0.0,
      )

    Error(archive_crawl.CheckpointFailed(detail)) -> LeaseLost(detail)
  }
}

fn renew_lease(
  config: Config,
  item: transport.ClaimedWorkItem,
) -> Result(Nil, String) {
  case master_client.renew_lease(config, item.work_item_id, item.lease_id) {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(master_client.describe_error(error))
  }
}

fn acquire_provider_slot(
  config: Config,
  provider_key: String,
) -> Result(Nil, String) {
  case master_client.acquire_provider_slot(config, provider_key) {
    Ok(response) -> {
      case response.delay_ms > 0 {
        True -> process.sleep(response.delay_ms)
        False -> Nil
      }
      Ok(Nil)
    }
    Error(error) -> Error(master_client.describe_error(error))
  }
}

fn report_provider_status(
  config: Config,
  provider_key: String,
  status_code: Int,
) -> Result(Nil, String) {
  master_client.report_provider_status(config, provider_key, status_code)
  |> result.map_error(master_client.describe_error)
}

fn archive_target_dates(item: transport.ClaimedWorkItem) -> List(String) {
  case json.parse(item.metadata_json, target_dates_decoder()) {
    Ok([_, ..] as dates) -> dates
    _ ->
      case item.archive_date {
        Some(archive_date) -> [archive_date]
        None -> []
      }
  }
}

fn target_dates_decoder() -> decode.Decoder(List(String)) {
  use dates <- decode.field("target_dates", decode.list(decode.string))
  decode.success(dates)
}

fn archive_empty_result(
  url: String,
  archive_date: String,
  report: archive_crawl.CrawlReport,
) -> Outcome {
  Failed(archive_unavailable_error(url, archive_date, report), False, 0.0)
}

fn archive_attempted(visit: archive_crawl.Visit) -> Bool {
  case visit.fetch {
    archive_crawl.NotAttempted -> False
    _ -> True
  }
}

fn rate_limited(
  config: Config,
  url: String,
  archive_date: String,
  visit: archive_crawl.Visit,
) -> Outcome {
  let retry_after_seconds = archive_retry_after(visit)
  let backoff_seconds = case retry_after_seconds {
    Some(seconds) -> seconds
    None -> config.failure_backoff_seconds
  }

  Failed(
    json_failure([
      #("case", json.string("rate_limited")),
      #("summary", json.string("archive provider returned HTTP 429")),
      #("requested_url", json.string(url)),
      #("requested_archive_date", json.string(archive_date)),
      #("retry_after_seconds", option_json(retry_after_seconds, json.float)),
      #("backoff_seconds", json.float(backoff_seconds)),
      #("final_visit", archive_crawl.visit_to_json(visit)),
    ]),
    True,
    backoff_seconds,
  )
}

fn archive_unavailable_error(
  url: String,
  archive_date: String,
  report: archive_crawl.CrawlReport,
) -> String {
  let final_visit = list.last(report.visit)

  let final_visit_fields = case final_visit {
    Ok(visit) -> [
      #("summary", json.string(archive_failure_summary(visit))),
      #("final_visit", archive_crawl.visit_to_json(visit)),
    ]
    Error(Nil) -> [
      #("summary", json.string("archive crawl produced no visits")),
    ]
  }

  json_failure(list.append(
    [
      #("case", json.string("archive_unavailable")),
      #("requested_url", json.string(url)),
      #("requested_archive_date", json.string(archive_date)),
      #("archive_crawl", archive_crawl.report_to_json(report)),
    ],
    final_visit_fields,
  ))
}

fn archive_failure_summary(visit: archive_crawl.Visit) -> String {
  case visit.fetch {
    archive_crawl.NotAttempted -> archive_resolution_summary(visit.resolution)
    archive_crawl.ReplayedHtml(status, _, _, _) ->
      "archive replay returned HTML with HTTP "
      <> int.to_string(status)
      <> " but the response body was empty"
    archive_crawl.ReplayEscapedToLive(status, location, _) ->
      "archive replay escaped to live URL with HTTP "
      <> int.to_string(status)
      <> ": "
      <> location
    archive_crawl.ReplayRedirect(status, Some(location), _) ->
      "archive replay redirected with HTTP "
      <> int.to_string(status)
      <> ": "
      <> location
    archive_crawl.ReplayRedirect(status, None, _) ->
      "archive replay redirected with HTTP "
      <> int.to_string(status)
      <> " and no Location header"
    archive_crawl.ReplayNonHtml(status, content_type, _, body) ->
      "archive replay returned non-HTML HTTP "
      <> int.to_string(status)
      <> " content-type="
      <> option_string(content_type, "unknown")
      <> " body_bytes="
      <> int.to_string(bit_array.byte_size(body))
    archive_crawl.ReplayHttpError(status, content_type, _, body) ->
      "archive replay returned HTTP "
      <> int.to_string(status)
      <> " content-type="
      <> option_string(content_type, "unknown")
      <> " body_bytes="
      <> int.to_string(bit_array.byte_size(body))
    archive_crawl.ReplayTransportError(detail) ->
      "archive replay transport error: " <> detail
  }
}

fn archive_resolution_summary(
  resolution: archive_crawl.ArchiveResolution,
) -> String {
  case resolution {
    archive_crawl.SnapshotUnavailable(_) ->
      "archive lookup found no snapshot for the requested date"
    archive_crawl.InvalidArchiveDate(detail) ->
      "invalid archive date: " <> detail
    archive_crawl.LookupRequestBuildError(_) ->
      "could not build archive lookup request"
    archive_crawl.LookupHttpError(_, status) ->
      "archive lookup returned HTTP " <> int.to_string(status)
    archive_crawl.LookupTransportError(_, detail) ->
      "archive lookup transport error: " <> detail
    archive_crawl.LookupDecodeError(_, detail) ->
      "archive lookup decode error: " <> detail
    archive_crawl.LookupIncompleteSnapshot(_) ->
      "archive lookup response did not include a usable snapshot"
    archive_crawl.ExactPeriod(..)
    | archive_crawl.SameDayFallback(..)
    | archive_crawl.NearbyFallback(..) ->
      "archive snapshot was resolved but replay was not attempted"
  }
}

fn json_failure(fields: List(#(String, json.Json))) -> String {
  json.object(fields)
  |> json.to_string
}

fn option_json(value: Option(a), encode: fn(a) -> json.Json) -> json.Json {
  case value {
    Some(value) -> encode(value)
    None -> json.null()
  }
}

fn option_string(value: Option(String), default: String) -> String {
  case value {
    Some(value) -> value
    None -> default
  }
}

fn archive_fetched_url(visit: archive_crawl.Visit) -> String {
  case visit.fetch {
    archive_crawl.ReplayEscapedToLive(_, location, _) -> location
    archive_crawl.ReplayRedirect(_, Some(location), _) -> location
    _ -> archive_resolution_url(visit)
  }
}

fn archive_resolution_url(visit: archive_crawl.Visit) -> String {
  case visit.resolution {
    archive_crawl.ExactPeriod(snapshot, _) -> snapshot.replay_url
    archive_crawl.SameDayFallback(snapshot, _) -> snapshot.replay_url
    archive_crawl.NearbyFallback(snapshot, _) -> snapshot.replay_url
    _ -> visit.requested_url
  }
}

fn archive_status_code(visit: archive_crawl.Visit) -> Option(Int) {
  case visit.fetch {
    archive_crawl.NotAttempted -> None
    archive_crawl.ReplayedHtml(status, _, _, _) -> Some(status)
    archive_crawl.ReplayEscapedToLive(status, _, _) -> Some(status)
    archive_crawl.ReplayRedirect(status, _, _) -> Some(status)
    archive_crawl.ReplayNonHtml(status, _, _, _) -> Some(status)
    archive_crawl.ReplayHttpError(status, _, _, _) -> Some(status)
    archive_crawl.ReplayTransportError(_) -> None
  }
}

fn archive_content_type(visit: archive_crawl.Visit) -> Option(String) {
  case visit.fetch {
    archive_crawl.ReplayedHtml(_, content_type, _, _) -> content_type
    archive_crawl.ReplayNonHtml(_, content_type, _, _) -> content_type
    archive_crawl.ReplayHttpError(_, content_type, _, _) -> content_type
    _ -> None
  }
}

fn archive_retry_after(visit: archive_crawl.Visit) -> Option(Float) {
  case visit.fetch {
    archive_crawl.ReplayedHtml(_, _, retry_after_seconds, _) ->
      retry_after_seconds
    archive_crawl.ReplayEscapedToLive(_, _, retry_after_seconds) ->
      retry_after_seconds
    archive_crawl.ReplayRedirect(_, _, retry_after_seconds) ->
      retry_after_seconds
    archive_crawl.ReplayNonHtml(_, _, retry_after_seconds, _) ->
      retry_after_seconds
    archive_crawl.ReplayHttpError(_, _, retry_after_seconds, _) ->
      retry_after_seconds
    _ -> None
  }
}

fn archive_body(visit: archive_crawl.Visit) -> BitArray {
  case visit.fetch {
    archive_crawl.ReplayedHtml(_, _, _, archive_crawl.HtmlSnapshot(body:, ..)) ->
      body
    archive_crawl.ReplayNonHtml(_, _, _, body) -> body
    archive_crawl.ReplayHttpError(_, _, _, body) -> body
    _ -> <<>>
  }
}
