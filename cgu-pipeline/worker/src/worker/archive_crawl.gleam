import gleam/bit_array
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import presentable_soup as soup
import worker/retry_after

const wayback_availability_api = "https://archive.org/wayback/available"

const replay_host = "web.archive.org"

const arquivo_cdx_api = "https://arquivo.pt/wayback/cdx"

const arquivo_replay_prefix = "https://arquivo.pt/wayback/"

const archive_it_timemap_api = "https://wayback.archive-it.org/all/timemap/json/"

const archive_it_replay_prefix = "https://wayback.archive-it.org/all/"

const loc_timemap_api = "https://webarchive.loc.gov/all/timemap/json/"

const loc_replay_prefix = "https://webarchive.loc.gov/all/"

pub type ArchivePrecision {
  Year
  Month
  Day
  Hour
  Minute
  Second
}

pub type RequestedArchiveDate {
  RequestedArchiveDate(
    original: String,
    timestamp: String,
    precision: ArchivePrecision,
  )
}

pub type SnapshotRef {
  SnapshotRef(
    provider: String,
    original_url: String,
    lookup_url: String,
    alias_rule: String,
    replay_url: String,
    timestamp: String,
    availability_status: Option(String),
    distance_seconds: Option(Int),
  )
}

pub type ArchiveLookup {
  ArchiveLookup(url: String, alias_rule: String)
}

pub type ArchiveResolution {
  ExactPeriod(snapshot: SnapshotRef, request: RequestedArchiveDate)
  SameDayFallback(snapshot: SnapshotRef, request: RequestedArchiveDate)
  NearbyFallback(snapshot: SnapshotRef, request: RequestedArchiveDate)
  SnapshotUnavailable(request: RequestedArchiveDate)
  InvalidArchiveDate(detail: String)
  LookupRequestBuildError(request: RequestedArchiveDate)
  LookupHttpError(request: RequestedArchiveDate, status: Int)
  LookupTransportError(request: RequestedArchiveDate, detail: String)
  LookupDecodeError(request: RequestedArchiveDate, detail: String)
  LookupIncompleteSnapshot(request: RequestedArchiveDate)
}

pub type LinkRejection {
  MissingHref
  BlankHref
  UnsupportedHref(raw: String)
  InvalidBaseUrl(base_url: String)
  InvalidHref(raw: String)
  UnmergeableHref(raw: String)
}

pub type LinkExtraction {
  LinkExtractionSucceeded(url: List(String), rejected: List(LinkRejection))
  LinkExtractionParseError(soup.ScrapeError)
}

pub type HtmlSnapshot {
  HtmlSnapshot(body: BitArray, links: LinkExtraction)
}

pub type FetchOutcome {
  NotAttempted
  ReplayedHtml(
    status: Int,
    content_type: Option(String),
    retry_after_seconds: Option(Float),
    page: HtmlSnapshot,
  )
  ReplayEscapedToLive(
    status: Int,
    location: String,
    retry_after_seconds: Option(Float),
  )
  ReplayRedirect(
    status: Int,
    location: Option(String),
    retry_after_seconds: Option(Float),
  )
  ReplayNonHtml(
    status: Int,
    content_type: Option(String),
    retry_after_seconds: Option(Float),
    body: BitArray,
  )
  ReplayHttpError(
    status: Int,
    content_type: Option(String),
    retry_after_seconds: Option(Float),
    body: BitArray,
  )
  ReplayTransportError(detail: String)
}

pub type Visit {
  Visit(
    requested_url: String,
    resolution: ArchiveResolution,
    fetch: FetchOutcome,
  )
}

pub type CrawlReport {
  CrawlReport(
    requested_url: String,
    requested_archive_date: String,
    visit: List(Visit),
  )
}

pub type CrawlError {
  InvalidSeedUrl
  InvalidLimit
  CheckpointFailed(detail: String)
}

type AvailabilityClosest {
  AvailabilityClosest(
    available: Bool,
    status: Option(String),
    timestamp: Option(String),
    replay_url: Option(String),
  )
}

type ArchiveProvider {
  Wayback
  ArquivoPt
  ArchiveIt
  LibraryOfCongress
}

pub fn crawl(
  url requested_url: String,
  at archive_date: String,
  max_visits limit: Int,
) -> Result(CrawlReport, CrawlError) {
  crawl_with_checkpoint(
    url: requested_url,
    at: archive_date,
    max_visits: limit,
    checkpoint: fn() { Ok(Nil) },
  )
}

pub fn crawl_with_checkpoint(
  url requested_url: String,
  at archive_date: String,
  max_visits limit: Int,
  checkpoint checkpoint: fn() -> Result(Nil, String),
) -> Result(CrawlReport, CrawlError) {
  crawl_with_controls(
    url: requested_url,
    at: archive_date,
    max_visits: limit,
    checkpoint: checkpoint,
    acquire_provider_slot: fn(_) { Ok(Nil) },
    report_provider_status: fn(_, _) { Ok(Nil) },
  )
}

pub fn crawl_with_controls(
  url requested_url: String,
  at archive_date: String,
  max_visits limit: Int,
  checkpoint checkpoint: fn() -> Result(Nil, String),
  acquire_provider_slot acquire_provider_slot: fn(String) -> Result(Nil, String),
  report_provider_status report_provider_status: fn(String, Int) ->
    Result(Nil, String),
) -> Result(CrawlReport, CrawlError) {
  case limit <= 0 {
    True -> Error(InvalidLimit)
    False ->
      case uri.parse(requested_url) {
        Error(Nil) -> Error(InvalidSeedUrl)
        Ok(seed_uri) ->
          case uri.origin(seed_uri) {
            Error(Nil) -> Error(InvalidSeedUrl)
            Ok(origin) -> {
              use visits <- result.try(
                crawl_queue(
                  queue: [requested_url],
                  seen: [],
                  acc: [],
                  site_origin: origin,
                  archive_date: archive_date,
                  remaining: limit,
                  checkpoint: checkpoint,
                  acquire_provider_slot: acquire_provider_slot,
                  report_provider_status: report_provider_status,
                )
                |> result.map_error(CheckpointFailed),
              )

              Ok(CrawlReport(
                requested_url: requested_url,
                requested_archive_date: archive_date,
                visit: visits,
              ))
            }
          }
      }
  }
}

pub fn visit(url requested_url: String, at archive_date: String) -> Visit {
  let assert Ok(visit) =
    resolve_and_fetch_snapshot(
      requested_url,
      archive_date,
      checkpoint: fn() { Ok(Nil) },
      acquire_provider_slot: fn(_) { Ok(Nil) },
      report_provider_status: fn(_, _) { Ok(Nil) },
    )
  visit
}

pub fn report_to_json(report: CrawlReport) -> json.Json {
  json.object([
    #("requested_url", json.string(report.requested_url)),
    #("requested_archive_date", json.string(report.requested_archive_date)),
    #("visit", json.array(from: report.visit, of: visit_to_json)),
  ])
}

pub fn visit_to_json(visit: Visit) -> json.Json {
  json.object([
    #("requested_url", json.string(visit.requested_url)),
    #("resolution", archive_resolution_to_json(visit.resolution)),
    #("fetch", fetch_outcome_to_json(visit.fetch)),
  ])
}

fn crawl_queue(
  queue queue: List(String),
  seen seen: List(String),
  acc acc: List(Visit),
  site_origin site_origin: String,
  archive_date archive_date: String,
  remaining remaining: Int,
  checkpoint checkpoint: fn() -> Result(Nil, String),
  acquire_provider_slot acquire_provider_slot: fn(String) -> Result(Nil, String),
  report_provider_status report_provider_status: fn(String, Int) ->
    Result(Nil, String),
) -> Result(List(Visit), String) {
  case remaining, queue {
    0, _ -> Ok(list.reverse(acc))
    _, [] -> Ok(list.reverse(acc))
    _, [next, ..rest] -> {
      case list.contains(seen, next) {
        True ->
          crawl_queue(
            queue: rest,
            seen: seen,
            acc: acc,
            site_origin: site_origin,
            archive_date: archive_date,
            remaining: remaining,
            checkpoint: checkpoint,
            acquire_provider_slot: acquire_provider_slot,
            report_provider_status: report_provider_status,
          )

        False -> {
          use _ <- result.try(checkpoint())
          use current <- result.try(resolve_and_fetch_snapshot(
            next,
            archive_date,
            checkpoint:,
            acquire_provider_slot:,
            report_provider_status:,
          ))
          let discovered = next_urls(current, site_origin)
          let queue =
            append_unique(rest, discovered)
            |> drop_seen(seen)

          crawl_queue(
            queue: queue,
            seen: [next, ..seen],
            acc: [current, ..acc],
            site_origin: site_origin,
            archive_date: archive_date,
            remaining: remaining - 1,
            checkpoint: checkpoint,
            acquire_provider_slot: acquire_provider_slot,
            report_provider_status: report_provider_status,
          )
        }
      }
    }
  }
}

fn next_urls(visit: Visit, site_origin: String) -> List(String) {
  case visit.fetch {
    ReplayedHtml(page: HtmlSnapshot(links:, ..), ..) ->
      case links {
        LinkExtractionSucceeded(url:, rejected:) -> {
          let _ = rejected
          keep_same_site(url, site_origin)
          |> dedupe()
        }
        LinkExtractionParseError(_) -> []
      }
    _ -> []
  }
}

fn resolve_and_fetch_snapshot(
  requested_url: String,
  archive_date: String,
  checkpoint checkpoint: fn() -> Result(Nil, String),
  acquire_provider_slot acquire_provider_slot: fn(String) -> Result(Nil, String),
  report_provider_status report_provider_status: fn(String, Int) ->
    Result(Nil, String),
) -> Result(Visit, String) {
  case normalize_archive_date(archive_date) {
    Error(detail) ->
      Ok(Visit(
        requested_url:,
        resolution: InvalidArchiveDate(detail),
        fetch: NotAttempted,
      ))
    Ok(requested) ->
      visit_with_providers(
        requested_url,
        requested,
        [
          Wayback,
          ArquivoPt,
          ArchiveIt,
          LibraryOfCongress,
        ],
        checkpoint,
        acquire_provider_slot,
        report_provider_status,
      )
  }
}

fn visit_with_providers(
  original_url: String,
  requested: RequestedArchiveDate,
  providers: List(ArchiveProvider),
  checkpoint: fn() -> Result(Nil, String),
  acquire_provider_slot: fn(String) -> Result(Nil, String),
  report_provider_status: fn(String, Int) -> Result(Nil, String),
) -> Result(Visit, String) {
  case providers {
    [] ->
      Ok(Visit(
        requested_url: original_url,
        resolution: SnapshotUnavailable(requested),
        fetch: NotAttempted,
      ))

    [provider, ..rest] -> {
      use _ <- result.try(checkpoint())
      use _ <- result.try(acquire_provider_slot(provider_lookup_key(provider)))
      use resolution <- result.try(lookup_provider_snapshot(
        provider,
        original_url,
        requested,
        report_provider_status,
      ))
      use fetch <- result.try(fetch_resolution(
        resolution,
        acquire_provider_slot,
        report_provider_status,
      ))
      case should_accept_fetch(fetch) || should_stop_fallback(fetch) {
        True -> Ok(Visit(requested_url: original_url, resolution:, fetch:))
        False ->
          visit_with_providers(
            original_url,
            requested,
            rest,
            checkpoint,
            acquire_provider_slot,
            report_provider_status,
          )
      }
    }
  }
}

fn lookup_provider_snapshot(
  provider: ArchiveProvider,
  original_url: String,
  requested: RequestedArchiveDate,
  report_provider_status: fn(String, Int) -> Result(Nil, String),
) -> Result(ArchiveResolution, String) {
  lookup_provider_snapshot_candidates(
    provider,
    archive_lookup_candidates(original_url),
    requested,
    report_provider_status,
  )
}

fn lookup_provider_snapshot_candidates(
  provider: ArchiveProvider,
  candidates: List(ArchiveLookup),
  requested: RequestedArchiveDate,
  report_provider_status: fn(String, Int) -> Result(Nil, String),
) -> Result(ArchiveResolution, String) {
  case candidates {
    [] -> Ok(SnapshotUnavailable(requested))
    [lookup, ..rest] -> {
      use resolution <- result.try(lookup_provider_snapshot_candidate(
        provider,
        lookup,
        requested,
        report_provider_status,
      ))
      case resolution {
        SnapshotUnavailable(_) | LookupIncompleteSnapshot(_) ->
          lookup_provider_snapshot_candidates(
            provider,
            rest,
            requested,
            report_provider_status,
          )
        _ -> Ok(resolution)
      }
    }
  }
}

fn lookup_provider_snapshot_candidate(
  provider: ArchiveProvider,
  lookup: ArchiveLookup,
  requested: RequestedArchiveDate,
  report_provider_status: fn(String, Int) -> Result(Nil, String),
) -> Result(ArchiveResolution, String) {
  case provider {
    Wayback ->
      lookup_wayback_snapshot(
        lookup,
        requested,
        provider_lookup_key(provider),
        report_provider_status,
      )
    ArquivoPt ->
      lookup_memento_timemap_snapshot(
        lookup,
        requested,
        "arquivo.pt",
        arquivo_cdx_lookup_url(lookup.url, requested),
        arquivo_replay_prefix,
        provider_lookup_key(provider),
        report_provider_status,
      )
    ArchiveIt ->
      lookup_memento_timemap_snapshot(
        lookup,
        requested,
        "archive-it",
        archive_it_timemap_api <> lookup.url,
        archive_it_replay_prefix,
        provider_lookup_key(provider),
        report_provider_status,
      )
    LibraryOfCongress ->
      lookup_memento_timemap_snapshot(
        lookup,
        requested,
        "library-of-congress",
        loc_timemap_api <> lookup.url,
        loc_replay_prefix,
        provider_lookup_key(provider),
        report_provider_status,
      )
  }
}

fn should_accept_fetch(fetch: FetchOutcome) -> Bool {
  case fetch {
    ReplayedHtml(page: HtmlSnapshot(body:, ..), ..) ->
      bit_array.byte_size(body) > 0
    ReplayNonHtml(status, _, _, body) ->
      status != 429 && bit_array.byte_size(body) > 0
    ReplayHttpError(status, _, _, body) ->
      status != 429 && bit_array.byte_size(body) > 0
    _ -> False
  }
}

fn should_stop_fallback(fetch: FetchOutcome) -> Bool {
  case fetch {
    ReplayedHtml(status: 429, ..)
    | ReplayEscapedToLive(status: 429, ..)
    | ReplayRedirect(status: 429, ..)
    | ReplayNonHtml(status: 429, ..)
    | ReplayHttpError(status: 429, ..) -> True
    _ -> False
  }
}

fn provider_lookup_key(provider: ArchiveProvider) -> String {
  case provider {
    Wayback -> "wayback_lookup"
    ArquivoPt -> "arquivo_lookup"
    ArchiveIt -> "archive_it_lookup"
    LibraryOfCongress -> "loc_lookup"
  }
}

fn provider_replay_key(provider: String) -> String {
  case provider {
    "wayback" -> "wayback_replay"
    "arquivo.pt" -> "arquivo_replay"
    "archive-it" -> "archive_it_replay"
    "library-of-congress" -> "loc_replay"
    _ -> "wayback_replay"
  }
}

pub fn archive_lookup_candidates(original_url: String) -> List(ArchiveLookup) {
  let exact = ArchiveLookup(url: original_url, alias_rule: "exact")

  case uri.parse(original_url) {
    Error(Nil) -> [exact]
    Ok(parsed) -> {
      let canonical = canonical_uri(parsed)
      let candidates = [exact]
      let candidates = append_lookup(candidates, canonical, "canonical")
      let candidates =
        append_optional_lookup(
          candidates,
          toggle_scheme(canonical),
          "scheme_alias",
        )
      let candidates =
        append_optional_lookup(candidates, toggle_www(canonical), "www_alias")
      let candidates =
        append_optional_lookup(
          candidates,
          toggle_scheme(canonical)
            |> option_then(toggle_www),
          "scheme_and_www_alias",
        )

      dedupe_lookups(candidates, [], [])
    }
  }
}

fn canonical_uri(parsed: uri.Uri) -> uri.Uri {
  let uri.Uri(scheme:, host:, port:, ..) = parsed
  let scheme = option_map(scheme, string.lowercase)
  let host = option_map(host, string.lowercase)
  let port = case scheme, port {
    Some("http"), Some(80) -> None
    Some("https"), Some(443) -> None
    _, _ -> port
  }

  uri.Uri(..parsed, scheme:, host:, port:, fragment: None)
}

fn toggle_scheme(parsed: uri.Uri) -> Option(uri.Uri) {
  case parsed.scheme {
    Some("http") -> Some(uri.Uri(..parsed, scheme: Some("https")))
    Some("https") -> Some(uri.Uri(..parsed, scheme: Some("http")))
    _ -> None
  }
}

fn toggle_www(parsed: uri.Uri) -> Option(uri.Uri) {
  case parsed.host {
    Some(host) ->
      case string.starts_with(host, "www.") {
        True ->
          Some(
            uri.Uri(..parsed, host: Some(string.remove_prefix(host, "www."))),
          )
        False -> Some(uri.Uri(..parsed, host: Some("www." <> host)))
      }
    None -> None
  }
}

fn append_lookup(
  candidates: List(ArchiveLookup),
  parsed: uri.Uri,
  alias_rule: String,
) -> List(ArchiveLookup) {
  let candidates =
    list.append(candidates, [
      ArchiveLookup(url: uri.to_string(parsed), alias_rule: alias_rule),
    ])

  case root_path_alias(parsed) {
    Some(root_alias) ->
      list.append(candidates, [
        ArchiveLookup(
          url: uri.to_string(root_alias),
          alias_rule: alias_rule <> "_root_path",
        ),
      ])
    None -> candidates
  }
}

fn append_optional_lookup(
  candidates: List(ArchiveLookup),
  parsed: Option(uri.Uri),
  alias_rule: String,
) -> List(ArchiveLookup) {
  case parsed {
    Some(parsed) -> append_lookup(candidates, parsed, alias_rule)
    None -> candidates
  }
}

fn root_path_alias(parsed: uri.Uri) -> Option(uri.Uri) {
  case parsed.path {
    "" -> Some(uri.Uri(..parsed, path: "/"))
    "/" -> Some(uri.Uri(..parsed, path: ""))
    _ -> None
  }
}

fn dedupe_lookups(
  candidates: List(ArchiveLookup),
  seen: List(String),
  acc: List(ArchiveLookup),
) -> List(ArchiveLookup) {
  case candidates {
    [] -> list.reverse(acc)
    [candidate, ..rest] -> {
      let ArchiveLookup(url:, ..) = candidate
      case list.contains(seen, url) {
        True -> dedupe_lookups(rest, seen, acc)
        False -> dedupe_lookups(rest, [url, ..seen], [candidate, ..acc])
      }
    }
  }
}

fn option_map(value: Option(a), mapper: fn(a) -> b) -> Option(b) {
  case value {
    Some(value) -> Some(mapper(value))
    None -> None
  }
}

fn option_then(value: Option(a), mapper: fn(a) -> Option(b)) -> Option(b) {
  case value {
    Some(value) -> mapper(value)
    None -> None
  }
}

fn lookup_wayback_snapshot(
  lookup: ArchiveLookup,
  requested: RequestedArchiveDate,
  provider_key: String,
  report_provider_status: fn(String, Int) -> Result(Nil, String),
) -> Result(ArchiveResolution, String) {
  let query =
    uri.query_to_string([
      #("url", lookup.url),
      #("timestamp", requested.timestamp),
    ])
  let lookup_url = wayback_availability_api <> "?" <> query

  case request.to(lookup_url) {
    Error(Nil) -> Ok(LookupRequestBuildError(requested))
    Ok(req) -> {
      let req =
        req
        |> request.prepend_header("accept", "application/json")
        |> request.prepend_header("user-agent", "cgu-pipeline/worker-crawl")

      case httpc.dispatch(http_client(), req) {
        Error(error) ->
          Ok(LookupTransportError(requested, format_http_error(error)))

        Ok(resp) -> {
          use _ <- result.try(report_provider_status(provider_key, resp.status))
          case resp.status >= 400 {
            True -> Ok(LookupHttpError(requested, resp.status))
            False ->
              case json.parse(from: resp.body, using: availability_decoder()) {
                Error(error) ->
                  Ok(LookupDecodeError(
                    requested,
                    availability_decode_error(error),
                  ))
                Ok(None) -> Ok(SnapshotUnavailable(requested))
                Ok(Some(closest)) ->
                  Ok(to_archive_resolution(lookup, requested, closest))
              }
          }
        }
      }
    }
  }
}

fn to_archive_resolution(
  lookup: ArchiveLookup,
  requested: RequestedArchiveDate,
  closest: AvailabilityClosest,
) -> ArchiveResolution {
  case closest.available, closest.replay_url, closest.timestamp {
    False, _, _ -> SnapshotUnavailable(requested)
    True, Some(replay_url), Some(timestamp) -> {
      let snapshot =
        SnapshotRef(
          provider: "wayback",
          original_url: lookup.url,
          lookup_url: lookup.url,
          alias_rule: lookup.alias_rule,
          replay_url: replay_url,
          timestamp: timestamp,
          availability_status: closest.status,
          distance_seconds: distance_seconds(requested.timestamp, timestamp),
        )

      case match_resolution(requested, timestamp) {
        Exact -> ExactPeriod(snapshot, requested)
        SameDay -> SameDayFallback(snapshot, requested)
        Nearby -> NearbyFallback(snapshot, requested)
      }
    }
    True, _, _ -> LookupIncompleteSnapshot(requested)
  }
}

type TimemapRecord {
  TimemapRecord(
    timestamp: String,
    url: String,
    status: Option(String),
    mime: Option(String),
  )
}

fn lookup_memento_timemap_snapshot(
  lookup: ArchiveLookup,
  requested: RequestedArchiveDate,
  provider: String,
  lookup_url: String,
  replay_prefix: String,
  provider_key: String,
  report_provider_status: fn(String, Int) -> Result(Nil, String),
) -> Result(ArchiveResolution, String) {
  case request.to(lookup_url) {
    Error(Nil) -> Ok(LookupRequestBuildError(requested))
    Ok(req) -> {
      let req =
        req
        |> request.prepend_header("accept", "application/json")
        |> request.prepend_header("user-agent", "cgu-pipeline/worker-crawl")

      case httpc.dispatch(http_client(), req) {
        Error(error) ->
          Ok(LookupTransportError(
            requested,
            provider <> ": " <> format_http_error(error),
          ))

        Ok(resp) -> {
          use _ <- result.try(report_provider_status(provider_key, resp.status))
          case resp.status >= 400 {
            True -> Ok(LookupHttpError(requested, resp.status))
            False ->
              case closest_timemap_record(resp.body, requested) {
                None -> Ok(SnapshotUnavailable(requested))
                Some(record) ->
                  Ok(timemap_record_to_resolution(
                    provider,
                    replay_prefix,
                    lookup,
                    requested,
                    record,
                  ))
              }
          }
        }
      }
    }
  }
}

fn arquivo_cdx_lookup_url(
  original_url: String,
  requested: RequestedArchiveDate,
) -> String {
  let year = string.slice(from: requested.timestamp, at_index: 0, length: 4)

  arquivo_cdx_api
  <> "?"
  <> uri.query_to_string([
    #("url", original_url),
    #("output", "json"),
    #("fl", "timestamp,url,mime,status"),
    #("filter", "status:200"),
    #("from", year),
    #("to", year),
    #("limit", "100"),
  ])
}

fn timemap_record_to_resolution(
  provider: String,
  replay_prefix: String,
  lookup: ArchiveLookup,
  requested: RequestedArchiveDate,
  record: TimemapRecord,
) -> ArchiveResolution {
  let snapshot =
    SnapshotRef(
      provider:,
      original_url: lookup.url,
      lookup_url: lookup.url,
      alias_rule: lookup.alias_rule,
      replay_url: replay_prefix <> record.timestamp <> "id_/" <> record.url,
      timestamp: record.timestamp,
      availability_status: record.status,
      distance_seconds: distance_seconds(requested.timestamp, record.timestamp),
    )

  case match_resolution(requested, record.timestamp) {
    Exact -> ExactPeriod(snapshot, requested)
    SameDay -> SameDayFallback(snapshot, requested)
    Nearby -> NearbyFallback(snapshot, requested)
  }
}

fn closest_timemap_record(
  body: String,
  requested: RequestedArchiveDate,
) -> Option(TimemapRecord) {
  body
  |> string.split(on: "\n")
  |> list.fold(None, fn(closest, line) {
    case decode_timemap_line(line) {
      None -> closest
      Some(record) -> nearer_record(closest, record, requested)
    }
  })
}

fn decode_timemap_line(line: String) -> Option(TimemapRecord) {
  case string.trim(line) {
    "" -> None
    trimmed ->
      case json.parse(trimmed, timemap_record_decoder()) {
        Ok(record) ->
          case usable_timemap_record(record) {
            True -> Some(record)
            False -> None
          }
        Error(_) -> None
      }
  }
}

fn usable_timemap_record(record: TimemapRecord) -> Bool {
  record.status == Some("200")
}

fn nearer_record(
  closest: Option(TimemapRecord),
  candidate: TimemapRecord,
  requested: RequestedArchiveDate,
) -> Option(TimemapRecord) {
  case closest {
    None -> Some(candidate)
    Some(current) ->
      case
        distance_seconds(requested.timestamp, candidate.timestamp),
        distance_seconds(requested.timestamp, current.timestamp)
      {
        Some(candidate_distance), Some(current_distance) ->
          case candidate_distance < current_distance {
            True -> Some(candidate)
            False -> closest
          }
        Some(_), None -> Some(candidate)
        _, _ -> closest
      }
  }
}

fn timemap_record_decoder() -> decode.Decoder(TimemapRecord) {
  use timestamp <- decode.field("timestamp", decode.string)
  use url <- decode.field("url", decode.string)
  use status <- decode.field("status", decode.optional(decode.string))
  use mime <- decode.field("mime", decode.optional(decode.string))
  decode.success(TimemapRecord(timestamp:, url:, status:, mime:))
}

type MatchResolution {
  Exact
  SameDay
  Nearby
}

fn match_resolution(
  requested: RequestedArchiveDate,
  resolved_timestamp: String,
) -> MatchResolution {
  case string.starts_with(resolved_timestamp, requested.timestamp) {
    True -> Exact
    False ->
      case requested.precision {
        Hour | Minute | Second ->
          case
            string.slice(from: resolved_timestamp, at_index: 0, length: 8)
            == string.slice(from: requested.timestamp, at_index: 0, length: 8)
          {
            True -> SameDay
            False -> Nearby
          }
        Year | Month | Day -> Nearby
      }
  }
}

fn fetch_resolution(
  resolution: ArchiveResolution,
  acquire_provider_slot: fn(String) -> Result(Nil, String),
  report_provider_status: fn(String, Int) -> Result(Nil, String),
) -> Result(FetchOutcome, String) {
  case resolution {
    ExactPeriod(snapshot:, ..)
    | SameDayFallback(snapshot:, ..)
    | NearbyFallback(snapshot:, ..) -> {
      use _ <- result.try(
        acquire_provider_slot(provider_replay_key(snapshot.provider)),
      )
      fetch_snapshot(snapshot, report_provider_status)
    }
    SnapshotUnavailable(..)
    | InvalidArchiveDate(..)
    | LookupRequestBuildError(..)
    | LookupHttpError(..)
    | LookupTransportError(..)
    | LookupDecodeError(..)
    | LookupIncompleteSnapshot(..) -> Ok(NotAttempted)
  }
}

fn fetch_snapshot(
  snapshot: SnapshotRef,
  report_provider_status: fn(String, Int) -> Result(Nil, String),
) -> Result(FetchOutcome, String) {
  case request.to(snapshot.replay_url) {
    Error(Nil) -> Ok(ReplayTransportError("Could not build replay request."))
    Ok(req) -> {
      let req =
        req
        |> request.prepend_header("accept", "*/*")
        |> request.prepend_header("user-agent", "cgu-pipeline/worker-crawl")
        |> request.map(bit_array.from_string)

      case httpc.dispatch_bits(http_client(), req) {
        Error(error) -> Ok(ReplayTransportError(format_http_error(error)))
        Ok(resp) -> {
          use _ <- result.try(report_provider_status(
            provider_replay_key(snapshot.provider),
            resp.status,
          ))
          Ok(classify_fetch(snapshot, resp))
        }
      }
    }
  }
}

fn classify_fetch(
  snapshot: SnapshotRef,
  resp: response.Response(BitArray),
) -> FetchOutcome {
  let content_type = header(resp, "content-type")
  let location = header(resp, "location")
  let retry_after_seconds = retry_after.parse(header(resp, "retry-after"))

  case resp.status >= 300 && resp.status < 400 {
    True ->
      case location {
        Some(location) ->
          case escaped_to_live(location) {
            True ->
              ReplayEscapedToLive(resp.status, location, retry_after_seconds)
            False ->
              ReplayRedirect(resp.status, Some(location), retry_after_seconds)
          }
        None -> ReplayRedirect(resp.status, location, retry_after_seconds)
      }

    False ->
      case resp.status >= 400 {
        True ->
          ReplayHttpError(
            resp.status,
            content_type,
            retry_after_seconds,
            resp.body,
          )
        False ->
          case content_type {
            Some(value) ->
              case string.lowercase(value) {
                "text/html" <> _ | "application/xhtml+xml" <> _ ->
                  case bit_array.to_string(resp.body) {
                    Ok(body) ->
                      ReplayedHtml(
                        resp.status,
                        content_type,
                        retry_after_seconds,
                        HtmlSnapshot(
                          body: resp.body,
                          links: extract_links(snapshot.original_url, body),
                        ),
                      )
                    Error(Nil) ->
                      ReplayNonHtml(
                        resp.status,
                        content_type,
                        retry_after_seconds,
                        resp.body,
                      )
                  }
                _ ->
                  ReplayNonHtml(
                    resp.status,
                    content_type,
                    retry_after_seconds,
                    resp.body,
                  )
              }

            None ->
              ReplayNonHtml(
                resp.status,
                content_type,
                retry_after_seconds,
                resp.body,
              )
          }
      }
  }
}

fn http_client() -> httpc.Configuration {
  httpc.configure()
  |> httpc.follow_redirects(False)
  |> httpc.timeout(30_000)
}

fn extract_links(base_url: String, html: String) -> LinkExtraction {
  let href_scraper =
    soup.elements([soup.with_tag("a")])
    |> soup.return(soup.attributes())

  case soup.scrape(href_scraper, html) {
    Ok(attributes) -> collect_links(base_url, attributes, [], [])
    Error(error) -> LinkExtractionParseError(error)
  }
}

fn collect_links(
  base_url: String,
  attributes: List(List(#(String, String))),
  accepted: List(String),
  rejected: List(LinkRejection),
) -> LinkExtraction {
  case attributes {
    [] ->
      LinkExtractionSucceeded(
        url: accepted |> list.reverse |> dedupe(),
        rejected: list.reverse(rejected),
      )
    [entry, ..rest] ->
      case normalise_link(base_url, entry) {
        AcceptedLink(url) ->
          collect_links(base_url, rest, [url, ..accepted], rejected)
        RejectedLink(reason) ->
          collect_links(base_url, rest, accepted, [reason, ..rejected])
      }
  }
}

pub type LinkNormalisation {
  AcceptedLink(url: String)
  RejectedLink(reason: LinkRejection)
}

pub fn normalise_link(
  base_url: String,
  attributes: List(#(String, String)),
) -> LinkNormalisation {
  case find_attribute(attributes, "href") {
    None -> RejectedLink(MissingHref)
    Some(raw_href) ->
      case string.trim(raw_href) {
        "" -> RejectedLink(BlankHref)
        href -> normalise_href(base_url, href)
      }
  }
}

fn normalise_href(base_url: String, href: String) -> LinkNormalisation {
  let href =
    href
    |> string.trim
    |> strip_fragment
    |> unwrap_wayback_href

  case href == "" || unsupported_href(href) {
    True -> RejectedLink(UnsupportedHref(href))
    False ->
      case uri.parse(base_url), uri.parse(href) {
        Ok(base), Ok(target) ->
          case uri.merge(base, target) {
            Ok(merged) -> {
              let normalized =
                uri.to_string(uri.Uri(..merged, fragment: None))
                |> drop_trailing_slash_when_rootless
              AcceptedLink(normalized)
            }
            Error(Nil) -> RejectedLink(UnmergeableHref(href))
          }
        Error(Nil), _ -> RejectedLink(InvalidBaseUrl(base_url))
        _, Error(Nil) -> RejectedLink(InvalidHref(href))
      }
  }
}

fn unsupported_href(href: String) -> Bool {
  string.starts_with(href, "#")
  || string.starts_with(href, "javascript:")
  || string.starts_with(href, "mailto:")
  || string.starts_with(href, "tel:")
  || string.starts_with(href, "data:")
}

pub fn unwrap_wayback_href(href: String) -> String {
  case
    string.starts_with(href, "https://web.archive.org/web/")
    || string.starts_with(href, "http://web.archive.org/web/")
    || string.starts_with(href, "/web/")
  {
    True -> unwrap_replay_href(href, "/web/")
    False ->
      case
        string.starts_with(href, "https://arquivo.pt/wayback/")
        || string.starts_with(href, "http://arquivo.pt/wayback/")
        || string.starts_with(href, "/wayback/")
      {
        True -> unwrap_replay_href(href, "/wayback/")
        False ->
          case
            string.starts_with(href, "https://wayback.archive-it.org/all/")
            || string.starts_with(href, "http://wayback.archive-it.org/all/")
            || string.starts_with(href, "https://webarchive.loc.gov/all/")
            || string.starts_with(href, "http://webarchive.loc.gov/all/")
            || string.starts_with(href, "/all/")
          {
            True -> unwrap_replay_href(href, "/all/")
            False -> href
          }
      }
  }
}

fn unwrap_replay_href(href: String, marker: String) -> String {
  case string.split_once(href, on: marker) {
    Ok(#(_, rest)) ->
      case string.split_once(rest, on: "/") {
        Ok(#(_, original)) -> original
        Error(Nil) -> href
      }
    Error(Nil) -> href
  }
}

fn strip_fragment(value: String) -> String {
  case string.split_once(value, on: "#") {
    Ok(#(before, _)) -> before
    Error(Nil) -> value
  }
}

fn drop_trailing_slash_when_rootless(url: String) -> String {
  case uri.parse(url) {
    Ok(parsed) ->
      case parsed.path {
        "/" -> url
        _ ->
          case string.ends_with(url, "/") {
            True ->
              string.slice(
                from: url,
                at_index: 0,
                length: string.length(url) - 1,
              )
            False -> url
          }
      }
    Error(Nil) -> url
  }
}

fn keep_same_site(urls: List(String), site_origin: String) -> List(String) {
  list.filter(urls, fn(url) {
    case uri.parse(url) {
      Ok(parsed) ->
        case uri.origin(parsed) {
          Ok(origin) -> origin == site_origin
          Error(Nil) -> False
        }
      Error(Nil) -> False
    }
  })
}

fn escaped_to_live(location: String) -> Bool {
  case uri.parse(location) {
    Ok(uri.Uri(host: Some(host), ..)) -> host != replay_host
    _ -> False
  }
}

fn header(resp: response.Response(body), key: String) -> Option(String) {
  case response.get_header(resp, key) {
    Ok(value) -> Some(value)
    Error(Nil) -> None
  }
}

fn availability_decoder() -> decode.Decoder(Option(AvailabilityClosest)) {
  decode.optionally_at(
    ["archived_snapshots", "closest"],
    None,
    decode.optional(availability_closest_decoder()),
  )
}

fn availability_closest_decoder() -> decode.Decoder(AvailabilityClosest) {
  use available <- decode.field("available", decode.bool)
  use status <- decode.field("status", decode.optional(decode.string))
  use timestamp <- decode.field("timestamp", decode.optional(decode.string))
  use replay_url <- decode.field("url", decode.optional(decode.string))
  decode.success(AvailabilityClosest(
    available:,
    status:,
    timestamp:,
    replay_url:,
  ))
}

fn normalize_archive_date(
  archive_date: String,
) -> Result(RequestedArchiveDate, String) {
  let digits =
    archive_date
    |> string.to_graphemes
    |> list.filter(is_digit)
    |> string.concat

  case string.length(digits) {
    4 -> Ok(RequestedArchiveDate(archive_date, digits, Year))
    6 -> Ok(RequestedArchiveDate(archive_date, digits, Month))
    8 -> Ok(RequestedArchiveDate(archive_date, digits, Day))
    10 -> Ok(RequestedArchiveDate(archive_date, digits, Hour))
    12 -> Ok(RequestedArchiveDate(archive_date, digits, Minute))
    14 -> Ok(RequestedArchiveDate(archive_date, digits, Second))
    _ ->
      Error(
        "archive_date must contain 4, 6, 8, 10, 12, or 14 digits after normalization",
      )
  }
}

fn distance_seconds(
  requested_timestamp: String,
  resolved_timestamp: String,
) -> Option(Int) {
  case
    maybe_timestamp_value(requested_timestamp),
    maybe_timestamp_value(resolved_timestamp)
  {
    Some(requested), Some(resolved) ->
      Some(int.absolute_value(resolved - requested))
    _, _ -> None
  }
}

// This is a coarse sortable distance, not a wall-clock implementation.
fn maybe_timestamp_value(timestamp: String) -> Option(Int) {
  case int.parse(timestamp) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

fn format_http_error(error: httpc.HttpError) -> String {
  case error {
    httpc.InvalidUtf8Response -> "Response body was not valid UTF-8."
    httpc.ResponseTimeout -> "Response timed out."
    httpc.FailedToConnect(ip4, ip6) ->
      "Failed to connect over IPv4 ("
      <> connect_error_to_string(ip4)
      <> ") or IPv6 ("
      <> connect_error_to_string(ip6)
      <> ")."
  }
}

fn connect_error_to_string(error: httpc.ConnectError) -> String {
  case error {
    httpc.Posix(code) -> code
    httpc.TlsAlert(code, detail) -> code <> ": " <> detail
  }
}

fn archive_resolution_to_json(resolution: ArchiveResolution) -> json.Json {
  case resolution {
    ExactPeriod(snapshot, request) ->
      resolution_json("exact_period", request, Some(snapshot), [])
    SameDayFallback(snapshot, request) ->
      resolution_json("same_day_fallback", request, Some(snapshot), [])
    NearbyFallback(snapshot, request) ->
      resolution_json("nearby_fallback", request, Some(snapshot), [])
    SnapshotUnavailable(request) ->
      resolution_json("snapshot_unavailable", request, None, [])
    InvalidArchiveDate(detail) ->
      json.object([
        #("case", json.string("invalid_archive_date")),
        #("detail", json.string(detail)),
      ])
    LookupRequestBuildError(request) ->
      resolution_json("lookup_request_build_error", request, None, [])
    LookupHttpError(request, status) ->
      resolution_json("lookup_http_error", request, None, [
        #("status", json.int(status)),
      ])
    LookupTransportError(request, detail) ->
      resolution_json("lookup_transport_error", request, None, [
        #("detail", json.string(detail)),
      ])
    LookupDecodeError(request, detail) ->
      resolution_json("lookup_decode_error", request, None, [
        #("detail", json.string(detail)),
      ])
    LookupIncompleteSnapshot(request) ->
      resolution_json("lookup_incomplete_snapshot", request, None, [])
  }
}

fn resolution_json(
  case_name: String,
  request: RequestedArchiveDate,
  snapshot: Option(SnapshotRef),
  extra: List(#(String, json.Json)),
) -> json.Json {
  let base = [
    #("case", json.string(case_name)),
    #("requested_at", json.string(request.original)),
    #("requested_timestamp", json.string(request.timestamp)),
    #(
      "requested_precision",
      json.string(precision_to_string(request.precision)),
    ),
  ]
  let snapshot_fields = case snapshot {
    Some(snapshot) -> [
      #("provider", json.string(snapshot.provider)),
      #("lookup_url", json.string(snapshot.lookup_url)),
      #("alias_rule", json.string(snapshot.alias_rule)),
      #("replay_url", json.string(snapshot.replay_url)),
      #("resolved_timestamp", json.string(snapshot.timestamp)),
      #(
        "availability_status",
        option_json(snapshot.availability_status, json.string),
      ),
      #("distance_seconds", option_json(snapshot.distance_seconds, json.int)),
    ]
    None -> []
  }

  json.object(list.append(base, list.append(snapshot_fields, extra)))
}

fn fetch_outcome_to_json(fetch: FetchOutcome) -> json.Json {
  case fetch {
    NotAttempted -> json.object([#("case", json.string("not_attempted"))])
    ReplayedHtml(
      status,
      content_type,
      retry_after_seconds,
      HtmlSnapshot(body:, links:),
    ) ->
      json.object([
        #("case", json.string("replayed_html")),
        #("status", json.int(status)),
        #("content_type", option_json(content_type, json.string)),
        #("retry_after_seconds", option_json(retry_after_seconds, json.float)),
        #("body_size_bytes", json.int(bit_array.byte_size(body))),
        #("links", link_extraction_to_json(links)),
      ])
    ReplayEscapedToLive(status, location, retry_after_seconds) ->
      json.object([
        #("case", json.string("replay_escaped_to_live")),
        #("status", json.int(status)),
        #("location", json.string(location)),
        #("retry_after_seconds", option_json(retry_after_seconds, json.float)),
      ])
    ReplayRedirect(status, location, retry_after_seconds) ->
      json.object([
        #("case", json.string("replay_redirect")),
        #("status", json.int(status)),
        #("location", option_json(location, json.string)),
        #("retry_after_seconds", option_json(retry_after_seconds, json.float)),
      ])
    ReplayNonHtml(status, content_type, retry_after_seconds, body) ->
      json.object([
        #("case", json.string("replay_non_html")),
        #("status", json.int(status)),
        #("content_type", option_json(content_type, json.string)),
        #("retry_after_seconds", option_json(retry_after_seconds, json.float)),
        #("body_size_bytes", json.int(bit_array.byte_size(body))),
      ])
    ReplayHttpError(status, content_type, retry_after_seconds, body) ->
      json.object([
        #("case", json.string("replay_http_error")),
        #("status", json.int(status)),
        #("content_type", option_json(content_type, json.string)),
        #("retry_after_seconds", option_json(retry_after_seconds, json.float)),
        #("body_size_bytes", json.int(bit_array.byte_size(body))),
        #("body_preview", json.string(body_preview(body))),
      ])
    ReplayTransportError(detail) ->
      json.object([
        #("case", json.string("replay_transport_error")),
        #("detail", json.string(detail)),
      ])
  }
}

fn body_preview(body: BitArray) -> String {
  case bit_array.to_string(body) {
    Ok(text) -> string.slice(from: text, at_index: 0, length: 500)
    Error(Nil) ->
      "<non-utf8 body bytes=" <> int.to_string(bit_array.byte_size(body)) <> ">"
  }
}

fn precision_to_string(precision: ArchivePrecision) -> String {
  case precision {
    Year -> "year"
    Month -> "month"
    Day -> "day"
    Hour -> "hour"
    Minute -> "minute"
    Second -> "second"
  }
}

fn link_extraction_to_json(links: LinkExtraction) -> json.Json {
  case links {
    LinkExtractionSucceeded(url:, rejected:) ->
      json.object([
        #("case", json.string("link_extraction_succeeded")),
        #("url", json.array(from: url, of: json.string)),
        #("rejected", json.array(from: rejected, of: link_rejection_to_json)),
      ])
    LinkExtractionParseError(detail) ->
      json.object([
        #("case", json.string("link_extraction_parse_error")),
        #("detail", json.string(string.inspect(detail))),
      ])
  }
}

fn link_rejection_to_json(rejection: LinkRejection) -> json.Json {
  case rejection {
    MissingHref -> json.object([#("case", json.string("missing_href"))])
    BlankHref -> json.object([#("case", json.string("blank_href"))])
    UnsupportedHref(raw) ->
      json.object([
        #("case", json.string("unsupported_href")),
        #("raw", json.string(raw)),
      ])
    InvalidBaseUrl(base_url) ->
      json.object([
        #("case", json.string("invalid_base_url")),
        #("base_url", json.string(base_url)),
      ])
    InvalidHref(raw) ->
      json.object([
        #("case", json.string("invalid_href")),
        #("raw", json.string(raw)),
      ])
    UnmergeableHref(raw) ->
      json.object([
        #("case", json.string("unmergeable_href")),
        #("raw", json.string(raw)),
      ])
  }
}

fn option_json(value: Option(a), encode: fn(a) -> json.Json) -> json.Json {
  case value {
    Some(value) -> encode(value)
    None -> json.null()
  }
}

fn append_unique(
  current: List(String),
  discovered: List(String),
) -> List(String) {
  case discovered {
    [] -> current
    [first, ..rest] ->
      case list.contains(current, first) {
        True -> append_unique(current, rest)
        False -> append_unique(list.append(current, [first]), rest)
      }
  }
}

fn drop_seen(values: List(String), seen: List(String)) -> List(String) {
  list.filter(values, fn(value) { !list.contains(seen, value) })
}

fn dedupe(values: List(String)) -> List(String) {
  dedupe_loop(values, [])
}

fn dedupe_loop(values: List(String), seen: List(String)) -> List(String) {
  case values {
    [] -> list.reverse(seen)
    [first, ..rest] ->
      case list.contains(seen, first) {
        True -> dedupe_loop(rest, seen)
        False -> dedupe_loop(rest, [first, ..seen])
      }
  }
}

fn find_attribute(
  attributes: List(#(String, String)),
  name: String,
) -> Option(String) {
  case attributes {
    [] -> None
    [#(key, value), ..rest] ->
      case key == name {
        True -> Some(value)
        False -> find_attribute(rest, name)
      }
  }
}

fn availability_decode_error(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "unexpected_end_of_input"
    json.UnexpectedByte(value) -> "unexpected_byte: " <> value
    json.UnexpectedSequence(value) -> "unexpected_sequence: " <> value
    json.UnableToDecode(_) -> "unable_to_decode"
  }
}

fn is_digit(part: String) -> Bool {
  list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], part)
}
