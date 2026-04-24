import gleam/http.{Get}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import master/web.{type Context}
import master/work_items/queries/sql as query
import wisp.{type Request, type Response}

const default_page_limit = 50

const max_page_limit = 200

pub fn data_insights(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)
  use summary <- web.require_one_query(
    query.data_insights(ctx.db),
    while: "load data insights",
  )
  use work_item_status_counts <- web.require_many_query(
    query.work_item_status_counts(ctx.db),
    while: "load work item status counts",
  )
  use work_item_kind_counts <- web.require_many_query(
    query.work_item_kind_counts(ctx.db),
    while: "load work item kind counts",
  )
  use artifact_status_code_counts <- web.require_many_query(
    query.artifact_status_code_counts(ctx.db),
    while: "load artifact status code counts",
  )
  use artifact_content_type_counts <- web.require_many_query(
    query.artifact_content_type_counts(ctx.db),
    while: "load artifact content type counts",
  )
  use verification_counts <- web.require_many_query(
    query.subject_item_verification_counts(ctx.db),
    while: "load subject item verification counts",
  )

  json.object([
    #("summary", data_insights_to_json(summary)),
    #(
      "work_item_status_counts",
      json.array(work_item_status_counts, work_item_status_count_to_json),
    ),
    #(
      "work_item_kind_counts",
      json.array(work_item_kind_counts, work_item_kind_count_to_json),
    ),
    #(
      "artifact_status_code_counts",
      json.array(artifact_status_code_counts, artifact_status_code_to_json),
    ),
    #(
      "artifact_content_type_counts",
      json.array(artifact_content_type_counts, artifact_content_type_to_json),
    ),
    #(
      "verification_counts",
      json.array(verification_counts, verification_count_to_json),
    ),
  ])
  |> json.to_string
  |> wisp.json_response(200)
}

pub fn prepared_items(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)
  let params = wisp.get_query(req)
  let limit = query_int(params, "limit", default_page_limit, 1, max_page_limit)
  let offset = query_int(params, "offset", 0, 0, 1_000_000_000)

  use summary <- web.require_one_query(
    query.prepared_summary(ctx.db),
    while: "load prepared summary",
  )
  use rows <- web.require_many_query(
    query.prepared_items(ctx.db, limit, offset),
    while: "list prepared items",
  )

  let total_count = case rows {
    [first, ..] -> first.total_count
    [] -> 0
  }

  json.object([
    #("summary", summary_to_json(summary)),
    #("total_count", json.int(total_count)),
    #("limit", json.int(limit)),
    #("offset", json.int(offset)),
    #("items", json.array(rows, prepared_item_to_json)),
  ])
  |> json.to_string
  |> wisp.json_response(200)
}

fn data_insights_to_json(row: query.DataInsightsRow) -> json.Json {
  let query.DataInsightsRow(
    subject_count:,
    subject_item_count:,
    fetched_subject_item_count:,
    not_fetched_subject_item_count:,
    work_item_count:,
    fetched_work_item_count:,
    not_fetched_work_item_count:,
    open_work_item_count:,
    failed_work_item_count:,
    artifact_count:,
    avg_body_size_bytes:,
    median_body_size_bytes:,
    p95_body_size_bytes:,
  ) = row

  json.object([
    #("subject_count", json.int(subject_count)),
    #("subject_item_count", json.int(subject_item_count)),
    #("fetched_subject_item_count", json.int(fetched_subject_item_count)),
    #(
      "not_fetched_subject_item_count",
      json.int(not_fetched_subject_item_count),
    ),
    #("work_item_count", json.int(work_item_count)),
    #("fetched_work_item_count", json.int(fetched_work_item_count)),
    #("not_fetched_work_item_count", json.int(not_fetched_work_item_count)),
    #("open_work_item_count", json.int(open_work_item_count)),
    #("failed_work_item_count", json.int(failed_work_item_count)),
    #("artifact_count", json.int(artifact_count)),
    #("avg_body_size_bytes", json.int(avg_body_size_bytes)),
    #("median_body_size_bytes", json.int(median_body_size_bytes)),
    #("p95_body_size_bytes", json.int(p95_body_size_bytes)),
  ])
}

fn work_item_status_count_to_json(
  row: query.WorkItemStatusCountsRow,
) -> json.Json {
  let query.WorkItemStatusCountsRow(label:, count:) = row
  count_to_json(label, count)
}

fn work_item_kind_count_to_json(row: query.WorkItemKindCountsRow) -> json.Json {
  let query.WorkItemKindCountsRow(label:, count:) = row
  count_to_json(label, count)
}

fn artifact_status_code_to_json(
  row: query.ArtifactStatusCodeCountsRow,
) -> json.Json {
  let query.ArtifactStatusCodeCountsRow(label:, count:) = row
  count_to_json(label, count)
}

fn artifact_content_type_to_json(
  row: query.ArtifactContentTypeCountsRow,
) -> json.Json {
  let query.ArtifactContentTypeCountsRow(label:, count:) = row
  count_to_json(label, count)
}

fn verification_count_to_json(
  row: query.SubjectItemVerificationCountsRow,
) -> json.Json {
  let query.SubjectItemVerificationCountsRow(label:, count:) = row
  count_to_json(label, count)
}

fn count_to_json(label: String, count: Int) -> json.Json {
  json.object([
    #("label", json.string(label)),
    #("count", json.int(count)),
  ])
}

fn summary_to_json(row: query.PreparedSummaryRow) -> json.Json {
  let query.PreparedSummaryRow(
    subject_item_count:,
    artifact_count:,
    extraction_count:,
    succeeded_count:,
    running_count:,
    failed_count:,
    empty_text_count:,
    median_cleaned_char_count:,
    p95_cleaned_char_count:,
  ) = row

  json.object([
    #("subject_item_count", json.int(subject_item_count)),
    #("artifact_count", json.int(artifact_count)),
    #("extraction_count", json.int(extraction_count)),
    #("succeeded_count", json.int(succeeded_count)),
    #("running_count", json.int(running_count)),
    #("failed_count", json.int(failed_count)),
    #("empty_text_count", json.int(empty_text_count)),
    #("median_cleaned_char_count", json.int(median_cleaned_char_count)),
    #("p95_cleaned_char_count", json.int(p95_cleaned_char_count)),
  ])
}

fn prepared_item_to_json(row: query.PreparedItemsRow) -> json.Json {
  let query.PreparedItemsRow(
    total_count: _,
    subject_item_id:,
    subject_id:,
    source_key:,
    url:,
    verification_status:,
    assunto:,
    item:,
    resposta_orgao:,
    avaliacao_cgu:,
    work_item_id:,
    work_kind:,
    work_status:,
    fetch_host:,
    artifact_id:,
    status_code:,
    content_type:,
    body_size_bytes:,
    fetched_url:,
    extraction_status:,
    char_count:,
    cleaned_char_count:,
    title:,
    cleaned_text_excerpt:,
    extraction_updated_at:,
  ) = row

  json.object([
    #("subject_item_id", json.string(subject_item_id)),
    #("subject_id", json.string(subject_id)),
    #("source_key", json.string(source_key)),
    #("url", json.string(url)),
    #("verification_status", json.string(verification_status)),
    #("assunto", json.string(assunto)),
    #("item", json.string(item)),
    #("resposta_orgao", json.string(resposta_orgao)),
    #("avaliacao_cgu", json.string(avaliacao_cgu)),
    #("work_item_id", json.string(work_item_id)),
    #("work_kind", optional_string(work_kind)),
    #("work_status", json.string(work_status)),
    #("fetch_host", optional_string(fetch_host)),
    #("artifact_id", json.string(artifact_id)),
    #("status_code", optional_int(status_code)),
    #("content_type", optional_string(content_type)),
    #("body_size_bytes", json.int(body_size_bytes)),
    #("fetched_url", optional_string(fetched_url)),
    #("extraction_status", optional_string(extraction_status)),
    #("char_count", optional_int(char_count)),
    #("cleaned_char_count", optional_int(cleaned_char_count)),
    #("title", optional_string(title)),
    #("cleaned_text_excerpt", json.string(cleaned_text_excerpt)),
    #("extraction_updated_at", json.string(extraction_updated_at)),
  ])
}

fn optional_string(value) -> json.Json {
  case value {
    Some(value) -> json.string(value)
    None -> json.null()
  }
}

fn optional_int(value) -> json.Json {
  case value {
    Some(value) -> json.int(value)
    None -> json.null()
  }
}

fn query_int(
  query: List(#(String, String)),
  key: String,
  default: Int,
  minimum: Int,
  maximum: Int,
) -> Int {
  case list.key_find(query, key) {
    Ok(value) ->
      case int.parse(value) {
        Ok(parsed) -> clamp(parsed, minimum, maximum)
        Error(Nil) -> default
      }
    Error(Nil) -> default
  }
}

fn clamp(value: Int, minimum: Int, maximum: Int) -> Int {
  case value < minimum {
    True -> minimum
    False ->
      case value > maximum {
        True -> maximum
        False -> value
      }
  }
}
