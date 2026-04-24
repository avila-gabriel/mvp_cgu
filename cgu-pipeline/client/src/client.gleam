import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

const upload_input_id = "sta-upload"

const page_limit = 100

const prepared_page_limit = 50

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(
    access_key: String,
    upload_state: UploadState,
    last_ingest: ResultSummary,
    work_items: ResultSummary,
    work_items_offset: Int,
    data_insights: ResultSummary,
    prepared_items: ResultSummary,
    prepared_items_offset: Int,
  )
}

type UploadState {
  Idle
  Uploading
}

type ResultSummary {
  Empty
  Loading
  Success(summary: String, body: String)
  Failure(message: String)
}

type WorkItem {
  WorkItem(
    work_item_id: String,
    subject_id: String,
    kind: String,
    url: String,
    archive_date: Option(String),
    status: String,
    attempts: Int,
    max_attempts: Int,
    last_error: Option(String),
    updated_at: String,
  )
}

type WorkItemsPage {
  WorkItemsPage(
    total_count: Int,
    limit: Int,
    offset: Int,
    items: List(WorkItem),
  )
}

type PreparedSummary {
  PreparedSummary(
    subject_item_count: Int,
    artifact_count: Int,
    extraction_count: Int,
    succeeded_count: Int,
    running_count: Int,
    failed_count: Int,
    empty_text_count: Int,
    median_cleaned_char_count: Int,
    p95_cleaned_char_count: Int,
  )
}

type PreparedItem {
  PreparedItem(
    subject_id: String,
    source_key: String,
    url: String,
    verification_status: String,
    assunto: String,
    item: String,
    avaliacao_cgu: String,
    work_kind: Option(String),
    work_status: String,
    fetch_host: Option(String),
    artifact_id: String,
    status_code: Option(Int),
    content_type: Option(String),
    fetched_url: Option(String),
    extraction_status: Option(String),
    cleaned_char_count: Option(Int),
    title: Option(String),
    cleaned_text_excerpt: String,
  )
}

type PreparedItemsPage {
  PreparedItemsPage(
    summary: PreparedSummary,
    total_count: Int,
    limit: Int,
    offset: Int,
    items: List(PreparedItem),
  )
}

type DataInsights {
  DataInsights(
    summary: DataInsightSummary,
    work_item_status_counts: List(CountRow),
    work_item_kind_counts: List(CountRow),
    artifact_status_code_counts: List(CountRow),
    artifact_content_type_counts: List(CountRow),
    verification_counts: List(CountRow),
  )
}

type DataInsightSummary {
  DataInsightSummary(
    subject_count: Int,
    subject_item_count: Int,
    fetched_subject_item_count: Int,
    not_fetched_subject_item_count: Int,
    work_item_count: Int,
    fetched_work_item_count: Int,
    not_fetched_work_item_count: Int,
    open_work_item_count: Int,
    failed_work_item_count: Int,
    artifact_count: Int,
    avg_body_size_bytes: Int,
    median_body_size_bytes: Int,
    p95_body_size_bytes: Int,
  )
}

type IngestResponse {
  IngestResponse(
    sta_count: Int,
    item_count: Int,
    skipped_missing_url: Int,
    discarded_rows: List(DiscardedRow),
    work_item_count: Int,
    work_items: List(IngestWorkItem),
  )
}

type DiscardedRow {
  DiscardedRow(reason: String)
}

type IngestWorkItem {
  IngestWorkItem(kind: String, status: String)
}

type CountRow {
  CountRow(label: String, count: Int)
}

type ErrorField {
  ErrorField(label: String, value: String)
}

type LastErrorDetail {
  LastErrorDetail(
    case_name: Option(String),
    error: Option(String),
    detail: Option(String),
    message: Option(String),
    status: Option(String),
    requested_url: Option(String),
    archive_date: Option(String),
    config_key: Option(String),
    configured_value: Option(Int),
    provider: Option(String),
    reason: Option(String),
    status_code: Option(Int),
    lookup_status_code: Option(Int),
    replay_status_code: Option(Int),
  )
}

type StatusCounts {
  StatusCounts(
    pending: Int,
    claimed: Int,
    succeeded: Int,
    failed: Int,
    other: Int,
  )
}

type Message {
  UserTypedAccessKey(String)
  UserClickedUpload
  UserClickedRefresh
  UserClickedPreviousPage
  UserClickedNextPage
  UserClickedRefreshInsights
  UserClickedRefreshPrepared
  UserClickedPreviousPreparedPage
  UserClickedNextPreparedPage
  UploadReturned(Result(String, String))
  WorkItemsReturned(Result(String, String))
  DataInsightsReturned(Result(String, String))
  PreparedItemsReturned(Result(String, String))
}

fn init(_flags) -> #(Model, Effect(Message)) {
  #(
    Model(
      access_key: "",
      upload_state: Idle,
      last_ingest: Empty,
      work_items: Empty,
      work_items_offset: 0,
      data_insights: Empty,
      prepared_items: Empty,
      prepared_items_offset: 0,
    ),
    effect.none(),
  )
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    UserTypedAccessKey(access_key) -> #(
      Model(..model, access_key:),
      effect.none(),
    )

    UserClickedUpload -> #(
      Model(..model, upload_state: Uploading, last_ingest: Loading),
      upload_file(
        upload_input_id,
        "/api/xlsx/ingest",
        "application/zip",
        model.access_key,
        UploadReturned,
      ),
    )

    UserClickedRefresh -> #(
      Model(..model, work_items: Loading),
      fetch_work_items(model.work_items_offset, model.access_key),
    )

    UserClickedPreviousPage -> {
      let offset = int.max(0, model.work_items_offset - page_limit)
      #(
        Model(..model, work_items: Loading, work_items_offset: offset),
        fetch_work_items(offset, model.access_key),
      )
    }

    UserClickedNextPage -> {
      let offset = model.work_items_offset + page_limit
      #(
        Model(..model, work_items: Loading, work_items_offset: offset),
        fetch_work_items(offset, model.access_key),
      )
    }

    UserClickedRefreshInsights -> #(
      Model(..model, data_insights: Loading),
      fetch_data_insights(model.access_key),
    )

    UserClickedRefreshPrepared -> #(
      Model(..model, prepared_items: Loading),
      fetch_prepared_items(model.prepared_items_offset, model.access_key),
    )

    UserClickedPreviousPreparedPage -> {
      let offset = int.max(0, model.prepared_items_offset - prepared_page_limit)
      #(
        Model(..model, prepared_items: Loading, prepared_items_offset: offset),
        fetch_prepared_items(offset, model.access_key),
      )
    }

    UserClickedNextPreparedPage -> {
      let offset = model.prepared_items_offset + prepared_page_limit
      #(
        Model(..model, prepared_items: Loading, prepared_items_offset: offset),
        fetch_prepared_items(offset, model.access_key),
      )
    }

    UploadReturned(Ok(body)) -> #(
      Model(
        access_key: model.access_key,
        upload_state: Idle,
        last_ingest: Success(ingest_summary(body), body),
        work_items: Loading,
        work_items_offset: 0,
        data_insights: model.data_insights,
        prepared_items: model.prepared_items,
        prepared_items_offset: model.prepared_items_offset,
      ),
      fetch_work_items(0, model.access_key),
    )

    UploadReturned(Error(message)) -> #(
      Model(..model, upload_state: Idle, last_ingest: Failure(message)),
      effect.none(),
    )

    WorkItemsReturned(Ok(body)) -> #(
      Model(
        ..model,
        work_items: Success(work_items_summary(body), body),
        work_items_offset: work_items_offset(body, model.work_items_offset),
      ),
      effect.none(),
    )

    WorkItemsReturned(Error(message)) -> #(
      Model(..model, work_items: Failure(message)),
      effect.none(),
    )

    DataInsightsReturned(Ok(body)) -> #(
      Model(..model, data_insights: Success(data_insights_summary(body), body)),
      effect.none(),
    )

    DataInsightsReturned(Error(message)) -> #(
      Model(..model, data_insights: Failure(message)),
      effect.none(),
    )

    PreparedItemsReturned(Ok(body)) -> #(
      Model(
        ..model,
        prepared_items: Success(prepared_items_summary(body), body),
        prepared_items_offset: prepared_items_offset(
          body,
          model.prepared_items_offset,
        ),
      ),
      effect.none(),
    )

    PreparedItemsReturned(Error(message)) -> #(
      Model(..model, prepared_items: Failure(message)),
      effect.none(),
    )
  }
}

fn fetch_work_items(offset: Int, access_key: String) -> Effect(Message) {
  fetch_text(
    "/api/work-items?limit="
      <> int.to_string(page_limit)
      <> "&offset="
      <> int.to_string(offset),
    access_key,
    WorkItemsReturned,
  )
}

fn fetch_data_insights(access_key: String) -> Effect(Message) {
  fetch_text("/api/analysis/data-insights", access_key, DataInsightsReturned)
}

fn fetch_prepared_items(offset: Int, access_key: String) -> Effect(Message) {
  fetch_text(
    "/api/analysis/prepared-items?limit="
      <> int.to_string(prepared_page_limit)
      <> "&offset="
      <> int.to_string(offset),
    access_key,
    PreparedItemsReturned,
  )
}

fn upload_file(
  input_id: String,
  endpoint: String,
  content_type: String,
  access_key: String,
  to_message: fn(Result(String, String)) -> Message,
) -> Effect(Message) {
  effect.from(fn(dispatch) {
    do_upload_file(input_id, endpoint, content_type, access_key, fn(result) {
      dispatch(to_message(result))
    })
  })
}

fn fetch_text(
  endpoint: String,
  access_key: String,
  to_message: fn(Result(String, String)) -> Message,
) -> Effect(Message) {
  effect.from(fn(dispatch) {
    do_fetch_text(endpoint, access_key, fn(result) {
      dispatch(to_message(result))
    })
  })
}

@external(javascript, "./file_ffi.mjs", "upload_file")
fn do_upload_file(
  input_id: String,
  endpoint: String,
  content_type: String,
  access_key: String,
  callback: fn(Result(String, String)) -> Nil,
) -> Nil

@external(javascript, "./file_ffi.mjs", "fetch_text")
fn do_fetch_text(
  endpoint: String,
  access_key: String,
  callback: fn(Result(String, String)) -> Nil,
) -> Nil

fn ingest_summary(body: String) -> String {
  let decoder = {
    use sta_count <- decode.field("sta_count", decode.int)
    use item_count <- decode.field("item_count", decode.int)
    use skipped_missing_url <- decode.optional_field(
      "skipped_missing_url",
      0,
      decode.int,
    )
    use work_item_count <- decode.field("work_item_count", decode.int)
    decode.success(#(
      sta_count,
      item_count,
      skipped_missing_url,
      work_item_count,
    ))
  }

  case json.parse(body, decoder) {
    Ok(#(sta_count, item_count, skipped_missing_url, work_item_count)) ->
      int.to_string(sta_count)
      <> " STAs, "
      <> int.to_string(item_count)
      <> " URLs, "
      <> int.to_string(work_item_count)
      <> " work items queued"
      <> case skipped_missing_url {
        0 -> "."
        _ ->
          ", "
          <> int.to_string(skipped_missing_url)
          <> " rows skipped without URL."
      }

    Error(_) -> "Ingest accepted."
  }
}

fn ingest_response_decoder() -> decode.Decoder(IngestResponse) {
  use sta_count <- decode.field("sta_count", decode.int)
  use item_count <- decode.field("item_count", decode.int)
  use skipped_missing_url <- decode.optional_field(
    "skipped_missing_url",
    0,
    decode.int,
  )
  use discarded_rows <- decode.optional_field(
    "discarded_rows",
    [],
    decode.list(discarded_row_decoder()),
  )
  use work_item_count <- decode.field("work_item_count", decode.int)
  use work_items <- decode.field(
    "work_items",
    decode.list(ingest_work_item_decoder()),
  )
  decode.success(IngestResponse(
    sta_count:,
    item_count:,
    skipped_missing_url:,
    discarded_rows:,
    work_item_count:,
    work_items:,
  ))
}

fn discarded_row_decoder() -> decode.Decoder(DiscardedRow) {
  use reason <- decode.field("reason", decode.string)
  decode.success(DiscardedRow(reason:))
}

fn ingest_work_item_decoder() -> decode.Decoder(IngestWorkItem) {
  use kind <- decode.field("kind", decode.string)
  use status <- decode.field("status", decode.string)
  decode.success(IngestWorkItem(kind:, status:))
}

fn last_error_detail_decoder() -> decode.Decoder(LastErrorDetail) {
  use case_name <- decode.optional_field(
    "case",
    None,
    decode.optional(decode.string),
  )
  use error <- decode.optional_field(
    "error",
    None,
    decode.optional(decode.string),
  )
  use detail <- decode.optional_field(
    "detail",
    None,
    decode.optional(decode.string),
  )
  use message <- decode.optional_field(
    "message",
    None,
    decode.optional(decode.string),
  )
  use status <- decode.optional_field(
    "status",
    None,
    decode.optional(decode.string),
  )
  use requested_url <- decode.optional_field(
    "requested_url",
    None,
    decode.optional(decode.string),
  )
  use archive_date <- decode.optional_field(
    "archive_date",
    None,
    decode.optional(decode.string),
  )
  use config_key <- decode.optional_field(
    "config_key",
    None,
    decode.optional(decode.string),
  )
  use configured_value <- decode.optional_field(
    "configured_value",
    None,
    decode.optional(decode.int),
  )
  use provider <- decode.optional_field(
    "provider",
    None,
    decode.optional(decode.string),
  )
  use reason <- decode.optional_field(
    "reason",
    None,
    decode.optional(decode.string),
  )
  use status_code <- decode.optional_field(
    "status_code",
    None,
    decode.optional(decode.int),
  )
  use lookup_status_code <- decode.optional_field(
    "lookup_status_code",
    None,
    decode.optional(decode.int),
  )
  use replay_status_code <- decode.optional_field(
    "replay_status_code",
    None,
    decode.optional(decode.int),
  )
  decode.success(LastErrorDetail(
    case_name:,
    error:,
    detail:,
    message:,
    status:,
    requested_url:,
    archive_date:,
    config_key:,
    configured_value:,
    provider:,
    reason:,
    status_code:,
    lookup_status_code:,
    replay_status_code:,
  ))
}

fn work_items_summary(body: String) -> String {
  case json.parse(body, work_items_page_decoder()) {
    Ok(page) -> {
      let start = case list.length(page.items) {
        0 -> 0
        _ -> page.offset + 1
      }
      let end = page.offset + list.length(page.items)
      "Showing "
      <> int.to_string(start)
      <> "-"
      <> int.to_string(end)
      <> " of "
      <> int.to_string(page.total_count)
      <> " work items."
    }
    Error(_) -> "Work item list refreshed."
  }
}

fn work_items_offset(body: String, fallback: Int) -> Int {
  case json.parse(body, work_items_page_decoder()) {
    Ok(page) -> page.offset
    Error(_) -> fallback
  }
}

fn work_items_page_decoder() -> decode.Decoder(WorkItemsPage) {
  use total_count <- decode.field("total_count", decode.int)
  use limit <- decode.field("limit", decode.int)
  use offset <- decode.field("offset", decode.int)
  use items <- decode.field("items", decode.list(work_item_decoder()))
  decode.success(WorkItemsPage(total_count:, limit:, offset:, items:))
}

fn work_item_decoder() -> decode.Decoder(WorkItem) {
  use work_item_id <- decode.field("work_item_id", decode.string)
  use subject_id <- decode.field("subject_id", decode.string)
  use kind <- decode.field("kind", decode.string)
  use url <- decode.field("url", decode.string)
  use archive_date <- decode.field(
    "archive_date",
    decode.optional(decode.string),
  )
  use status <- decode.field("status", decode.string)
  use attempts <- decode.field("attempts", decode.int)
  use max_attempts <- decode.field("max_attempts", decode.int)
  use last_error <- decode.field("last_error", decode.optional(decode.string))
  use updated_at <- decode.field("updated_at", decode.string)

  decode.success(WorkItem(
    work_item_id:,
    subject_id:,
    kind:,
    url:,
    archive_date:,
    status:,
    attempts:,
    max_attempts:,
    last_error:,
    updated_at:,
  ))
}

fn prepared_items_summary(body: String) -> String {
  case json.parse(body, prepared_items_page_decoder()) {
    Ok(page) -> {
      let start = case list.length(page.items) {
        0 -> 0
        _ -> page.offset + 1
      }
      let end = page.offset + list.length(page.items)
      "Showing "
      <> int.to_string(start)
      <> "-"
      <> int.to_string(end)
      <> " of "
      <> int.to_string(page.total_count)
      <> " prepared rows."
    }
    Error(_) -> "Prepared data refreshed."
  }
}

fn prepared_items_offset(body: String, fallback: Int) -> Int {
  case json.parse(body, prepared_items_page_decoder()) {
    Ok(page) -> page.offset
    Error(_) -> fallback
  }
}

fn data_insights_summary(body: String) -> String {
  case json.parse(body, data_insights_decoder()) {
    Ok(insights) -> {
      let summary = insights.summary
      int.to_string(summary.fetched_work_item_count)
      <> " fetched work items, "
      <> int.to_string(summary.not_fetched_subject_item_count)
      <> " URLs not fetched, median body "
      <> bytes_text(summary.median_body_size_bytes)
      <> "."
    }
    Error(_) -> "Data insights refreshed."
  }
}

fn data_insights_decoder() -> decode.Decoder(DataInsights) {
  use summary <- decode.field("summary", data_insight_summary_decoder())
  use work_item_status_counts <- decode.field(
    "work_item_status_counts",
    decode.list(count_row_decoder()),
  )
  use work_item_kind_counts <- decode.field(
    "work_item_kind_counts",
    decode.list(count_row_decoder()),
  )
  use artifact_status_code_counts <- decode.field(
    "artifact_status_code_counts",
    decode.list(count_row_decoder()),
  )
  use artifact_content_type_counts <- decode.field(
    "artifact_content_type_counts",
    decode.list(count_row_decoder()),
  )
  use verification_counts <- decode.field(
    "verification_counts",
    decode.list(count_row_decoder()),
  )
  decode.success(DataInsights(
    summary:,
    work_item_status_counts:,
    work_item_kind_counts:,
    artifact_status_code_counts:,
    artifact_content_type_counts:,
    verification_counts:,
  ))
}

fn data_insight_summary_decoder() -> decode.Decoder(DataInsightSummary) {
  use subject_count <- decode.field("subject_count", decode.int)
  use subject_item_count <- decode.field("subject_item_count", decode.int)
  use fetched_subject_item_count <- decode.field(
    "fetched_subject_item_count",
    decode.int,
  )
  use not_fetched_subject_item_count <- decode.field(
    "not_fetched_subject_item_count",
    decode.int,
  )
  use work_item_count <- decode.field("work_item_count", decode.int)
  use fetched_work_item_count <- decode.field(
    "fetched_work_item_count",
    decode.int,
  )
  use not_fetched_work_item_count <- decode.field(
    "not_fetched_work_item_count",
    decode.int,
  )
  use open_work_item_count <- decode.field("open_work_item_count", decode.int)
  use failed_work_item_count <- decode.field(
    "failed_work_item_count",
    decode.int,
  )
  use artifact_count <- decode.field("artifact_count", decode.int)
  use avg_body_size_bytes <- decode.field("avg_body_size_bytes", decode.int)
  use median_body_size_bytes <- decode.field(
    "median_body_size_bytes",
    decode.int,
  )
  use p95_body_size_bytes <- decode.field("p95_body_size_bytes", decode.int)
  decode.success(DataInsightSummary(
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
  ))
}

fn count_row_decoder() -> decode.Decoder(CountRow) {
  use label <- decode.field("label", decode.string)
  use count <- decode.field("count", decode.int)
  decode.success(CountRow(label:, count:))
}

fn prepared_items_page_decoder() -> decode.Decoder(PreparedItemsPage) {
  use summary <- decode.field("summary", prepared_summary_decoder())
  use total_count <- decode.field("total_count", decode.int)
  use limit <- decode.field("limit", decode.int)
  use offset <- decode.field("offset", decode.int)
  use items <- decode.field("items", decode.list(prepared_item_decoder()))
  decode.success(PreparedItemsPage(
    summary:,
    total_count:,
    limit:,
    offset:,
    items:,
  ))
}

fn prepared_summary_decoder() -> decode.Decoder(PreparedSummary) {
  use subject_item_count <- decode.field("subject_item_count", decode.int)
  use artifact_count <- decode.field("artifact_count", decode.int)
  use extraction_count <- decode.field("extraction_count", decode.int)
  use succeeded_count <- decode.field("succeeded_count", decode.int)
  use running_count <- decode.field("running_count", decode.int)
  use failed_count <- decode.field("failed_count", decode.int)
  use empty_text_count <- decode.field("empty_text_count", decode.int)
  use median_cleaned_char_count <- decode.field(
    "median_cleaned_char_count",
    decode.int,
  )
  use p95_cleaned_char_count <- decode.field(
    "p95_cleaned_char_count",
    decode.int,
  )
  decode.success(PreparedSummary(
    subject_item_count:,
    artifact_count:,
    extraction_count:,
    succeeded_count:,
    running_count:,
    failed_count:,
    empty_text_count:,
    median_cleaned_char_count:,
    p95_cleaned_char_count:,
  ))
}

fn prepared_item_decoder() -> decode.Decoder(PreparedItem) {
  use subject_id <- decode.field("subject_id", decode.string)
  use source_key <- decode.field("source_key", decode.string)
  use url <- decode.field("url", decode.string)
  use verification_status <- decode.field("verification_status", decode.string)
  use assunto <- decode.field("assunto", decode.string)
  use item <- decode.field("item", decode.string)
  use avaliacao_cgu <- decode.field("avaliacao_cgu", decode.string)
  use work_kind <- decode.field("work_kind", decode.optional(decode.string))
  use work_status <- decode.field("work_status", decode.string)
  use fetch_host <- decode.field("fetch_host", decode.optional(decode.string))
  use artifact_id <- decode.field("artifact_id", decode.string)
  use status_code <- decode.field("status_code", decode.optional(decode.int))
  use content_type <- decode.field(
    "content_type",
    decode.optional(decode.string),
  )
  use fetched_url <- decode.field("fetched_url", decode.optional(decode.string))
  use extraction_status <- decode.field(
    "extraction_status",
    decode.optional(decode.string),
  )
  use cleaned_char_count <- decode.field(
    "cleaned_char_count",
    decode.optional(decode.int),
  )
  use title <- decode.field("title", decode.optional(decode.string))
  use cleaned_text_excerpt <- decode.field(
    "cleaned_text_excerpt",
    decode.string,
  )
  decode.success(PreparedItem(
    subject_id:,
    source_key:,
    url:,
    verification_status:,
    assunto:,
    item:,
    avaliacao_cgu:,
    work_kind:,
    work_status:,
    fetch_host:,
    artifact_id:,
    status_code:,
    content_type:,
    fetched_url:,
    extraction_status:,
    cleaned_char_count:,
    title:,
    cleaned_text_excerpt:,
  ))
}

fn view(model: Model) -> Element(Message) {
  html.main([attribute.class("shell")], [
    html.style([], stylesheet()),
    html.section([attribute.class("mast")], [
      html.div([attribute.class("mast-copy")], [
        html.p([attribute.class("eyebrow")], [html.text("CGU Pipeline")]),
        html.h1([], [html.text("STA intake console")]),
        html.p([attribute.class("lede")], [
          html.text(
            "Upload the OneDrive ZIP or an exported XLSX bundle, enqueue the URLs, and let the local worker drain the queue.",
          ),
        ]),
      ]),
      html.div([attribute.class("status-tile")], [
        html.span([attribute.class("dot")], []),
        html.span([], [html.text("Master online")]),
      ]),
    ]),
    html.section([attribute.class("workspace")], [
      upload_panel(model),
      queue_panel(model),
      data_insights_panel(model),
      prepared_panel(model),
    ]),
  ])
}

fn upload_panel(model: Model) -> Element(Message) {
  let is_uploading = model.upload_state == Uploading
  html.section([attribute.class("panel upload-panel")], [
    html.div([attribute.class("panel-head")], [
      html.div([], [
        html.p([attribute.class("eyebrow")], [html.text("Input")]),
        html.h2([], [html.text("Upload STA ZIP")]),
      ]),
      html.span([attribute.class("pill")], [html.text("XLSX bundle")]),
    ]),
    html.label([attribute.class("access-key")], [
      html.span([], [html.text("Access key")]),
      html.input([
        attribute.type_("password"),
        attribute.value(model.access_key),
        attribute.placeholder("Leave empty for local open mode"),
        event.on_input(UserTypedAccessKey),
      ]),
    ]),
    html.label([attribute.class("dropzone"), attribute.for(upload_input_id)], [
      html.input([
        attribute.id(upload_input_id),
        attribute.type_("file"),
        attribute.accept([".zip", "application/zip"]),
      ]),
      html.span([attribute.class("drop-title")], [html.text("Choose ZIP file")]),
      html.span([attribute.class("drop-copy")], [
        html.text(
          "The browser sends the selected file directly to /api/xlsx/ingest.",
        ),
      ]),
    ]),
    html.div([attribute.class("actions")], [
      html.button(
        [
          attribute.class("primary"),
          attribute.type_("button"),
          attribute.disabled(is_uploading),
          event.on_click(UserClickedUpload),
        ],
        [
          html.text(case is_uploading {
            True -> "Uploading..."
            False -> "Upload and enqueue"
          }),
        ],
      ),
    ]),
    result_panel(model.last_ingest),
  ])
}

fn queue_panel(model: Model) -> Element(Message) {
  html.section([attribute.class("panel queue-panel")], [
    html.div([attribute.class("panel-head")], [
      html.div([], [
        html.p([attribute.class("eyebrow")], [html.text("Worker")]),
        html.h2([], [html.text("Queue monitor")]),
      ]),
      html.button(
        [
          attribute.class("secondary"),
          attribute.type_("button"),
          event.on_click(UserClickedRefresh),
        ],
        [html.text("Refresh")],
      ),
    ]),
    html.div([attribute.class("worker-note")], [
      html.strong([], [html.text("Local worker")]),
      html.span([], [
        html.text("polls every 5 seconds and claims queued items."),
      ]),
    ]),
    queue_result_panel(model.work_items),
  ])
}

fn data_insights_panel(model: Model) -> Element(Message) {
  html.section([attribute.class("panel data-insights-panel")], [
    html.div([attribute.class("panel-head")], [
      html.div([], [
        html.p([attribute.class("eyebrow")], [html.text("Analysis")]),
        html.h2([], [html.text("Data insights")]),
      ]),
      html.button(
        [
          attribute.class("secondary"),
          attribute.type_("button"),
          event.on_click(UserClickedRefreshInsights),
        ],
        [html.text("Refresh")],
      ),
    ]),
    html.div([attribute.class("worker-note")], [
      html.strong([], [html.text("Fetch coverage")]),
      html.span([], [
        html.text(
          "summarizes queued URLs, fetched artifacts, response types, and body sizes.",
        ),
      ]),
    ]),
    data_insights_result_panel(model.data_insights),
  ])
}

fn prepared_panel(model: Model) -> Element(Message) {
  html.section([attribute.class("panel prepared-panel")], [
    html.div([attribute.class("panel-head")], [
      html.div([], [
        html.p([attribute.class("eyebrow")], [html.text("Analysis")]),
        html.h2([], [html.text("Prepared data")]),
      ]),
      html.button(
        [
          attribute.class("secondary"),
          attribute.type_("button"),
          event.on_click(UserClickedRefreshPrepared),
        ],
        [html.text("Refresh")],
      ),
    ]),
    html.div([attribute.class("worker-note")], [
      html.strong([], [html.text("Prepared corpus")]),
      html.span([], [
        html.text(
          "shows STA rows joined to fetched artifacts and extracted text.",
        ),
      ]),
    ]),
    prepared_result_panel(model.prepared_items),
  ])
}

fn queue_result_panel(summary: ResultSummary) -> Element(Message) {
  case summary {
    Empty ->
      html.div([attribute.class("result muted")], [
        html.text("No refresh sent yet."),
      ])

    Loading ->
      html.div([attribute.class("result loading")], [
        html.text("Waiting for master..."),
      ])

    Success(_, body) ->
      case json.parse(body, work_items_page_decoder()) {
        Ok(page) -> work_items_view(page)
        Error(_) ->
          html.div([attribute.class("result failure")], [
            html.strong([], [html.text("Could not read queue response")]),
            html.pre([], [html.text(pretty_body(body))]),
          ])
      }

    Failure(message) ->
      html.div([attribute.class("result failure")], [
        html.strong([], [html.text("Request failed")]),
        html.pre([], [html.text(message)]),
      ])
  }
}

fn work_items_view(page: WorkItemsPage) -> Element(Message) {
  let WorkItemsPage(total_count:, limit: _, offset:, items:) = page
  let counts = count_statuses(items)
  let start = case list.length(items) {
    0 -> 0
    _ -> offset + 1
  }
  let end = offset + list.length(items)
  let has_previous = offset > 0
  let has_next = end < total_count

  html.div([attribute.class("queue-result")], [
    html.div([attribute.class("pager")], [
      html.span([], [
        html.text(
          "Showing "
          <> int.to_string(start)
          <> "-"
          <> int.to_string(end)
          <> " of "
          <> int.to_string(total_count),
        ),
      ]),
      html.div([attribute.class("pager-actions")], [
        html.button(
          [
            attribute.class("secondary"),
            attribute.type_("button"),
            attribute.disabled(!has_previous),
            event.on_click(UserClickedPreviousPage),
          ],
          [html.text("Previous")],
        ),
        html.button(
          [
            attribute.class("secondary"),
            attribute.type_("button"),
            attribute.disabled(!has_next),
            event.on_click(UserClickedNextPage),
          ],
          [html.text("Next")],
        ),
      ]),
    ]),
    html.div([attribute.class("queue-summary")], [
      status_metric("Page", list.length(items), "status-all"),
      status_metric("Pending", counts.pending, "status-pending"),
      status_metric("Claimed", counts.claimed, "status-claimed"),
      status_metric("Succeeded", counts.succeeded, "status-succeeded"),
      status_metric("Failed", counts.failed, "status-failed"),
    ]),
    html.div([attribute.class("table-wrap")], [
      html.table([], [
        html.thead([], [
          html.tr([], [
            html.th([], [html.text("Status")]),
            html.th([], [html.text("Subject")]),
            html.th([], [html.text("Kind")]),
            html.th([], [html.text("URL")]),
            html.th([], [html.text("Attempts")]),
            html.th([], [html.text("Updated")]),
            html.th([], [html.text("Last error")]),
          ]),
        ]),
        html.tbody([], list.map(items, work_item_row)),
      ]),
    ]),
  ])
}

fn data_insights_result_panel(summary: ResultSummary) -> Element(Message) {
  case summary {
    Empty ->
      html.div([attribute.class("result muted")], [
        html.text("No refresh sent yet."),
      ])

    Loading ->
      html.div([attribute.class("result loading")], [
        html.text("Waiting for data insights..."),
      ])

    Success(_, body) ->
      case json.parse(body, data_insights_decoder()) {
        Ok(insights) -> data_insights_view(insights)
        Error(_) ->
          html.div([attribute.class("result failure")], [
            html.strong([], [html.text("Could not read data insights")]),
            html.pre([], [html.text(pretty_body(body))]),
          ])
      }

    Failure(message) ->
      html.div([attribute.class("result failure")], [
        html.strong([], [html.text("Request failed")]),
        html.pre([], [html.text(message)]),
      ])
  }
}

fn data_insights_view(insights: DataInsights) -> Element(Message) {
  let summary = insights.summary
  html.div([attribute.class("queue-result data-insights-result")], [
    html.div([attribute.class("insight-metrics")], [
      insight_metric(
        "Fetched URLs",
        percent_text(
          summary.fetched_subject_item_count,
          summary.subject_item_count,
        ),
        count_detail(
          summary.fetched_subject_item_count,
          summary.subject_item_count,
        ),
        "status-succeeded",
      ),
      insight_metric(
        "URLs not fetched",
        percent_text(
          summary.not_fetched_subject_item_count,
          summary.subject_item_count,
        ),
        count_detail(
          summary.not_fetched_subject_item_count,
          summary.subject_item_count,
        ),
        "status-pending",
      ),
      insight_metric(
        "Failed",
        percent_text(summary.failed_work_item_count, summary.work_item_count),
        count_detail(summary.failed_work_item_count, summary.work_item_count),
        "status-failed",
      ),
      insight_metric(
        "Median body",
        bytes_text(summary.median_body_size_bytes),
        "P95 " <> bytes_text(summary.p95_body_size_bytes),
        "status-all",
      ),
      insight_metric(
        "Average body",
        bytes_text(summary.avg_body_size_bytes),
        int.to_string(summary.artifact_count) <> " artifacts",
        "status-all",
      ),
    ]),
    html.div([attribute.class("insight-grid data-insight-grid")], [
      distribution_view(
        "Work item status",
        insights.work_item_status_counts,
        summary.work_item_count,
      ),
      distribution_view(
        "Work item kind",
        insights.work_item_kind_counts,
        summary.work_item_count,
      ),
      distribution_view(
        "HTTP status",
        insights.artifact_status_code_counts,
        summary.artifact_count,
      ),
      distribution_view(
        "Content type",
        insights.artifact_content_type_counts,
        summary.artifact_count,
      ),
      distribution_view(
        "CGU verification",
        insights.verification_counts,
        summary.subject_item_count,
      ),
    ]),
  ])
}

fn prepared_result_panel(summary: ResultSummary) -> Element(Message) {
  case summary {
    Empty ->
      html.div([attribute.class("result muted")], [
        html.text("No refresh sent yet."),
      ])

    Loading ->
      html.div([attribute.class("result loading")], [
        html.text("Waiting for prepared data..."),
      ])

    Success(_, body) ->
      case json.parse(body, prepared_items_page_decoder()) {
        Ok(page) -> prepared_items_view(page)
        Error(_) ->
          html.div([attribute.class("result failure")], [
            html.strong([], [html.text("Could not read prepared response")]),
            html.pre([], [html.text(pretty_body(body))]),
          ])
      }

    Failure(message) ->
      html.div([attribute.class("result failure")], [
        html.strong([], [html.text("Request failed")]),
        html.pre([], [html.text(message)]),
      ])
  }
}

fn prepared_items_view(page: PreparedItemsPage) -> Element(Message) {
  let PreparedItemsPage(summary:, total_count:, limit: _, offset:, items:) =
    page
  let start = case list.length(items) {
    0 -> 0
    _ -> offset + 1
  }
  let end = offset + list.length(items)
  let has_previous = offset > 0
  let has_next = end < total_count

  html.div([attribute.class("queue-result")], [
    html.div([attribute.class("pager")], [
      html.span([], [
        html.text(
          "Showing "
          <> int.to_string(start)
          <> "-"
          <> int.to_string(end)
          <> " of "
          <> int.to_string(total_count),
        ),
      ]),
      html.div([attribute.class("pager-actions")], [
        html.button(
          [
            attribute.class("secondary"),
            attribute.type_("button"),
            attribute.disabled(!has_previous),
            event.on_click(UserClickedPreviousPreparedPage),
          ],
          [html.text("Previous")],
        ),
        html.button(
          [
            attribute.class("secondary"),
            attribute.type_("button"),
            attribute.disabled(!has_next),
            event.on_click(UserClickedNextPreparedPage),
          ],
          [html.text("Next")],
        ),
      ]),
    ]),
    prepared_summary_view(summary),
    html.div([attribute.class("table-wrap prepared-table-wrap")], [
      html.table([attribute.class("prepared-table")], [
        html.thead([], [
          html.tr([], [
            html.th([], [html.text("CGU")]),
            html.th([], [html.text("Subject")]),
            html.th([], [html.text("Evidence")]),
            html.th([], [html.text("Extraction")]),
            html.th([], [html.text("Text")]),
          ]),
        ]),
        html.tbody([], list.map(items, prepared_item_row)),
      ]),
    ]),
  ])
}

fn prepared_summary_view(summary: PreparedSummary) -> Element(Message) {
  html.div([attribute.class("queue-summary prepared-summary")], [
    status_metric("STA items", summary.subject_item_count, "status-all"),
    status_metric("Artifacts", summary.artifact_count, "status-all"),
    status_metric("Extracted", summary.succeeded_count, "status-succeeded"),
    status_metric("Running", summary.running_count, "status-claimed"),
    status_metric("Failed", summary.failed_count, "status-failed"),
    status_metric("Empty text", summary.empty_text_count, "status-pending"),
    status_metric(
      "Median chars",
      summary.median_cleaned_char_count,
      "status-all",
    ),
    status_metric("P95 chars", summary.p95_cleaned_char_count, "status-all"),
  ])
}

fn prepared_item_row(item: PreparedItem) -> Element(Message) {
  html.tr([], [
    html.td([], [
      html.span(
        [
          attribute.class(
            "status-badge " <> status_class(item.verification_status),
          ),
        ],
        [html.text(item.verification_status)],
      ),
      html.div([attribute.class("cell-muted")], [html.text(item.avaliacao_cgu)]),
    ]),
    html.td([attribute.class("subject-cell")], [
      html.strong([], [html.text(item.subject_id)]),
      html.div([attribute.class("cell-muted")], [html.text(item.source_key)]),
      html.div([attribute.class("cell-muted")], [html.text(item.assunto)]),
    ]),
    html.td([attribute.class("url-cell")], [
      html.div([], [html.text(option_text(item.work_kind, "-"))]),
      html.div([attribute.class("cell-muted")], [
        html.text(option_text(item.fetch_host, "")),
      ]),
      html.a(
        [
          attribute.href(option_text(item.fetched_url, item.url)),
          attribute.target("_blank"),
          attribute.rel("noreferrer"),
        ],
        [html.text(short_url(option_text(item.fetched_url, item.url)))],
      ),
    ]),
    html.td([], [
      html.span(
        [
          attribute.class(
            "status-badge "
            <> status_class(option_text(item.extraction_status, "")),
          ),
        ],
        [html.text(option_text(item.extraction_status, "missing"))],
      ),
      html.div([attribute.class("cell-muted")], [
        html.text(
          int_option_text(item.cleaned_char_count)
          <> " chars / "
          <> int_option_text(item.status_code)
          <> " HTTP",
        ),
      ]),
      html.div([attribute.class("cell-muted")], [
        html.text(option_text(item.content_type, "")),
      ]),
    ]),
    html.td([attribute.class("excerpt-cell")], [
      html.strong([], [html.text(option_text(item.title, ""))]),
      html.p([], [html.text(item.item)]),
      html.p([attribute.class("excerpt")], [
        html.text(item.cleaned_text_excerpt),
      ]),
    ]),
  ])
}

fn status_metric(
  label: String,
  value: Int,
  class_name: String,
) -> Element(Message) {
  html.div([attribute.class("metric " <> class_name)], [
    html.span([attribute.class("metric-value")], [
      html.text(int.to_string(value)),
    ]),
    html.span([attribute.class("metric-label")], [html.text(label)]),
  ])
}

fn insight_metric(
  label: String,
  value: String,
  detail: String,
  class_name: String,
) -> Element(Message) {
  html.div([attribute.class("metric insight-metric " <> class_name)], [
    html.span([attribute.class("metric-value")], [html.text(value)]),
    html.span([attribute.class("metric-label")], [html.text(label)]),
    html.span([attribute.class("metric-detail")], [html.text(detail)]),
  ])
}

fn work_item_row(item: WorkItem) -> Element(Message) {
  html.tr([], [
    html.td([], [
      html.span(
        [attribute.class("status-badge " <> status_class(item.status))],
        [html.text(item.status)],
      ),
    ]),
    html.td([attribute.class("subject-cell")], [html.text(item.subject_id)]),
    html.td([], [html.text(kind_label(item))]),
    html.td([attribute.class("url-cell")], [
      html.a(
        [
          attribute.href(item.url),
          attribute.target("_blank"),
          attribute.rel("noreferrer"),
        ],
        [html.text(short_url(item.url))],
      ),
    ]),
    html.td([], [
      html.text(
        int.to_string(item.attempts) <> "/" <> int.to_string(item.max_attempts),
      ),
    ]),
    html.td([], [html.text(short_datetime(item.updated_at))]),
    html.td([attribute.class("error-cell")], [last_error_view(item.last_error)]),
  ])
}

fn count_statuses(items: List(WorkItem)) -> StatusCounts {
  list.fold(items, StatusCounts(0, 0, 0, 0, 0), fn(counts, item) {
    case item.status {
      "pending" -> StatusCounts(..counts, pending: counts.pending + 1)
      "claimed" -> StatusCounts(..counts, claimed: counts.claimed + 1)
      "succeeded" -> StatusCounts(..counts, succeeded: counts.succeeded + 1)
      "failed" -> StatusCounts(..counts, failed: counts.failed + 1)
      _ -> StatusCounts(..counts, other: counts.other + 1)
    }
  })
}

fn status_class(status: String) -> String {
  case status {
    "pending" -> "is-pending"
    "claimed" -> "is-claimed"
    "succeeded" -> "is-succeeded"
    "failed" -> "is-failed"
    _ -> "is-other"
  }
}

fn kind_label(item: WorkItem) -> String {
  case item.archive_date {
    Some(date) -> item.kind <> " / " <> date
    None -> item.kind
  }
}

fn short_url(url: String) -> String {
  case string.length(url) > 72 {
    True -> string.slice(url, at_index: 0, length: 69) <> "..."
    False -> url
  }
}

fn short_datetime(value: String) -> String {
  case string.length(value) > 19 {
    True -> string.slice(value, at_index: 0, length: 19)
    False -> value
  }
}

fn last_error_view(value: Option(String)) -> Element(Message) {
  case value {
    Some(error) -> {
      case json.parse(error, last_error_detail_decoder()) {
        Ok(detail) -> {
          let fields = last_error_fields(detail)
          html.details([attribute.class("error-detail")], [
            html.summary([], [html.text(last_error_summary(detail))]),
            case fields {
              [] -> html.pre([], [html.text(error)])
              _ -> error_field_table(fields)
            },
          ])
        }
        Error(_) ->
          html.details([attribute.class("error-detail")], [
            html.summary([], [html.text(short_text(error))]),
            html.pre([], [html.text(error)]),
          ])
      }
    }
    None -> html.span([attribute.class("cell-muted")], [html.text("-")])
  }
}

fn last_error_summary(detail: LastErrorDetail) -> String {
  case detail.case_name {
    Some(value) -> short_text("case: " <> value)
    None ->
      case detail.error {
        Some(value) -> short_text("error: " <> value)
        None ->
          case detail.detail {
            Some(value) -> short_text("detail: " <> value)
            None ->
              case detail.message {
                Some(value) -> short_text("message: " <> value)
                None ->
                  case detail.status {
                    Some(value) -> short_text("status: " <> value)
                    None -> "JSON error"
                  }
              }
          }
      }
  }
}

fn last_error_fields(detail: LastErrorDetail) -> List(ErrorField) {
  let fields = []
  let fields = add_option_string(fields, "Case", detail.case_name)
  let fields = add_option_string(fields, "Error", detail.error)
  let fields = add_option_string(fields, "Detail", detail.detail)
  let fields = add_option_string(fields, "Message", detail.message)
  let fields = add_option_string(fields, "Status", detail.status)
  let fields = add_option_string(fields, "Requested URL", detail.requested_url)
  let fields = add_option_string(fields, "Archive date", detail.archive_date)
  let fields = add_option_string(fields, "Config key", detail.config_key)
  let fields =
    add_option_int(fields, "Configured value", detail.configured_value)
  let fields = add_option_string(fields, "Provider", detail.provider)
  let fields = add_option_string(fields, "Reason", detail.reason)
  let fields = add_option_int(fields, "Status code", detail.status_code)
  let fields =
    add_option_int(fields, "Lookup status", detail.lookup_status_code)
  let fields =
    add_option_int(fields, "Replay status", detail.replay_status_code)
  list.reverse(fields)
}

fn add_option_string(
  fields: List(ErrorField),
  label: String,
  value: Option(String),
) -> List(ErrorField) {
  case value {
    Some(value) ->
      case string.trim(value) {
        "" -> fields
        value -> [ErrorField(label, value), ..fields]
      }
    None -> fields
  }
}

fn add_option_int(
  fields: List(ErrorField),
  label: String,
  value: Option(Int),
) -> List(ErrorField) {
  case value {
    Some(value) -> [ErrorField(label, int.to_string(value)), ..fields]
    None -> fields
  }
}

fn error_field_table(fields: List(ErrorField)) -> Element(Message) {
  html.table([attribute.class("error-table")], [
    html.tbody([], list.map(fields, error_field_row)),
  ])
}

fn error_field_row(field: ErrorField) -> Element(Message) {
  let ErrorField(label:, value:) = field
  html.tr([], [
    html.th([], [html.text(label)]),
    html.td([], [html.text(value)]),
  ])
}

fn short_text(value: String) -> String {
  case string.length(value) > 96 {
    True -> string.slice(value, at_index: 0, length: 93) <> "..."
    False -> value
  }
}

fn option_text(value: Option(String), fallback: String) -> String {
  case value {
    Some(text) -> text
    None -> fallback
  }
}

fn int_option_text(value: Option(Int)) -> String {
  case value {
    Some(value) -> int.to_string(value)
    None -> "-"
  }
}

fn result_panel(summary: ResultSummary) -> Element(Message) {
  case summary {
    Empty ->
      html.div([attribute.class("result muted")], [
        html.text("No request sent yet."),
      ])

    Loading ->
      html.div([attribute.class("result loading")], [
        html.text("Waiting for master..."),
      ])

    Success(summary, body) -> ingest_result_panel(summary, body)

    Failure(message) ->
      html.div([attribute.class("result failure")], [
        html.strong([], [html.text("Request failed")]),
        html.pre([], [html.text(message)]),
      ])
  }
}

fn ingest_result_panel(summary: String, body: String) -> Element(Message) {
  case json.parse(body, ingest_response_decoder()) {
    Ok(report) ->
      html.div([attribute.class("result success ingest-result")], [
        html.strong([], [html.text(summary)]),
        ingest_metrics(report),
        html.div([attribute.class("insight-grid")], [
          distribution_view(
            "Work item kind",
            count_ingest_kinds(report.work_items),
            list.length(report.work_items),
          ),
          distribution_view(
            "Queue status",
            count_ingest_statuses(report.work_items),
            list.length(report.work_items),
          ),
          distribution_view(
            "Discarded rows",
            count_discard_reasons(report.discarded_rows),
            list.length(report.discarded_rows),
          ),
        ]),
        html.details([attribute.class("raw-response")], [
          html.summary([], [html.text("Raw ingest response")]),
          html.pre([], [html.text(pretty_body(body))]),
        ]),
      ])

    Error(_) ->
      html.div([attribute.class("result success")], [
        html.strong([], [html.text(summary)]),
        html.pre([], [html.text(pretty_body(body))]),
      ])
  }
}

fn ingest_metrics(report: IngestResponse) -> Element(Message) {
  html.div([attribute.class("queue-summary ingest-summary")], [
    status_metric("STAs", report.sta_count, "status-all"),
    status_metric("URLs", report.item_count, "status-all"),
    status_metric("Queued", report.work_item_count, "status-succeeded"),
    status_metric("Missing URL", report.skipped_missing_url, "status-pending"),
    status_metric(
      "Discarded",
      list.length(report.discarded_rows),
      "status-failed",
    ),
  ])
}

fn distribution_view(
  title: String,
  counts: List(CountRow),
  total: Int,
) -> Element(Message) {
  html.div([attribute.class("distribution")], [
    html.h3([], [html.text(title)]),
    case counts {
      [] ->
        html.div([attribute.class("distribution-empty")], [
          html.text("No rows"),
        ])
      _ ->
        html.div(
          [attribute.class("distribution-list")],
          list.map(counts, distribution_row(_, total)),
        )
    },
  ])
}

fn distribution_row(row: CountRow, total: Int) -> Element(Message) {
  let CountRow(label:, count:) = row
  let percent = percent(count, total)
  html.div([attribute.class("bar-row")], [
    html.div([attribute.class("bar-top")], [
      html.span([], [html.text(readable_label(label))]),
      html.strong([], [
        html.text(
          int.to_string(count)
          <> case total {
            0 -> ""
            _ -> " (" <> int.to_string(percent) <> "%)"
          },
        ),
      ]),
    ]),
    html.div([attribute.class("bar-track")], [
      html.span(
        [
          attribute.class("bar-fill"),
          attribute.style("width", int.to_string(bar_percent(percent)) <> "%"),
        ],
        [],
      ),
    ]),
  ])
}

fn count_ingest_kinds(items: List(IngestWorkItem)) -> List(CountRow) {
  list.fold(items, [], fn(counts, item) { increment_count(counts, item.kind) })
}

fn count_ingest_statuses(items: List(IngestWorkItem)) -> List(CountRow) {
  list.fold(items, [], fn(counts, item) { increment_count(counts, item.status) })
}

fn count_discard_reasons(rows: List(DiscardedRow)) -> List(CountRow) {
  list.fold(rows, [], fn(counts, row) { increment_count(counts, row.reason) })
}

fn increment_count(counts: List(CountRow), label: String) -> List(CountRow) {
  let label = case string.trim(label) {
    "" -> "missing"
    label -> label
  }

  case counts {
    [] -> [CountRow(label, 1)]
    [row, ..rest] -> {
      let CountRow(row_label, count) = row
      case row_label == label {
        True -> [CountRow(row_label, count + 1), ..rest]
        False -> [row, ..increment_count(rest, label)]
      }
    }
  }
}

fn percent(count: Int, total: Int) -> Int {
  case total <= 0 {
    True -> 0
    False ->
      case int.divide(count * 100, total) {
        Ok(value) -> value
        Error(Nil) -> 0
      }
  }
}

fn percent_text(count: Int, total: Int) -> String {
  int.to_string(percent(count, total)) <> "%"
}

fn count_detail(count: Int, total: Int) -> String {
  int.to_string(count) <> " of " <> int.to_string(total)
}

fn bytes_text(bytes: Int) -> String {
  case bytes < 1024 {
    True -> int.to_string(bytes) <> " B"
    False ->
      case bytes < 1_048_576 {
        True -> int.to_string(divide_or_zero(bytes, 1024)) <> " KB"
        False ->
          case bytes < 1_073_741_824 {
            True -> int.to_string(divide_or_zero(bytes, 1_048_576)) <> " MB"
            False ->
              int.to_string(divide_or_zero(bytes, 1_073_741_824)) <> " GB"
          }
      }
  }
}

fn divide_or_zero(value: Int, divisor: Int) -> Int {
  case int.divide(value, divisor) {
    Ok(value) -> value
    Error(Nil) -> 0
  }
}

fn bar_percent(percent: Int) -> Int {
  case percent {
    0 -> 0
    _ -> int.max(4, percent)
  }
}

fn readable_label(label: String) -> String {
  label
  |> string.replace(each: "_", with: " ")
  |> string.replace(each: "-", with: " ")
}

fn pretty_body(body: String) -> String {
  case string.length(body) > 2400 {
    True -> string.slice(body, at_index: 0, length: 2400) <> "\n..."
    False -> body
  }
}

fn stylesheet() -> String {
  "
:root {
  color-scheme: light;
  --ink: oklch(24% 0.025 225);
  --muted: oklch(48% 0.025 225);
  --paper: oklch(97% 0.012 92);
  --panel: oklch(99% 0.006 92);
  --line: oklch(86% 0.025 92);
  --accent: oklch(54% 0.13 158);
  --accent-ink: oklch(21% 0.05 158);
  --danger: oklch(49% 0.15 28);
  --space-xs: 4px;
  --space-sm: 8px;
  --space-md: 12px;
  --space-lg: 16px;
  --space-xl: 24px;
  --space-2xl: 32px;
  --space-3xl: 48px;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  font-family: Avenir Next, Avenir, Segoe UI, sans-serif;
  color: var(--ink);
  background:
    linear-gradient(90deg, oklch(92% 0.018 92) 1px, transparent 1px),
    linear-gradient(0deg, oklch(92% 0.018 92) 1px, transparent 1px),
    var(--paper);
  background-size: 48px 48px;
}

button, input { font: inherit; }

.shell {
  width: min(1120px, calc(100vw - 32px));
  min-height: 100vh;
  margin: 0 auto;
  padding: var(--space-3xl) 0;
  display: grid;
  gap: var(--space-2xl);
}

.mast {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: end;
  gap: var(--space-xl);
}

.mast-copy { max-width: 720px; }

.eyebrow {
  margin: 0 0 var(--space-sm);
  color: var(--accent-ink);
  font-size: 0.78rem;
  font-weight: 800;
  letter-spacing: 0;
  text-transform: uppercase;
}

h1, h2, h3, p { margin: 0; }

h1 {
  max-width: 760px;
  font-family: Optima, Candara, Segoe, sans-serif;
  font-size: clamp(2.4rem, 5vw, 5rem);
  line-height: 0.95;
  font-weight: 800;
}

h2 {
  font-size: 1.2rem;
  line-height: 1.15;
}

.lede {
  max-width: 68ch;
  margin-top: var(--space-lg);
  color: var(--muted);
  font-size: 1.02rem;
  line-height: 1.55;
}

.status-tile, .pill {
  border: 1px solid var(--line);
  background: color-mix(in oklch, var(--panel), var(--accent) 7%);
}

.status-tile {
  display: inline-flex;
  align-items: center;
  gap: var(--space-sm);
  padding: 10px 12px;
  border-radius: 8px;
  font-weight: 700;
  white-space: nowrap;
}

.dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--accent);
}

.workspace {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: var(--space-xl);
  align-items: start;
}

.queue-panel {
  width: 100%;
}

.panel {
  display: grid;
  gap: var(--space-xl);
  padding: var(--space-xl);
  border: 1px solid var(--line);
  border-radius: 8px;
  background: var(--panel);
  box-shadow: 0 18px 50px oklch(30% 0.03 225 / 0.08);
}

.panel-head {
  display: flex;
  justify-content: space-between;
  align-items: start;
  gap: var(--space-lg);
}

.pill {
  padding: 6px 10px;
  border-radius: 999px;
  color: var(--accent-ink);
  font-size: 0.82rem;
  font-weight: 800;
  white-space: nowrap;
}

.dropzone {
  min-height: 210px;
  display: grid;
  place-items: center;
  gap: var(--space-sm);
  padding: var(--space-2xl);
  border: 1px dashed oklch(65% 0.04 225);
  border-radius: 8px;
  background: oklch(96% 0.018 92);
  text-align: center;
  cursor: pointer;
}

.access-key {
  display: grid;
  gap: var(--space-sm);
}

.access-key span {
  color: var(--muted);
  font-size: 0.9rem;
  font-weight: 800;
}

.access-key input {
  width: 100%;
  min-height: 42px;
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 0 12px;
  background: oklch(98% 0.006 92);
}

.dropzone input {
  max-width: 100%;
}

.drop-title {
  display: block;
  font-size: 1.35rem;
  font-weight: 800;
}

.drop-copy {
  max-width: 44ch;
  color: var(--muted);
  line-height: 1.45;
}

.actions {
  display: flex;
  justify-content: flex-end;
}

button {
  min-height: 42px;
  border: 1px solid transparent;
  border-radius: 8px;
  padding: 0 16px;
  font-weight: 800;
  cursor: pointer;
}

button:disabled {
  cursor: wait;
  opacity: 0.62;
}

.primary {
  color: oklch(98% 0.01 92);
  background: var(--ink);
}

.secondary {
  color: var(--ink);
  background: oklch(96% 0.012 92);
  border-color: var(--line);
}

.worker-note {
  display: grid;
  gap: var(--space-xs);
  color: var(--muted);
  line-height: 1.45;
}

.worker-note strong { color: var(--ink); }

.result {
  display: grid;
  gap: var(--space-md);
  min-height: 86px;
  padding: var(--space-lg);
  border: 1px solid var(--line);
  border-radius: 8px;
  background: oklch(97% 0.01 92);
}

.result.success {
  background: color-mix(in oklch, var(--panel), var(--accent) 9%);
}

.result.failure {
  color: var(--danger);
  background: oklch(96% 0.025 28);
}

.result.muted, .result.loading {
  color: var(--muted);
}

.queue-result {
  display: grid;
  gap: var(--space-lg);
}

.pager {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: var(--space-lg);
  color: var(--muted);
  font-size: 0.9rem;
  font-weight: 800;
}

.pager-actions {
  display: flex;
  gap: var(--space-sm);
}

.queue-summary {
  display: grid;
  grid-template-columns: repeat(5, minmax(96px, 1fr));
  gap: var(--space-sm);
}

.prepared-summary {
  grid-template-columns: repeat(4, minmax(120px, 1fr));
}

.ingest-summary {
  grid-template-columns: repeat(5, minmax(110px, 1fr));
}

.insight-metrics {
  display: grid;
  grid-template-columns: repeat(5, minmax(120px, 1fr));
  gap: var(--space-sm);
}

.metric {
  min-height: 72px;
  display: grid;
  align-content: center;
  gap: 2px;
  padding: var(--space-md);
  border: 1px solid var(--line);
  border-radius: 8px;
  background: oklch(97% 0.01 92);
}

.metric-value {
  font-size: 1.45rem;
  line-height: 1;
  font-weight: 900;
}

.metric-label {
  color: var(--muted);
  font-size: 0.78rem;
  font-weight: 800;
  text-transform: uppercase;
}

.insight-metric {
  min-height: 92px;
  align-content: start;
}

.metric-detail {
  color: var(--muted);
  font-size: 0.82rem;
  line-height: 1.35;
}

.status-succeeded { background: color-mix(in oklch, var(--panel), var(--accent) 12%); }
.status-failed { background: oklch(96% 0.025 28); }
.status-claimed { background: oklch(95% 0.035 245); }
.status-pending { background: oklch(96% 0.03 82); }

.table-wrap {
  max-height: 560px;
  overflow: auto;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: var(--panel);
}

table {
  width: 100%;
  min-width: 900px;
  table-layout: fixed;
  border-collapse: collapse;
  font-size: 0.86rem;
}

th, td {
  padding: 10px 12px;
  border-bottom: 1px solid var(--line);
  text-align: left;
  vertical-align: top;
}

th {
  position: sticky;
  top: 0;
  z-index: 1;
  color: var(--muted);
  background: oklch(96% 0.012 92);
  font-size: 0.74rem;
  font-weight: 900;
  text-transform: uppercase;
}

tbody tr:last-child td {
  border-bottom: 0;
}

.subject-cell {
  font-weight: 900;
}

.url-cell {
  width: 34%;
}

.url-cell a {
  color: var(--accent-ink);
  text-decoration: none;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.url-cell a:hover {
  text-decoration: underline;
}

.error-cell {
  width: 22%;
  color: var(--danger);
  overflow-wrap: anywhere;
  word-break: break-word;
}

.error-detail {
  color: var(--danger);
}

.error-detail summary,
.raw-response summary {
  cursor: pointer;
  font-weight: 800;
  line-height: 1.35;
}

.error-detail pre {
  max-height: 280px;
  margin-top: var(--space-sm);
  padding: var(--space-sm);
  border: 1px solid oklch(86% 0.035 28);
  border-radius: 8px;
  background: oklch(98% 0.012 28);
  color: oklch(34% 0.08 28);
}

.error-table {
  width: 100%;
  min-width: 0;
  margin-top: var(--space-sm);
  table-layout: auto;
  border: 1px solid oklch(86% 0.035 28);
  border-radius: 8px;
  background: oklch(98% 0.012 28);
  font-size: 0.78rem;
}

.error-table th,
.error-table td {
  padding: 7px 8px;
  border-bottom: 1px solid oklch(90% 0.02 28);
  color: oklch(34% 0.08 28);
}

.error-table th {
  position: static;
  width: 34%;
  background: transparent;
  color: oklch(43% 0.08 28);
  font-size: 0.68rem;
  white-space: nowrap;
}

.error-table td {
  overflow-wrap: anywhere;
  word-break: break-word;
}

.error-table tr:last-child th,
.error-table tr:last-child td {
  border-bottom: 0;
}

.ingest-result {
  gap: var(--space-lg);
}

.insight-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--space-md);
}

.data-insight-grid {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.distribution {
  display: grid;
  align-content: start;
  gap: var(--space-md);
  padding: var(--space-md);
  border: 1px solid var(--line);
  border-radius: 8px;
  background: oklch(98% 0.008 92);
}

.distribution h3 {
  font-size: 0.88rem;
  line-height: 1.2;
}

.distribution-empty {
  color: var(--muted);
  font-size: 0.84rem;
  font-weight: 800;
}

.distribution-list {
  display: grid;
  gap: var(--space-md);
}

.bar-row {
  display: grid;
  gap: 6px;
}

.bar-top {
  display: flex;
  justify-content: space-between;
  gap: var(--space-md);
  color: var(--muted);
  font-size: 0.8rem;
  line-height: 1.3;
}

.bar-top span {
  overflow-wrap: anywhere;
}

.bar-top strong {
  color: var(--ink);
  white-space: nowrap;
}

.bar-track {
  height: 8px;
  overflow: hidden;
  border-radius: 999px;
  background: oklch(91% 0.018 92);
}

.bar-fill {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--accent);
}

.raw-response {
  display: grid;
  gap: var(--space-sm);
}

.raw-response pre {
  max-height: 300px;
}

.cell-muted {
  margin-top: 4px;
  color: var(--muted);
  overflow-wrap: anywhere;
  word-break: break-word;
  line-height: 1.35;
}

.prepared-table {
  min-width: 1180px;
}

.prepared-table-wrap {
  max-height: 680px;
}

.excerpt-cell {
  width: 38%;
}

.excerpt-cell p {
  margin-top: 6px;
  line-height: 1.42;
}

.excerpt {
  color: var(--muted);
  overflow-wrap: anywhere;
  word-break: break-word;
}

.status-badge {
  display: inline-flex;
  min-width: 82px;
  justify-content: center;
  padding: 4px 8px;
  border: 1px solid var(--line);
  border-radius: 999px;
  font-size: 0.76rem;
  font-weight: 900;
}

.status-badge.is-succeeded {
  color: oklch(27% 0.08 158);
  background: color-mix(in oklch, var(--panel), var(--accent) 16%);
}

.status-badge.is-failed {
  color: var(--danger);
  background: oklch(96% 0.025 28);
}

.status-badge.is-claimed {
  color: oklch(32% 0.08 245);
  background: oklch(95% 0.035 245);
}

.status-badge.is-pending {
  color: oklch(35% 0.08 82);
  background: oklch(96% 0.03 82);
}

pre {
  max-height: 360px;
  margin: 0;
  overflow: auto;
  color: oklch(35% 0.025 225);
  white-space: pre-wrap;
  word-break: break-word;
  font-size: 0.82rem;
  line-height: 1.45;
}

@media (max-width: 820px) {
  .shell { padding: var(--space-2xl) 0; }
  .mast, .workspace { grid-template-columns: 1fr; }
  .status-tile { justify-self: start; }
  .queue-summary { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .prepared-summary { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .ingest-summary { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .insight-metrics { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .insight-grid { grid-template-columns: 1fr; }
}
"
}
