import bridge
import error
import gleam/fetch
import gleam/http.{Post}
import gleam/http/request
import gleam/javascript/promise
import gleam/json
import shared/extension

@external(javascript, "./background_ffi.mjs", "install_listener")
fn install_listener(
  callback: fn(Result(bridge.BackgroundMessage, bridge.BackgroundListenerError)) ->
    Nil,
) -> Result(Nil, bridge.BackgroundListenerError)

@external(javascript, "./background_ffi.mjs", "log_error")
fn log_error(message: String) -> Nil

@external(javascript, "./background_ffi.mjs", "extension_version")
fn extension_version() -> String

pub fn main() -> Nil {
  case install_listener(handle_message) {
    Ok(_) -> Nil
    Error(listener_error) ->
      log_error(
        extension.error_to_string(error.from_background_listener_error(
          listener_error,
        )),
      )
  }
}

fn handle_message(
  result: Result(bridge.BackgroundMessage, bridge.BackgroundListenerError),
) -> Nil {
  case result {
    Ok(message) -> {
      let _ = case message {
        bridge.ForwardEvaluation(
          forward_url:,
          error_url:,
          body:,
          timestamp_seconds:,
          timestamp_nanoseconds:,
        ) ->
          process_forward_evaluation(
            forward_url,
            error_url,
            body,
            timestamp_seconds,
            timestamp_nanoseconds,
          )

        bridge.ReportError(
          error_url:,
          error:,
          timestamp_seconds:,
          timestamp_nanoseconds:,
        ) ->
          process_report_error(
            error_url,
            error,
            timestamp_seconds,
            timestamp_nanoseconds,
          )
      }

      Nil
    }

    Error(listener_error) -> {
      log_error(
        extension.error_to_string(error.from_background_listener_error(
          listener_error,
        )),
      )
      Nil
    }
  }
}

fn process_forward_evaluation(
  forward_url: String,
  error_url: String,
  body: String,
  timestamp_seconds: Int,
  timestamp_nanoseconds: Int,
) -> promise.Promise(Nil) {
  case build_forward_request(forward_url, body) {
    Ok(request) ->
      request
      |> fetch.send
      |> promise.await(fn(result) {
        case result {
          Ok(response) ->
            case response.status >= 200 && response.status < 300 {
              True -> promise.resolve(Nil)

              False ->
                report_client_error(
                  error_url,
                  extension.ForwardNon2xx(response.status),
                  timestamp_seconds,
                  timestamp_nanoseconds,
                )
            }

          Error(fetch_error) ->
            report_client_error(
              error_url,
              extension.ForwardFetchError(fetch_error),
              timestamp_seconds,
              timestamp_nanoseconds,
            )
        }
      })

    Error(client_error) ->
      report_client_error(
        error_url,
        client_error,
        timestamp_seconds,
        timestamp_nanoseconds,
      )
  }
}

fn process_report_error(
  error_url: String,
  client_error: String,
  timestamp_seconds: Int,
  timestamp_nanoseconds: Int,
) -> promise.Promise(Nil) {
  send_error_report(
    error_url,
    client_error,
    timestamp_seconds,
    timestamp_nanoseconds,
  )
  |> promise.map(fn(result) {
    case result {
      Ok(_) -> Nil
      Error(report_error) -> log_error(extension.error_to_string(report_error))
    }
  })
}

fn report_client_error(
  error_url: String,
  client_error: extension.Error,
  timestamp_seconds: Int,
  timestamp_nanoseconds: Int,
) -> promise.Promise(Nil) {
  send_error_report(
    error_url,
    extension.error_to_string(client_error),
    timestamp_seconds,
    timestamp_nanoseconds,
  )
  |> promise.map(fn(result) {
    case result {
      Ok(_) -> Nil
      Error(report_error) -> log_error(extension.error_to_string(report_error))
    }
  })
}

fn send_error_report(
  error_url: String,
  client_error: String,
  timestamp_seconds: Int,
  timestamp_nanoseconds: Int,
) -> promise.Promise(Result(Nil, extension.Error)) {
  let current_extension_version = extension_version()

  case
    build_error_report_request(
      error_url,
      extension.ErrorReport(
        error: client_error,
        extension_version: current_extension_version,
        timestamp_seconds:,
        timestamp_nanoseconds:,
      )
        |> extension.error_report_to_json
        |> json.to_string,
    )
  {
    Ok(request) ->
      request
      |> fetch.send
      |> promise.map(fn(result) {
        case result {
          Ok(response) ->
            case response.status >= 200 && response.status < 300 {
              True -> Ok(Nil)
              False -> Error(extension.ErrorReportNon2xx(response.status))
            }

          Error(fetch_error) ->
            Error(extension.ErrorReportFetchError(fetch_error))
        }
      })

    Error(client_error) -> promise.resolve(Error(client_error))
  }
}

fn build_forward_request(
  forward_url: String,
  body: String,
) -> Result(request.Request(String), extension.Error) {
  case build_json_post_request(forward_url, body) {
    Ok(request) -> Ok(request)
    Error(_) -> Error(extension.ForwardRequestBuildError)
  }
}

fn build_error_report_request(
  error_url: String,
  body: String,
) -> Result(request.Request(String), extension.Error) {
  case build_json_post_request(error_url, body) {
    Ok(request) -> Ok(request)
    Error(_) -> Error(extension.ErrorReportRequestBuildError)
  }
}

fn build_json_post_request(
  url: String,
  body: String,
) -> Result(request.Request(String), Nil) {
  case request.to(url) {
    Ok(request) ->
      Ok(
        request
        |> request.set_method(Post)
        |> request.set_body(body)
        |> request.prepend_header("content-type", "application/json"),
      )

    Error(_) -> Error(Nil)
  }
}
