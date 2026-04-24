import gleam/bit_array
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import master/csv_ingest
import master/log
import master/storage
import master/web.{type Context}
import master/work_items/sql
import master/xlsx_ingest as xlsx
import shared/sta
import shared/work_items as transport
import wisp.{type Request, type Response}

const default_page_limit = 100

const max_page_limit = 500

pub fn work_items(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> list(req, ctx)
    _ -> wisp.method_not_allowed([Get])
  }
}

pub fn list(req: Request, ctx: Context) -> Response {
  let query = wisp.get_query(req)
  let limit = query_int(query, "limit", default_page_limit, 1, max_page_limit)
  let offset = query_int(query, "offset", 0, 0, 1_000_000_000)

  use rows <- web.require_many_query(
    sql.list(ctx.db, limit, offset),
    while: "list work items",
  )

  case map_rows(rows, work_item_from_row) {
    Ok(items) -> {
      let total_count = case rows {
        [first, ..] -> first.total_count
        [] -> 0
      }

      json.object([
        #("total_count", json.int(total_count)),
        #("limit", json.int(limit)),
        #("offset", json.int(offset)),
        #("items", json.array(items, transport.work_item_to_json)),
      ])
      |> json.to_string
      |> wisp.json_response(200)
    }

    Error(Nil) -> wisp.internal_server_error()
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

pub fn claim(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use input <- web.require_parsed_json(req, claim_decoder())
  use row <- web.require_optional_query(
    sql.claim(ctx.db, input.worker_id, input.lease_seconds),
    while: "claim work item",
  )

  case row {
    Some(row) ->
      case claimed_work_item_from_row(row) {
        Ok(item) ->
          item
          |> transport.claimed_work_item_to_json
          |> json.to_string
          |> wisp.json_response(200)

        Error(Nil) -> wisp.internal_server_error()
      }

    None -> wisp.no_content()
  }
}

pub fn renew_lease(
  req: Request,
  ctx: Context,
  work_item_id: String,
) -> Response {
  use <- wisp.require_method(req, Post)
  use input <- web.require_parsed_json(
    req,
    transport.renew_lease_request_decoder(),
  )
  use row <- web.require_optional_query(
    sql.renew_lease(
      ctx.db,
      work_item_id,
      input.lease_id,
      input.worker_id,
      input.lease_seconds,
    ),
    while: "renew work item lease",
  )

  case row {
    Some(row) ->
      transport.RenewLeaseResponse(lease_expires_at: row.lease_expires_at)
      |> transport.renew_lease_response_to_json
      |> json.to_string
      |> wisp.json_response(200)

    None ->
      json.object([#("error", json.string("work_item_lease_conflict"))])
      |> json.to_string
      |> wisp.json_response(409)
  }
}

pub fn complete(req: Request, ctx: Context, work_item_id: String) -> Response {
  use <- wisp.require_method(req, Post)
  use input <- web.require_parsed_json(req, complete_decoder())
  use existing <- web.require_optional_query(
    sql.completed_by_lease(
      ctx.db,
      work_item_id,
      input.lease_id,
      input.worker_id,
    ),
    while: "find completed work item",
  )

  case existing {
    Some(row) -> completed_response(row)
    None -> complete_new(ctx, work_item_id, input)
  }
}

fn complete_new(
  ctx: Context,
  work_item_id: String,
  input: transport.CompleteRequest,
) -> Response {
  use body <- require_body(input.body_base64)
  use stored <- require_stored_body(ctx.storage, body)
  use row <- web.require_optional_query(
    sql.complete(
      ctx.db,
      work_item_id,
      input.lease_id,
      input.worker_id,
      input.fetched_url,
      input.status_code,
      input.content_type,
      stored.body_sha256,
      stored.body_size_bytes,
      stored.storage_url,
      stored.storage_sha256,
      stored.storage_size_bytes,
      stored.storage_content_encoding,
      input.metadata_json,
    ),
    while: "complete work item",
  )

  case row {
    Some(row) -> completed_response(row)
    None -> completion_lease_conflict(work_item_id, input)
  }
}

fn completion_lease_conflict(
  work_item_id: String,
  input: transport.CompleteRequest,
) -> Response {
  log.error(
    "complete work item",
    "lease conflict for work_item_id="
      <> work_item_id
      <> " lease_id="
      <> input.lease_id
      <> " worker_id="
      <> input.worker_id,
  )

  json.object([#("error", json.string("work_item_lease_conflict"))])
  |> json.to_string
  |> wisp.json_response(409)
}

fn completed_response(row: sql.CompletedWorkItemRow) -> Response {
  case completed_work_item_from_row(row) {
    Ok(item) ->
      item
      |> transport.completed_work_item_to_json
      |> json.to_string
      |> wisp.json_response(200)

    Error(Nil) -> wisp.internal_server_error()
  }
}

fn require_body(
  body_base64: String,
  next: fn(BitArray) -> Response,
) -> Response {
  case bit_array.base64_decode(body_base64) {
    Ok(body) -> next(body)
    Error(Nil) -> wisp.bad_request("body_base64 must be valid base64.")
  }
}

fn require_stored_body(
  config: storage.Config,
  body: BitArray,
  next: fn(storage.StoredBody) -> Response,
) -> Response {
  case storage.store(config, body) {
    Ok(stored) -> next(stored)
    Error(error) -> {
      log.error("store artifact", storage.describe_error(error))
      wisp.internal_server_error()
    }
  }
}

pub fn fail(req: Request, ctx: Context, work_item_id: String) -> Response {
  use <- wisp.require_method(req, Post)
  use input <- web.require_parsed_json(req, fail_decoder())
  use row <- web.require_one_query(
    sql.fail(
      ctx.db,
      work_item_id,
      input.lease_id,
      input.worker_id,
      input.error,
      input.retryable,
      input.backoff_seconds,
    ),
    while: "fail work item",
  )

  case failed_work_item_from_row(row) {
    Ok(item) ->
      item
      |> transport.failed_work_item_to_json
      |> json.to_string
      |> wisp.json_response(200)

    Error(Nil) -> wisp.internal_server_error()
  }
}

pub fn csv_ingest(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_string_body(req)

  case csv_ingest.parse(body) {
    Error(error) -> {
      log.warning(
        "parse CSV ingest body",
        csv_ingest.parse_error_to_string(error),
      )
      json.object([
        #("error", json.string("csv_parse_error")),
        #("detail", json.string(csv_ingest.parse_error_to_string(error))),
      ])
      |> json.to_string
      |> wisp.json_response(400)
    }

    Ok(records) -> {
      use rows <- web.require_many_query(
        sql.enqueue_sta_records(ctx.db, records, 0),
        while: "ingest CSV",
      )
      let work_items = unique_enqueued_rows(rows)

      json.object([
        #("sta_count", json.int(list.length(records))),
        #("item_count", json.int(item_count(records))),
        #("work_item_count", json.int(list.length(work_items))),
        #("work_items", json.array(work_items, enqueued_row_to_json)),
      ])
      |> json.to_string
      |> wisp.json_response(201)
    }
  }
}

pub fn xlsx_ingest(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_bit_array_body(req)

  case xlsx.parse_zip(body) {
    Error(error) -> {
      log.warning("parse XLSX ingest body", xlsx.parse_error_to_string(error))
      json.object([
        #("error", json.string("xlsx_parse_error")),
        #("detail", json.string(xlsx.parse_error_to_string(error))),
      ])
      |> json.to_string
      |> wisp.json_response(400)
    }

    Ok(report) -> {
      log_xlsx_discarded_rows(report.discarded_rows)

      use rows <- web.require_many_query(
        sql.enqueue_sta_records(ctx.db, report.records, 0),
        while: "ingest XLSX zip",
      )
      let work_items = unique_enqueued_rows(rows)

      json.object([
        #("sta_count", json.int(list.length(report.records))),
        #("item_count", json.int(item_count(report.records))),
        #("skipped_missing_url", json.int(report.skipped_missing_url)),
        #(
          "discarded_rows",
          json.array(report.discarded_rows, xlsx_discarded_row_to_json),
        ),
        #("work_item_count", json.int(list.length(work_items))),
        #("work_items", json.array(work_items, enqueued_row_to_json)),
      ])
      |> json.to_string
      |> wisp.json_response(201)
    }
  }
}

fn log_xlsx_discarded_rows(discarded_rows: List(xlsx.DiscardedRow)) -> Nil {
  case discarded_rows {
    [] -> Nil
    _ -> {
      let detail =
        discarded_rows
        |> json.array(xlsx_discarded_row_to_json)
        |> json.to_string

      log.warning("discard XLSX ingest rows", detail)
    }
  }
}

fn xlsx_discarded_row_to_json(row: xlsx.DiscardedRow) -> json.Json {
  json.object([
    #("file", json.string(row.file)),
    #("row", json.int(row.row)),
    #("reason", json.string(row.reason)),
    #("sta_id", json.string(row.sta_id)),
    #("item_url", json.string(row.item_url)),
    #("assunto", json.string(row.assunto)),
    #("item", json.string(row.item)),
  ])
}

fn claim_decoder() -> decode.Decoder(transport.ClaimRequest) {
  transport.claim_request_decoder()
}

fn complete_decoder() -> decode.Decoder(transport.CompleteRequest) {
  transport.complete_request_decoder()
}

fn fail_decoder() -> decode.Decoder(transport.FailRequest) {
  transport.fail_request_decoder()
}

fn work_item_from_row(row: sql.WorkItemRow) -> Result(transport.WorkItem, Nil) {
  let sql.WorkItemRow(
    total_count: _,
    work_item_id:,
    subject_id:,
    kind:,
    url:,
    archive_date:,
    status:,
    priority:,
    attempts:,
    max_attempts:,
    last_error:,
    available_at:,
    inserted_at:,
    updated_at:,
  ) = row

  case
    transport.work_kind_from_string(kind),
    transport.work_status_from_string(status)
  {
    Ok(kind), Ok(status) ->
      Ok(transport.WorkItem(
        work_item_id:,
        subject_id:,
        kind: kind,
        url:,
        archive_date:,
        status: status,
        priority:,
        attempts:,
        max_attempts:,
        last_error:,
        available_at:,
        inserted_at:,
        updated_at:,
      ))

    _, _ -> Error(Nil)
  }
}

fn claimed_work_item_from_row(
  row: sql.ClaimedWorkItemRow,
) -> Result(transport.ClaimedWorkItem, Nil) {
  let sql.ClaimedWorkItemRow(
    lease_id:,
    lease_expires_at:,
    work_item_id:,
    subject_id:,
    kind:,
    url:,
    archive_date:,
    metadata_json:,
    attempts:,
    max_attempts:,
  ) = row

  case transport.work_kind_from_string(kind) {
    Ok(kind) ->
      Ok(transport.ClaimedWorkItem(
        lease_id:,
        lease_expires_at:,
        work_item_id:,
        subject_id:,
        kind: kind,
        url:,
        archive_date:,
        metadata_json:,
        attempts:,
        max_attempts:,
      ))

    Error(Nil) -> Error(Nil)
  }
}

fn enqueued_work_item_from_row(
  row: sql.EnqueuedWorkItemRow,
) -> Result(transport.EnqueuedWorkItem, Nil) {
  let sql.EnqueuedWorkItemRow(work_item_id:, subject_id:, kind:, status:) = row

  case
    transport.work_kind_from_string(kind),
    transport.work_status_from_string(status)
  {
    Ok(kind), Ok(status) ->
      Ok(transport.EnqueuedWorkItem(work_item_id:, subject_id:, kind:, status:))

    _, _ -> Error(Nil)
  }
}

fn completed_work_item_from_row(
  row: sql.CompletedWorkItemRow,
) -> Result(transport.CompletedWorkItem, Nil) {
  let sql.CompletedWorkItemRow(work_item_id:, artifact_id:, status:) = row

  case transport.work_status_from_string(status) {
    Ok(status) ->
      Ok(transport.CompletedWorkItem(work_item_id:, artifact_id:, status:))

    Error(Nil) -> Error(Nil)
  }
}

fn failed_work_item_from_row(
  row: sql.FailedWorkItemRow,
) -> Result(transport.FailedWorkItem, Nil) {
  let sql.FailedWorkItemRow(work_item_id:, status:, attempts:, max_attempts:) =
    row

  case transport.work_status_from_string(status) {
    Ok(status) ->
      Ok(transport.FailedWorkItem(
        work_item_id:,
        status:,
        attempts:,
        max_attempts:,
      ))

    Error(Nil) -> Error(Nil)
  }
}

fn map_rows(
  rows: List(a),
  map: fn(a) -> Result(b, Nil),
) -> Result(List(b), Nil) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      case map(first), map_rows(rest, map) {
        Ok(mapped), Ok(mapped_rest) -> Ok([mapped, ..mapped_rest])
        _, _ -> Error(Nil)
      }
    }
  }
}

fn item_count(stas: List(sta.STA)) -> Int {
  stas
  |> list.fold(0, fn(count, sta) { count + list.length(sta.items) })
}

fn unique_enqueued_rows(rows: List(sql.EnqueuedWorkItemRow)) {
  rows
  |> unique_enqueued_rows_loop([], [])
}

fn unique_enqueued_rows_loop(
  rows: List(sql.EnqueuedWorkItemRow),
  seen_ids: List(String),
  acc: List(sql.EnqueuedWorkItemRow),
) {
  case rows {
    [] -> list.reverse(acc)
    [row, ..rest] ->
      case list.contains(seen_ids, row.work_item_id) {
        True -> unique_enqueued_rows_loop(rest, seen_ids, acc)
        False ->
          unique_enqueued_rows_loop(rest, [row.work_item_id, ..seen_ids], [
            row,
            ..acc
          ])
      }
  }
}

fn enqueued_row_to_json(row: sql.EnqueuedWorkItemRow) -> json.Json {
  case enqueued_work_item_from_row(row) {
    Ok(item) -> transport.enqueued_work_item_to_json(item)
    Error(Nil) ->
      json.object([
        #("work_item_id", json.string(row.work_item_id)),
        #("subject_id", json.string(row.subject_id)),
        #("kind", json.string(row.kind)),
        #("status", json.string(row.status)),
      ])
  }
}
