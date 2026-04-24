import gleam/json
import gleam/option.{Some}
import shared/work_items as transport

pub fn claim_request_roundtrip_test() {
  let payload =
    transport.ClaimRequest(worker_id: "worker-1", lease_seconds: 120.0)
    |> transport.claim_request_to_json
    |> json.to_string

  let assert Ok(decoded) =
    json.parse(from: payload, using: transport.claim_request_decoder())

  assert decoded
    == transport.ClaimRequest(worker_id: "worker-1", lease_seconds: 120.0)
}

pub fn claim_request_decodes_integer_lease_seconds_test() {
  let payload = "{\"worker_id\":\"worker-1\",\"lease_seconds\":120}"

  let assert Ok(decoded) =
    json.parse(from: payload, using: transport.claim_request_decoder())

  assert decoded
    == transport.ClaimRequest(worker_id: "worker-1", lease_seconds: 120.0)
}

pub fn claim_request_requires_lease_seconds_test() {
  let payload = "{\"worker_id\":\"worker-1\"}"

  let assert Error(_) =
    json.parse(from: payload, using: transport.claim_request_decoder())
}

pub fn renew_lease_request_roundtrip_test() {
  let payload =
    transport.RenewLeaseRequest(
      worker_id: "worker-1",
      lease_id: "lease-1",
      lease_seconds: 120.0,
    )
    |> transport.renew_lease_request_to_json
    |> json.to_string

  let assert Ok(decoded) =
    json.parse(from: payload, using: transport.renew_lease_request_decoder())

  assert decoded
    == transport.RenewLeaseRequest(
      worker_id: "worker-1",
      lease_id: "lease-1",
      lease_seconds: 120.0,
    )
}

pub fn renew_lease_response_roundtrip_test() {
  let payload =
    transport.RenewLeaseResponse(lease_expires_at: "2026-04-28T12:02:00Z")
    |> transport.renew_lease_response_to_json
    |> json.to_string

  let assert Ok(decoded) =
    json.parse(from: payload, using: transport.renew_lease_response_decoder())

  assert decoded
    == transport.RenewLeaseResponse(lease_expires_at: "2026-04-28T12:02:00Z")
}

pub fn worker_heartbeat_roundtrip_test() {
  let payload =
    transport.WorkerHeartbeatRequest(worker_id: "worker-1", capacity: 2)
    |> transport.worker_heartbeat_request_to_json
    |> json.to_string

  let assert Ok(decoded) =
    json.parse(
      from: payload,
      using: transport.worker_heartbeat_request_decoder(),
    )

  assert decoded
    == transport.WorkerHeartbeatRequest(worker_id: "worker-1", capacity: 2)
}

pub fn worker_heartbeat_response_roundtrip_test() {
  let payload =
    transport.WorkerHeartbeatResponse(assigned_fetch_slots: 1)
    |> transport.worker_heartbeat_response_to_json
    |> json.to_string

  let assert Ok(decoded) =
    json.parse(
      from: payload,
      using: transport.worker_heartbeat_response_decoder(),
    )

  assert decoded == transport.WorkerHeartbeatResponse(assigned_fetch_slots: 1)
}

pub fn provider_slot_acquire_roundtrip_test() {
  let payload =
    transport.ProviderSlotAcquireRequest(provider_key: "wayback_lookup")
    |> transport.provider_slot_acquire_request_to_json
    |> json.to_string

  let assert Ok(decoded) =
    json.parse(
      from: payload,
      using: transport.provider_slot_acquire_request_decoder(),
    )

  assert decoded
    == transport.ProviderSlotAcquireRequest(provider_key: "wayback_lookup")
}

pub fn provider_slot_report_roundtrip_test() {
  let payload =
    transport.ProviderSlotReportRequest(
      provider_key: "wayback_lookup",
      status_code: 429,
    )
    |> transport.provider_slot_report_request_to_json
    |> json.to_string

  let assert Ok(decoded) =
    json.parse(
      from: payload,
      using: transport.provider_slot_report_request_decoder(),
    )

  assert decoded
    == transport.ProviderSlotReportRequest(
      provider_key: "wayback_lookup",
      status_code: 429,
    )
}

pub fn claimed_work_item_decode_test() {
  let payload =
    transport.ClaimedWorkItem(
      lease_id: "lease-1",
      lease_expires_at: "2026-04-28T12:00:00Z",
      work_item_id: "work-1",
      subject_id: "subject-1",
      kind: transport.SnapshotArchive,
      url: "https://example.gov.br",
      archive_date: Some("20240101"),
      metadata_json: "{\"target_dates\":[\"20240101\"]}",
      attempts: 1,
      max_attempts: 5,
    )
    |> transport.claimed_work_item_to_json
    |> json.to_string

  let assert Ok(decoded) =
    json.parse(from: payload, using: transport.claimed_work_item_decoder())

  assert decoded
    == transport.ClaimedWorkItem(
      lease_id: "lease-1",
      lease_expires_at: "2026-04-28T12:00:00Z",
      work_item_id: "work-1",
      subject_id: "subject-1",
      kind: transport.SnapshotArchive,
      url: "https://example.gov.br",
      archive_date: Some("20240101"),
      metadata_json: "{\"target_dates\":[\"20240101\"]}",
      attempts: 1,
      max_attempts: 5,
    )
}

pub fn complete_request_roundtrip_includes_body_test() {
  let payload =
    transport.CompleteRequest(
      worker_id: "worker-1",
      lease_id: "lease-1",
      fetched_url: "https://web.archive.org/web/20240101000000/https://example.gov.br",
      status_code: Some(200),
      content_type: Some("text/html"),
      body_base64: "PGh0bWw+PC9odG1sPg==",
      metadata_json: "{\"case\":\"fetched\"}",
    )
    |> transport.complete_request_to_json
    |> json.to_string

  let assert Ok(decoded) =
    json.parse(from: payload, using: transport.complete_request_decoder())

  assert decoded
    == transport.CompleteRequest(
      worker_id: "worker-1",
      lease_id: "lease-1",
      fetched_url: "https://web.archive.org/web/20240101000000/https://example.gov.br",
      status_code: Some(200),
      content_type: Some("text/html"),
      body_base64: "PGh0bWw+PC9odG1sPg==",
      metadata_json: "{\"case\":\"fetched\"}",
    )
}
