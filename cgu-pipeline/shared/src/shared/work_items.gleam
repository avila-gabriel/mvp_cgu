import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option}
import shared/url.{type Url}

pub type WorkKind {
  SnapshotCurrent
  SnapshotArchive
}

pub type WorkStatus {
  Pending
  Running
  Succeeded
  Failed
  Dead
}

pub type EnqueueRequest {
  EnqueueRequest(
    subject_id: String,
    url: Url,
    archive_date: Option(String),
    priority: Int,
  )
}

pub type ClaimRequest {
  ClaimRequest(worker_id: String, lease_seconds: Float)
}

pub type RenewLeaseRequest {
  RenewLeaseRequest(worker_id: String, lease_id: String, lease_seconds: Float)
}

pub type RenewLeaseResponse {
  RenewLeaseResponse(lease_expires_at: String)
}

pub type WorkerHeartbeatRequest {
  WorkerHeartbeatRequest(worker_id: String, capacity: Int)
}

pub type WorkerHeartbeatResponse {
  WorkerHeartbeatResponse(assigned_fetch_slots: Int)
}

pub type ProviderSlotAcquireRequest {
  ProviderSlotAcquireRequest(provider_key: String)
}

pub type ProviderSlotAcquireResponse {
  ProviderSlotAcquireResponse(delay_ms: Int)
}

pub type ProviderSlotReportRequest {
  ProviderSlotReportRequest(provider_key: String, status_code: Int)
}

pub type CompleteRequest {
  CompleteRequest(
    worker_id: String,
    lease_id: String,
    fetched_url: String,
    status_code: Option(Int),
    content_type: Option(String),
    body_base64: String,
    metadata_json: String,
  )
}

pub type FailRequest {
  FailRequest(
    worker_id: String,
    lease_id: String,
    error: String,
    retryable: Bool,
    backoff_seconds: Float,
  )
}

pub type WorkItem {
  WorkItem(
    work_item_id: String,
    subject_id: String,
    kind: WorkKind,
    url: String,
    archive_date: Option(String),
    status: WorkStatus,
    priority: Int,
    attempts: Int,
    max_attempts: Int,
    last_error: Option(String),
    available_at: String,
    inserted_at: String,
    updated_at: String,
  )
}

pub type ClaimedWorkItem {
  ClaimedWorkItem(
    lease_id: String,
    lease_expires_at: String,
    work_item_id: String,
    subject_id: String,
    kind: WorkKind,
    url: String,
    archive_date: Option(String),
    metadata_json: String,
    attempts: Int,
    max_attempts: Int,
  )
}

pub type EnqueuedWorkItem {
  EnqueuedWorkItem(
    work_item_id: String,
    subject_id: String,
    kind: WorkKind,
    status: WorkStatus,
  )
}

pub type CompletedWorkItem {
  CompletedWorkItem(
    work_item_id: String,
    artifact_id: String,
    status: WorkStatus,
  )
}

pub type FailedWorkItem {
  FailedWorkItem(
    work_item_id: String,
    status: WorkStatus,
    attempts: Int,
    max_attempts: Int,
  )
}

pub fn enqueue_request_decoder() -> decode.Decoder(EnqueueRequest) {
  use subject_id <- decode.field("subject_id", decode.string)
  use archive_date <- decode.field(
    "archive_date",
    decode.optional(decode.string),
  )
  use priority <- decode.field("priority", decode.int)
  use url <- decode.field("url", url.decoder())
  decode.success(EnqueueRequest(subject_id:, url:, archive_date:, priority:))
}

pub fn claim_request_decoder() -> decode.Decoder(ClaimRequest) {
  use worker_id <- decode.field("worker_id", decode.string)
  use lease_seconds <- decode.field("lease_seconds", float_or_int_decoder())
  decode.success(ClaimRequest(worker_id:, lease_seconds:))
}

pub fn renew_lease_request_decoder() -> decode.Decoder(RenewLeaseRequest) {
  use worker_id <- decode.field("worker_id", decode.string)
  use lease_id <- decode.field("lease_id", decode.string)
  use lease_seconds <- decode.field("lease_seconds", float_or_int_decoder())
  decode.success(RenewLeaseRequest(worker_id:, lease_id:, lease_seconds:))
}

pub fn worker_heartbeat_request_decoder() -> decode.Decoder(
  WorkerHeartbeatRequest,
) {
  use worker_id <- decode.field("worker_id", decode.string)
  use capacity <- decode.field("capacity", decode.int)
  decode.success(WorkerHeartbeatRequest(worker_id:, capacity:))
}

pub fn provider_slot_acquire_request_decoder() -> decode.Decoder(
  ProviderSlotAcquireRequest,
) {
  use provider_key <- decode.field("provider_key", decode.string)
  decode.success(ProviderSlotAcquireRequest(provider_key:))
}

pub fn provider_slot_report_request_decoder() -> decode.Decoder(
  ProviderSlotReportRequest,
) {
  use provider_key <- decode.field("provider_key", decode.string)
  use status_code <- decode.field("status_code", decode.int)
  decode.success(ProviderSlotReportRequest(provider_key:, status_code:))
}

fn float_or_int_decoder() -> decode.Decoder(Float) {
  decode.one_of(decode.float, or: [
    decode.int |> decode.map(int.to_float),
  ])
}

pub fn complete_request_decoder() -> decode.Decoder(CompleteRequest) {
  use worker_id <- decode.field("worker_id", decode.string)
  use lease_id <- decode.field("lease_id", decode.string)
  use fetched_url <- decode.field("fetched_url", decode.string)
  use status_code <- decode.field("status_code", decode.optional(decode.int))
  use content_type <- decode.field(
    "content_type",
    decode.optional(decode.string),
  )
  use body_base64 <- decode.field("body_base64", decode.string)
  use metadata_json <- decode.field("metadata_json", decode.string)
  decode.success(CompleteRequest(
    worker_id:,
    lease_id:,
    fetched_url:,
    status_code:,
    content_type:,
    body_base64:,
    metadata_json:,
  ))
}

pub fn fail_request_decoder() -> decode.Decoder(FailRequest) {
  use worker_id <- decode.field("worker_id", decode.string)
  use lease_id <- decode.field("lease_id", decode.string)
  use error <- decode.field("error", decode.string)
  use retryable <- decode.field("retryable", decode.bool)
  use backoff_seconds <- decode.field("backoff_seconds", float_or_int_decoder())
  decode.success(FailRequest(
    worker_id:,
    lease_id:,
    error:,
    retryable:,
    backoff_seconds:,
  ))
}

pub fn work_item_decoder() -> decode.Decoder(WorkItem) {
  use work_item_id <- decode.field("work_item_id", decode.string)
  use subject_id <- decode.field("subject_id", decode.string)
  use kind <- decode.field("kind", work_kind_decoder())
  use url <- decode.field("url", decode.string)
  use archive_date <- decode.field(
    "archive_date",
    decode.optional(decode.string),
  )
  use status <- decode.field("status", work_status_decoder())
  use priority <- decode.field("priority", decode.int)
  use attempts <- decode.field("attempts", decode.int)
  use max_attempts <- decode.field("max_attempts", decode.int)
  use last_error <- decode.field("last_error", decode.optional(decode.string))
  use available_at <- decode.field("available_at", decode.string)
  use inserted_at <- decode.field("inserted_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  decode.success(WorkItem(
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
  ))
}

pub fn claimed_work_item_decoder() -> decode.Decoder(ClaimedWorkItem) {
  use lease_id <- decode.field("lease_id", decode.string)
  use lease_expires_at <- decode.field("lease_expires_at", decode.string)
  use work_item_id <- decode.field("work_item_id", decode.string)
  use subject_id <- decode.field("subject_id", decode.string)
  use kind <- decode.field("kind", work_kind_decoder())
  use url <- decode.field("url", decode.string)
  use archive_date <- decode.field(
    "archive_date",
    decode.optional(decode.string),
  )
  use metadata_json <- decode.field("metadata_json", decode.string)
  use attempts <- decode.field("attempts", decode.int)
  use max_attempts <- decode.field("max_attempts", decode.int)
  decode.success(ClaimedWorkItem(
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
  ))
}

pub fn renew_lease_response_decoder() -> decode.Decoder(RenewLeaseResponse) {
  use lease_expires_at <- decode.field("lease_expires_at", decode.string)
  decode.success(RenewLeaseResponse(lease_expires_at:))
}

pub fn worker_heartbeat_response_decoder() -> decode.Decoder(
  WorkerHeartbeatResponse,
) {
  use assigned_fetch_slots <- decode.field("assigned_fetch_slots", decode.int)
  decode.success(WorkerHeartbeatResponse(assigned_fetch_slots:))
}

pub fn provider_slot_acquire_response_decoder() -> decode.Decoder(
  ProviderSlotAcquireResponse,
) {
  use delay_ms <- decode.field("delay_ms", decode.int)
  decode.success(ProviderSlotAcquireResponse(delay_ms:))
}

pub fn enqueued_work_item_decoder() -> decode.Decoder(EnqueuedWorkItem) {
  use work_item_id <- decode.field("work_item_id", decode.string)
  use subject_id <- decode.field("subject_id", decode.string)
  use kind <- decode.field("kind", work_kind_decoder())
  use status <- decode.field("status", work_status_decoder())
  decode.success(EnqueuedWorkItem(work_item_id:, subject_id:, kind:, status:))
}

pub fn completed_work_item_decoder() -> decode.Decoder(CompletedWorkItem) {
  use work_item_id <- decode.field("work_item_id", decode.string)
  use artifact_id <- decode.field("artifact_id", decode.string)
  use status <- decode.field("status", work_status_decoder())
  decode.success(CompletedWorkItem(work_item_id:, artifact_id:, status:))
}

pub fn failed_work_item_decoder() -> decode.Decoder(FailedWorkItem) {
  use work_item_id <- decode.field("work_item_id", decode.string)
  use status <- decode.field("status", work_status_decoder())
  use attempts <- decode.field("attempts", decode.int)
  use max_attempts <- decode.field("max_attempts", decode.int)
  decode.success(FailedWorkItem(
    work_item_id:,
    status:,
    attempts:,
    max_attempts:,
  ))
}

pub fn enqueue_request_to_json(request: EnqueueRequest) -> json.Json {
  let EnqueueRequest(subject_id:, url:, archive_date:, priority:) = request

  json.object([
    #("subject_id", json.string(subject_id)),
    #("url", json.string(url.to_string(url))),
    #("archive_date", json.nullable(archive_date, of: json.string)),
    #("priority", json.int(priority)),
  ])
}

pub fn claim_request_to_json(request: ClaimRequest) -> json.Json {
  let ClaimRequest(worker_id:, lease_seconds:) = request

  json.object([
    #("worker_id", json.string(worker_id)),
    #("lease_seconds", json.float(lease_seconds)),
  ])
}

pub fn renew_lease_request_to_json(request: RenewLeaseRequest) -> json.Json {
  let RenewLeaseRequest(worker_id:, lease_id:, lease_seconds:) = request

  json.object([
    #("worker_id", json.string(worker_id)),
    #("lease_id", json.string(lease_id)),
    #("lease_seconds", json.float(lease_seconds)),
  ])
}

pub fn worker_heartbeat_request_to_json(
  request: WorkerHeartbeatRequest,
) -> json.Json {
  let WorkerHeartbeatRequest(worker_id:, capacity:) = request

  json.object([
    #("worker_id", json.string(worker_id)),
    #("capacity", json.int(capacity)),
  ])
}

pub fn provider_slot_acquire_request_to_json(
  request: ProviderSlotAcquireRequest,
) -> json.Json {
  let ProviderSlotAcquireRequest(provider_key:) = request

  json.object([#("provider_key", json.string(provider_key))])
}

pub fn provider_slot_report_request_to_json(
  request: ProviderSlotReportRequest,
) -> json.Json {
  let ProviderSlotReportRequest(provider_key:, status_code:) = request

  json.object([
    #("provider_key", json.string(provider_key)),
    #("status_code", json.int(status_code)),
  ])
}

pub fn complete_request_to_json(request: CompleteRequest) -> json.Json {
  let CompleteRequest(
    worker_id:,
    lease_id:,
    fetched_url:,
    status_code:,
    content_type:,
    body_base64:,
    metadata_json:,
  ) = request

  json.object([
    #("worker_id", json.string(worker_id)),
    #("lease_id", json.string(lease_id)),
    #("fetched_url", json.string(fetched_url)),
    #("status_code", json.nullable(status_code, of: json.int)),
    #("content_type", json.nullable(content_type, of: json.string)),
    #("body_base64", json.string(body_base64)),
    #("metadata_json", json.string(metadata_json)),
  ])
}

pub fn fail_request_to_json(request: FailRequest) -> json.Json {
  let FailRequest(worker_id:, lease_id:, error:, retryable:, backoff_seconds:) =
    request

  json.object([
    #("worker_id", json.string(worker_id)),
    #("lease_id", json.string(lease_id)),
    #("error", json.string(error)),
    #("retryable", json.bool(retryable)),
    #("backoff_seconds", json.float(backoff_seconds)),
  ])
}

pub fn work_item_to_json(item: WorkItem) -> json.Json {
  let WorkItem(
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
  ) = item

  json.object([
    #("work_item_id", json.string(work_item_id)),
    #("subject_id", json.string(subject_id)),
    #("kind", json.string(work_kind_to_string(kind))),
    #("url", json.string(url)),
    #("archive_date", json.nullable(archive_date, of: json.string)),
    #("status", json.string(work_status_to_string(status))),
    #("priority", json.int(priority)),
    #("attempts", json.int(attempts)),
    #("max_attempts", json.int(max_attempts)),
    #("last_error", json.nullable(last_error, of: json.string)),
    #("available_at", json.string(available_at)),
    #("inserted_at", json.string(inserted_at)),
    #("updated_at", json.string(updated_at)),
  ])
}

pub fn claimed_work_item_to_json(item: ClaimedWorkItem) -> json.Json {
  let ClaimedWorkItem(
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
  ) = item

  json.object([
    #("lease_id", json.string(lease_id)),
    #("lease_expires_at", json.string(lease_expires_at)),
    #("work_item_id", json.string(work_item_id)),
    #("subject_id", json.string(subject_id)),
    #("kind", json.string(work_kind_to_string(kind))),
    #("url", json.string(url)),
    #("archive_date", json.nullable(archive_date, of: json.string)),
    #("metadata_json", json.string(metadata_json)),
    #("attempts", json.int(attempts)),
    #("max_attempts", json.int(max_attempts)),
  ])
}

pub fn renew_lease_response_to_json(response: RenewLeaseResponse) -> json.Json {
  let RenewLeaseResponse(lease_expires_at:) = response

  json.object([#("lease_expires_at", json.string(lease_expires_at))])
}

pub fn worker_heartbeat_response_to_json(
  response: WorkerHeartbeatResponse,
) -> json.Json {
  let WorkerHeartbeatResponse(assigned_fetch_slots:) = response

  json.object([#("assigned_fetch_slots", json.int(assigned_fetch_slots))])
}

pub fn provider_slot_acquire_response_to_json(
  response: ProviderSlotAcquireResponse,
) -> json.Json {
  let ProviderSlotAcquireResponse(delay_ms:) = response

  json.object([#("delay_ms", json.int(delay_ms))])
}

pub fn enqueued_work_item_to_json(item: EnqueuedWorkItem) -> json.Json {
  let EnqueuedWorkItem(work_item_id:, subject_id:, kind:, status:) = item

  json.object([
    #("work_item_id", json.string(work_item_id)),
    #("subject_id", json.string(subject_id)),
    #("kind", json.string(work_kind_to_string(kind))),
    #("status", json.string(work_status_to_string(status))),
  ])
}

pub fn completed_work_item_to_json(item: CompletedWorkItem) -> json.Json {
  let CompletedWorkItem(work_item_id:, artifact_id:, status:) = item

  json.object([
    #("work_item_id", json.string(work_item_id)),
    #("artifact_id", json.string(artifact_id)),
    #("status", json.string(work_status_to_string(status))),
  ])
}

pub fn failed_work_item_to_json(item: FailedWorkItem) -> json.Json {
  let FailedWorkItem(work_item_id:, status:, attempts:, max_attempts:) = item

  json.object([
    #("work_item_id", json.string(work_item_id)),
    #("status", json.string(work_status_to_string(status))),
    #("attempts", json.int(attempts)),
    #("max_attempts", json.int(max_attempts)),
  ])
}

pub fn work_kind_to_string(kind: WorkKind) -> String {
  case kind {
    SnapshotCurrent -> "snapshot.current"
    SnapshotArchive -> "snapshot.archive"
  }
}

pub fn work_status_to_string(status: WorkStatus) -> String {
  case status {
    Pending -> "pending"
    Running -> "running"
    Succeeded -> "succeeded"
    Failed -> "failed"
    Dead -> "dead"
  }
}

pub fn work_kind_from_string(value: String) -> Result(WorkKind, Nil) {
  case value {
    "snapshot.current" -> Ok(SnapshotCurrent)
    "snapshot.archive" -> Ok(SnapshotArchive)
    _ -> Error(Nil)
  }
}

pub fn work_status_from_string(value: String) -> Result(WorkStatus, Nil) {
  case value {
    "pending" -> Ok(Pending)
    "running" -> Ok(Running)
    "succeeded" -> Ok(Succeeded)
    "failed" -> Ok(Failed)
    "dead" -> Ok(Dead)
    _ -> Error(Nil)
  }
}

fn work_kind_decoder() -> decode.Decoder(WorkKind) {
  decode.then(decode.string, fn(value) {
    case work_kind_from_string(value) {
      Ok(kind) -> decode.success(kind)
      Error(Nil) -> decode.failure(SnapshotCurrent, expected: "WorkKind")
    }
  })
}

fn work_status_decoder() -> decode.Decoder(WorkStatus) {
  decode.then(decode.string, fn(value) {
    case work_status_from_string(value) {
      Ok(status) -> decode.success(status)
      Error(Nil) -> decode.failure(Pending, expected: "WorkStatus")
    }
  })
}
