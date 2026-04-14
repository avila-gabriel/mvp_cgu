import gleam/dynamic/decode
import gleam/fetch
import gleam/int
import gleam/json

pub type Error {
  SubmitEventTargetWasNotForm
  ContentRuntimeUnavailable
  ContentMessageDispatchRejected(String)
  BackgroundRuntimeUnavailable
  BackgroundInvalidMessage(String)
  ForwardRequestBuildError
  ForwardNon2xx(Int)
  ForwardFetchError(fetch.FetchError)
  ErrorReportRequestBuildError
  ErrorReportNon2xx(Int)
  ErrorReportFetchError(fetch.FetchError)
}

pub type ErrorReport {
  ErrorReport(
    error: String,
    extension_version: String,
    timestamp_seconds: Int,
    timestamp_nanoseconds: Int,
  )
}

pub fn error_report_to_json(report: ErrorReport) -> json.Json {
  let ErrorReport(
    error:,
    extension_version:,
    timestamp_seconds:,
    timestamp_nanoseconds:,
  ) = report
  json.object([
    #("error", json.string(error)),
    #("extension_version", json.string(extension_version)),
    #("timestamp_seconds", json.int(timestamp_seconds)),
    #("timestamp_nanoseconds", json.int(timestamp_nanoseconds)),
  ])
}

pub fn error_report_decoder() -> decode.Decoder(ErrorReport) {
  use error <- decode.field("error", decode.string)
  use extension_version <- decode.field("extension_version", decode.string)
  use timestamp_seconds <- decode.field("timestamp_seconds", decode.int)
  use timestamp_nanoseconds <- decode.field("timestamp_nanoseconds", decode.int)
  decode.success(ErrorReport(
    error:,
    extension_version:,
    timestamp_seconds:,
    timestamp_nanoseconds:,
  ))
}

pub fn error_to_string(error: Error) -> String {
  case error {
    SubmitEventTargetWasNotForm -> "submit_event_target_was_not_form"

    ContentRuntimeUnavailable -> "content_runtime_unavailable"

    ContentMessageDispatchRejected(message) ->
      "content_message_dispatch_rejected:" <> message

    BackgroundRuntimeUnavailable -> "background_runtime_unavailable"

    BackgroundInvalidMessage(message) ->
      "background_invalid_message:" <> message

    ForwardRequestBuildError -> "forward_request_build_error"

    ForwardNon2xx(status) -> "forward_non_2xx:" <> int.to_string(status)

    ForwardFetchError(fetch.NetworkError(message)) ->
      "forward_network_error:" <> message

    ForwardFetchError(fetch.UnableToReadBody) -> "forward_unable_to_read_body"

    ForwardFetchError(fetch.InvalidJsonBody) -> "forward_invalid_json_body"

    ErrorReportRequestBuildError -> "error_report_request_build_error"

    ErrorReportNon2xx(status) ->
      "error_report_non_2xx:" <> int.to_string(status)

    ErrorReportFetchError(fetch.NetworkError(message)) ->
      "error_report_network_error:" <> message

    ErrorReportFetchError(fetch.UnableToReadBody) ->
      "error_report_unable_to_read_body"

    ErrorReportFetchError(fetch.InvalidJsonBody) ->
      "error_report_invalid_json_body"
  }
}
