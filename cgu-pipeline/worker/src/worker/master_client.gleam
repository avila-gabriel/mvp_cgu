import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/result
import shared/work_items as transport
import worker/config.{type Config}

pub type ClaimOutcome {
  NoWork
  Claimed(item: transport.ClaimedWorkItem)
}

pub type ApiError {
  RequestBuildError(url: String)
  HttpStatusError(status: Int, body: String)
  TransportError(detail: String)
  DecodeError(detail: String)
}

pub fn claim(config: Config) -> Result(ClaimOutcome, ApiError) {
  let payload =
    transport.ClaimRequest(
      worker_id: config.worker_id,
      lease_seconds: config.lease_seconds,
    )
    |> transport.claim_request_to_json
    |> json.to_string

  use resp <- result.try(post_json(
    api_url(config.master_base_url, "/api/work-items/claim"),
    payload,
    config.request_timeout_ms,
    config.master_access_key,
  ))

  case resp.status {
    204 -> Ok(NoWork)
    200 ->
      decode_json_response(resp.body, transport.claimed_work_item_decoder())
      |> result.map(Claimed)
    status -> Error(HttpStatusError(status, resp.body))
  }
}

pub fn renew_lease(
  config: Config,
  work_item_id: String,
  lease_id: String,
) -> Result(transport.RenewLeaseResponse, ApiError) {
  let payload =
    transport.RenewLeaseRequest(
      worker_id: config.worker_id,
      lease_id: lease_id,
      lease_seconds: config.lease_seconds,
    )
    |> transport.renew_lease_request_to_json
    |> json.to_string

  use resp <- result.try(post_json(
    api_url(
      config.master_base_url,
      "/api/work-items/" <> work_item_id <> "/renew-lease",
    ),
    payload,
    config.request_timeout_ms,
    config.master_access_key,
  ))

  case resp.status {
    200 ->
      decode_json_response(resp.body, transport.renew_lease_response_decoder())
    status -> Error(HttpStatusError(status, resp.body))
  }
}

pub fn heartbeat(
  config: Config,
  capacity: Int,
) -> Result(transport.WorkerHeartbeatResponse, ApiError) {
  let payload =
    transport.WorkerHeartbeatRequest(
      worker_id: config.worker_id,
      capacity: capacity,
    )
    |> transport.worker_heartbeat_request_to_json
    |> json.to_string

  use resp <- result.try(post_json(
    api_url(config.master_base_url, "/api/workers/heartbeat"),
    payload,
    config.request_timeout_ms,
    config.master_access_key,
  ))

  case resp.status {
    200 ->
      decode_json_response(
        resp.body,
        transport.worker_heartbeat_response_decoder(),
      )
    status -> Error(HttpStatusError(status, resp.body))
  }
}

pub fn acquire_provider_slot(
  config: Config,
  provider_key: String,
) -> Result(transport.ProviderSlotAcquireResponse, ApiError) {
  let payload =
    transport.ProviderSlotAcquireRequest(provider_key: provider_key)
    |> transport.provider_slot_acquire_request_to_json
    |> json.to_string

  use resp <- result.try(post_json(
    api_url(config.master_base_url, "/api/provider-slots/acquire"),
    payload,
    config.request_timeout_ms,
    config.master_access_key,
  ))

  case resp.status {
    200 ->
      decode_json_response(
        resp.body,
        transport.provider_slot_acquire_response_decoder(),
      )
    status -> Error(HttpStatusError(status, resp.body))
  }
}

pub fn report_provider_status(
  config: Config,
  provider_key: String,
  status_code: Int,
) -> Result(Nil, ApiError) {
  let payload =
    transport.ProviderSlotReportRequest(provider_key:, status_code:)
    |> transport.provider_slot_report_request_to_json
    |> json.to_string

  use resp <- result.try(post_json(
    api_url(config.master_base_url, "/api/provider-slots/report"),
    payload,
    config.request_timeout_ms,
    config.master_access_key,
  ))

  case resp.status {
    200 -> Ok(Nil)
    status -> Error(HttpStatusError(status, resp.body))
  }
}

pub fn complete(
  config: Config,
  work_item_id: String,
  request_body: transport.CompleteRequest,
) -> Result(transport.CompletedWorkItem, ApiError) {
  let payload =
    request_body
    |> transport.complete_request_to_json
    |> json.to_string

  use resp <- result.try(post_json(
    api_url(
      config.master_base_url,
      "/api/work-items/" <> work_item_id <> "/complete",
    ),
    payload,
    config.request_timeout_ms,
    config.master_access_key,
  ))

  case resp.status {
    200 ->
      decode_json_response(resp.body, transport.completed_work_item_decoder())
    status -> Error(HttpStatusError(status, resp.body))
  }
}

pub fn fail(
  config: Config,
  work_item_id: String,
  request_body: transport.FailRequest,
) -> Result(transport.FailedWorkItem, ApiError) {
  let payload =
    request_body
    |> transport.fail_request_to_json
    |> json.to_string

  use resp <- result.try(post_json(
    api_url(
      config.master_base_url,
      "/api/work-items/" <> work_item_id <> "/fail",
    ),
    payload,
    config.request_timeout_ms,
    config.master_access_key,
  ))

  case resp.status {
    200 -> decode_json_response(resp.body, transport.failed_work_item_decoder())
    status -> Error(HttpStatusError(status, resp.body))
  }
}

pub fn describe_error(error: ApiError) -> String {
  case error {
    RequestBuildError(url) -> "Could not build request for " <> url
    HttpStatusError(status, body) ->
      "Master API returned HTTP " <> int.to_string(status) <> ": " <> body
    TransportError(detail) -> detail
    DecodeError(detail) -> detail
  }
}

pub fn http_error_to_string(error: httpc.HttpError) -> String {
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

fn api_url(base: String, path: String) -> String {
  case path {
    "" -> base
    "/" <> _ -> base <> path
    _ -> base <> "/" <> path
  }
}

fn post_json(
  url: String,
  payload: String,
  timeout_ms: Int,
  access_key: String,
) -> Result(response.Response(String), ApiError) {
  use req <- result.try(case request.to(url) {
    Ok(req) ->
      Ok(
        req
        |> request.set_method(Post)
        |> request.set_header("accept", "application/json")
        |> request.set_header("content-type", "application/json")
        |> request.set_header("user-agent", "cgu-pipeline/worker")
        |> maybe_set_access_key_header(access_key)
        |> request.set_body(payload),
      )
    Error(Nil) -> Error(RequestBuildError(url))
  })

  httpc.configure()
  |> httpc.timeout(timeout_ms)
  |> httpc.follow_redirects(False)
  |> httpc.dispatch(req)
  |> result.map_error(fn(error) { TransportError(http_error_to_string(error)) })
}

fn maybe_set_access_key_header(
  req: request.Request(String),
  access_key: String,
) -> request.Request(String) {
  case access_key {
    "" -> req
    _ -> request.set_header(req, "x-master-access-key", access_key)
  }
}

fn decode_json_response(
  body: String,
  decoder: decode.Decoder(a),
) -> Result(a, ApiError) {
  case json.parse(from: body, using: decoder) {
    Ok(value) -> Ok(value)
    Error(error) -> Error(DecodeError(json_decode_error_to_string(error)))
  }
}

fn json_decode_error_to_string(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "unexpected_end_of_input"
    json.UnexpectedByte(value) -> "unexpected_byte: " <> value
    json.UnexpectedSequence(value) -> "unexpected_sequence: " <> value
    json.UnableToDecode(_) -> "unable_to_decode"
  }
}
