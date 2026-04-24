import gleam/bit_array
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/json
import gleam/option.{type Option, None, Some}
import worker/master_client
import worker/retry_after

pub type FetchResult {
  FetchResult(
    requested_url: String,
    fetched_url: String,
    status_code: Option(Int),
    content_type: Option(String),
    retry_after_seconds: Option(Float),
    body: BitArray,
    metadata: json.Json,
  )
}

pub fn fetch(url: String, timeout_ms: Int) -> FetchResult {
  case request.to(url) {
    Error(Nil) ->
      FetchResult(
        requested_url: url,
        fetched_url: url,
        status_code: None,
        content_type: None,
        retry_after_seconds: None,
        body: <<>>,
        metadata: current_fetch_json("request_build_error", None, None, None),
      )

    Ok(req) -> {
      let req =
        req
        |> request.prepend_header("accept", "*/*")
        |> request.prepend_header("user-agent", "cgu-pipeline/worker")
        |> request.map(bit_array.from_string)

      case httpc.dispatch_bits(http_config(timeout_ms), req) {
        Error(error) ->
          FetchResult(
            requested_url: url,
            fetched_url: url,
            status_code: None,
            content_type: None,
            retry_after_seconds: None,
            body: <<>>,
            metadata: current_fetch_json(
              "transport_error",
              None,
              None,
              Some(master_client.http_error_to_string(error)),
            ),
          )

        Ok(resp) -> classify_response(url, resp)
      }
    }
  }
}

fn classify_response(
  requested_url: String,
  resp: response.Response(BitArray),
) -> FetchResult {
  let content_type = header(resp, "content-type")
  let location = header(resp, "location")
  let retry_after_seconds = retry_after.parse(header(resp, "retry-after"))

  case resp.status >= 300 && resp.status < 400 {
    True ->
      FetchResult(
        requested_url: requested_url,
        fetched_url: option.unwrap(location, requested_url),
        status_code: Some(resp.status),
        content_type: content_type,
        retry_after_seconds: retry_after_seconds,
        body: resp.body,
        metadata: current_fetch_json(
          "redirect",
          Some(resp.status),
          content_type,
          location,
        ),
      )

    False ->
      case resp.status >= 400 {
        True ->
          FetchResult(
            requested_url: requested_url,
            fetched_url: requested_url,
            status_code: Some(resp.status),
            content_type: content_type,
            retry_after_seconds: retry_after_seconds,
            body: resp.body,
            metadata: current_fetch_json(
              "http_error",
              Some(resp.status),
              content_type,
              None,
            ),
          )

        False ->
          FetchResult(
            requested_url: requested_url,
            fetched_url: requested_url,
            status_code: Some(resp.status),
            content_type: content_type,
            retry_after_seconds: retry_after_seconds,
            body: resp.body,
            metadata: current_fetch_json(
              "fetched",
              Some(resp.status),
              content_type,
              None,
            ),
          )
      }
  }
}

fn http_config(timeout_ms: Int) -> httpc.Configuration {
  httpc.configure()
  |> httpc.follow_redirects(False)
  |> httpc.timeout(timeout_ms)
}

fn header(resp: response.Response(body), key: String) -> Option(String) {
  case response.get_header(resp, key) {
    Ok(value) -> Some(value)
    Error(Nil) -> None
  }
}

fn current_fetch_json(
  case_name: String,
  status_code: Option(Int),
  content_type: Option(String),
  detail: Option(String),
) -> json.Json {
  json.object([
    #(
      "current_fetch",
      json.object([
        #("case", json.string(case_name)),
        #("status_code", optional_json(status_code, json.int)),
        #("content_type", optional_json(content_type, json.string)),
        #("detail", optional_json(detail, json.string)),
      ]),
    ),
  ])
}

fn optional_json(value: Option(a), encode: fn(a) -> json.Json) -> json.Json {
  case value {
    Some(value) -> encode(value)
    None -> json.null()
  }
}
