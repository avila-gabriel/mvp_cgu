import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import master/work_items/queries/sql as query
import pog
import shared/sta
import shared/url

pub type WorkItemRow {
  WorkItemRow(
    total_count: Int,
    work_item_id: String,
    subject_id: String,
    kind: String,
    url: String,
    archive_date: Option(String),
    status: String,
    priority: Int,
    attempts: Int,
    max_attempts: Int,
    last_error: Option(String),
    available_at: String,
    inserted_at: String,
    updated_at: String,
  )
}

pub type ClaimedWorkItemRow {
  ClaimedWorkItemRow(
    lease_id: String,
    lease_expires_at: String,
    work_item_id: String,
    subject_id: String,
    kind: String,
    url: String,
    archive_date: Option(String),
    metadata_json: String,
    attempts: Int,
    max_attempts: Int,
  )
}

pub type RenewedLeaseRow {
  RenewedLeaseRow(lease_expires_at: String)
}

pub type EnqueuedWorkItemRow {
  EnqueuedWorkItemRow(
    work_item_id: String,
    subject_id: String,
    kind: String,
    status: String,
  )
}

pub type CompletedWorkItemRow {
  CompletedWorkItemRow(
    work_item_id: String,
    artifact_id: String,
    status: String,
  )
}

pub type FailedWorkItemRow {
  FailedWorkItemRow(
    work_item_id: String,
    status: String,
    attempts: Int,
    max_attempts: Int,
  )
}

pub fn list(
  db: pog.Connection,
  limit: Int,
  offset: Int,
) -> Result(pog.Returned(WorkItemRow), pog.QueryError) {
  query.list(db, limit, offset)
  |> result.map(map_returned(_, list_row))
}

pub fn enqueue_sta_records(
  db: pog.Connection,
  records: List(sta.STA),
  priority: Int,
) -> Result(pog.Returned(EnqueuedWorkItemRow), pog.QueryError) {
  use rows <- result.try(enqueue_sta_records_loop(db, records, priority, []))
  Ok(pog.Returned(count: list.length(rows), rows:))
}

pub fn claim(
  db: pog.Connection,
  worker_id: String,
  lease_seconds: Float,
) -> Result(pog.Returned(ClaimedWorkItemRow), pog.QueryError) {
  use _ <- result.try(query.expire_leases(db))
  query.claim(db, worker_id, lease_seconds)
  |> result.map(map_returned(_, claim_row))
}

pub fn renew_lease(
  db: pog.Connection,
  work_item_id: String,
  lease_id: String,
  worker_id: String,
  lease_seconds: Float,
) -> Result(pog.Returned(RenewedLeaseRow), pog.QueryError) {
  query.renew_lease(db, work_item_id, lease_id, worker_id, lease_seconds)
  |> result.map(map_returned(_, renew_lease_row))
}

pub fn complete(
  db: pog.Connection,
  work_item_id: String,
  lease_id: String,
  worker_id: String,
  fetched_url: String,
  status_code: Option(Int),
  content_type: Option(String),
  body_sha256: String,
  body_size_bytes: Int,
  storage_url: String,
  storage_sha256: String,
  storage_size_bytes: Int,
  storage_content_encoding: String,
  metadata_json: String,
) -> Result(pog.Returned(CompletedWorkItemRow), pog.QueryError) {
  case status_code, content_type {
    Some(status_code), Some(content_type) ->
      query.complete(
        db,
        work_item_id,
        lease_id,
        worker_id,
        fetched_url,
        status_code,
        content_type,
        body_sha256,
        body_size_bytes,
        storage_url,
        storage_sha256,
        storage_size_bytes,
        storage_content_encoding,
        metadata_json,
      )
      |> result.map(map_returned(_, complete_row))

    Some(status_code), None ->
      query.complete_without_content_type(
        db,
        work_item_id,
        lease_id,
        worker_id,
        fetched_url,
        status_code,
        body_sha256,
        body_size_bytes,
        storage_url,
        storage_sha256,
        storage_size_bytes,
        storage_content_encoding,
        metadata_json,
      )
      |> result.map(map_returned(_, complete_without_content_type_row))

    None, Some(content_type) ->
      query.complete_without_status_code(
        db,
        work_item_id,
        lease_id,
        worker_id,
        fetched_url,
        content_type,
        body_sha256,
        body_size_bytes,
        storage_url,
        storage_sha256,
        storage_size_bytes,
        storage_content_encoding,
        metadata_json,
      )
      |> result.map(map_returned(_, complete_without_status_code_row))

    None, None ->
      query.complete_without_response_details(
        db,
        work_item_id,
        lease_id,
        worker_id,
        fetched_url,
        body_sha256,
        body_size_bytes,
        storage_url,
        storage_sha256,
        storage_size_bytes,
        storage_content_encoding,
        metadata_json,
      )
      |> result.map(map_returned(_, complete_without_response_details_row))
  }
}

pub fn completed_by_lease(
  db: pog.Connection,
  work_item_id: String,
  lease_id: String,
  worker_id: String,
) -> Result(pog.Returned(CompletedWorkItemRow), pog.QueryError) {
  query.completed_by_lease(db, work_item_id, lease_id, worker_id)
  |> result.map(map_returned(_, completed_by_lease_row))
}

pub fn fail(
  db: pog.Connection,
  work_item_id: String,
  lease_id: String,
  worker_id: String,
  error: String,
  retryable: Bool,
  backoff_seconds: Float,
) -> Result(pog.Returned(FailedWorkItemRow), pog.QueryError) {
  query.fail(
    db,
    work_item_id,
    lease_id,
    worker_id,
    error,
    retryable,
    backoff_seconds,
  )
  |> result.map(map_returned(_, fail_row))
}

fn enqueue_sta_records_loop(
  db: pog.Connection,
  records: List(sta.STA),
  priority: Int,
  acc: List(EnqueuedWorkItemRow),
) -> Result(List(EnqueuedWorkItemRow), pog.QueryError) {
  case records {
    [] -> Ok(list.reverse(acc))
    [sta, ..rest] -> {
      use acc <- result.try(enqueue_sta_items_loop(
        db,
        sta.id_to_string(sta.id),
        sta.items,
        priority,
        acc,
      ))
      enqueue_sta_records_loop(db, rest, priority, acc)
    }
  }
}

fn enqueue_sta_items_loop(
  db: pog.Connection,
  sta_id: String,
  items: List(sta.STAItem),
  priority: Int,
  acc: List(EnqueuedWorkItemRow),
) -> Result(List(EnqueuedWorkItemRow), pog.QueryError) {
  case items {
    [] -> Ok(acc)
    [item, ..rest] -> {
      use returned <- result.try(query.enqueue_sta_item(
        db,
        sta_id,
        item.source_key,
        url.to_string(item.url),
        verification_status(item.status),
        priority,
        "web.archive.org",
        item.current_archive_date,
        first_archive_fallback_date(item),
        archive_fallback_dates_json(item),
        item.metadata_json,
      ))
      let rows = list.map(returned.rows, enqueue_sta_item_row)
      enqueue_sta_items_loop(db, sta_id, rest, priority, append_rows(rows, acc))
    }
  }
}

fn first_archive_fallback_date(item: sta.STAItem) -> String {
  case item.archive_fallback_dates {
    [date, ..] -> date
    [] -> ""
  }
}

fn archive_fallback_dates_json(item: sta.STAItem) -> String {
  item.archive_fallback_dates
  |> json.array(json.string)
  |> json.to_string
}

fn map_returned(
  returned: pog.Returned(a),
  mapper: fn(a) -> b,
) -> pog.Returned(b) {
  pog.Returned(count: returned.count, rows: list.map(returned.rows, mapper))
}

fn list_row(row: query.ListRow) -> WorkItemRow {
  let query.ListRow(
    total_count:,
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

  WorkItemRow(
    total_count:,
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
  )
}

fn claim_row(row: query.ClaimRow) -> ClaimedWorkItemRow {
  let query.ClaimRow(
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

  ClaimedWorkItemRow(
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
  )
}

fn renew_lease_row(row: query.RenewLeaseRow) -> RenewedLeaseRow {
  let query.RenewLeaseRow(lease_expires_at:) = row
  RenewedLeaseRow(lease_expires_at:)
}

fn enqueue_sta_item_row(row: query.EnqueueStaItemRow) -> EnqueuedWorkItemRow {
  let query.EnqueueStaItemRow(work_item_id:, subject_id:, kind:, status:) = row
  EnqueuedWorkItemRow(work_item_id:, subject_id:, kind:, status:)
}

fn complete_row(row: query.CompleteRow) -> CompletedWorkItemRow {
  let query.CompleteRow(work_item_id:, artifact_id:, status:) = row
  CompletedWorkItemRow(work_item_id:, artifact_id:, status:)
}

fn complete_without_content_type_row(
  row: query.CompleteWithoutContentTypeRow,
) -> CompletedWorkItemRow {
  let query.CompleteWithoutContentTypeRow(work_item_id:, artifact_id:, status:) =
    row
  CompletedWorkItemRow(work_item_id:, artifact_id:, status:)
}

fn complete_without_status_code_row(
  row: query.CompleteWithoutStatusCodeRow,
) -> CompletedWorkItemRow {
  let query.CompleteWithoutStatusCodeRow(work_item_id:, artifact_id:, status:) =
    row
  CompletedWorkItemRow(work_item_id:, artifact_id:, status:)
}

fn complete_without_response_details_row(
  row: query.CompleteWithoutResponseDetailsRow,
) -> CompletedWorkItemRow {
  let query.CompleteWithoutResponseDetailsRow(
    work_item_id:,
    artifact_id:,
    status:,
  ) = row
  CompletedWorkItemRow(work_item_id:, artifact_id:, status:)
}

fn completed_by_lease_row(
  row: query.CompletedByLeaseRow,
) -> CompletedWorkItemRow {
  let query.CompletedByLeaseRow(work_item_id:, artifact_id:, status:) = row
  CompletedWorkItemRow(work_item_id:, artifact_id:, status:)
}

fn fail_row(row: query.FailRow) -> FailedWorkItemRow {
  let query.FailRow(work_item_id:, status:, attempts:, max_attempts:) = row
  FailedWorkItemRow(work_item_id:, status:, attempts:, max_attempts:)
}

fn verification_status(
  status: sta.VerificationStatus,
) -> query.VerificationStatus {
  case status {
    sta.NotVerified -> query.NotVerified
    sta.Conform -> query.Conform
    sta.NonConform -> query.NonConform
  }
}

fn append_rows(
  rows: List(EnqueuedWorkItemRow),
  acc: List(EnqueuedWorkItemRow),
) {
  case rows {
    [] -> acc
    [row, ..rest] -> append_rows(rest, [row, ..acc])
  }
}
