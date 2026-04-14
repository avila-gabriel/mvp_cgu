import bridge
import error
import gleam/javascript/promise
import gleam/json
import gleam/time/timestamp
import shared/extension

const target_form_id = "__REPLACE_FORM_ID__"

const target_form_action = "__REPLACE_FORM_ACTION__"

const forward_url = "https://YOUR_HOSTNAME_HERE/api/evaluation/ingest"

const error_url = "https://YOUR_HOSTNAME_HERE/api/ingest/error"

@external(javascript, "./extension_ffi.mjs", "install_submit_listener")
fn install_submit_listener(
  callback: fn(Result(bridge.SubmitInfo, bridge.SubmitListenerError)) -> Nil,
) -> Nil

@external(javascript, "./extension_ffi.mjs", "extension_version")
fn extension_version() -> String

@external(javascript, "./extension_ffi.mjs", "send_forward_evaluation")
fn send_forward_evaluation(
  forward_url: String,
  error_url: String,
  body: String,
  timestamp_seconds: Int,
  timestamp_nanoseconds: Int,
) -> promise.Promise(Result(Nil, bridge.RuntimeMessageError))

@external(javascript, "./extension_ffi.mjs", "send_report_error")
fn send_report_error(
  error_url: String,
  error: String,
  timestamp_seconds: Int,
  timestamp_nanoseconds: Int,
) -> promise.Promise(Result(Nil, bridge.RuntimeMessageError))

pub fn main() -> Nil {
  install_submit_listener(handle_submit)
}

fn handle_submit(
  result: Result(bridge.SubmitInfo, bridge.SubmitListenerError),
) -> Nil {
  let #(timestamp_seconds, timestamp_nanoseconds) = now()
  let current_extension_version = extension_version()

  case result {
    Ok(info) ->
      case should_forward(info) {
        True -> {
          let _ =
            send_forward_evaluation(
              forward_url,
              error_url,
              evaluation_body(
                info,
                current_extension_version,
                timestamp_seconds,
                timestamp_nanoseconds,
              ),
              timestamp_seconds,
              timestamp_nanoseconds,
            )
            |> promise.map(fn(result) {
              case result {
                Ok(_) -> Nil

                Error(runtime_error) -> {
                  let _ =
                    report_client_error(
                      error.from_content_runtime_message_error(runtime_error),
                      timestamp_seconds,
                      timestamp_nanoseconds,
                    )

                  Nil
                }
              }
            })

          Nil
        }

        False -> Nil
      }

    Error(submit_error) -> {
      let _ =
        report_client_error(
          error.from_submit_listener_error(submit_error),
          timestamp_seconds,
          timestamp_nanoseconds,
        )

      Nil
    }
  }
}

fn should_forward(info: bridge.SubmitInfo) -> Bool {
  let bridge.SubmitInfo(action:, form_id:, ..) = info
  form_id == target_form_id || action == target_form_action
}

fn evaluation_body(
  info: bridge.SubmitInfo,
  current_extension_version: String,
  timestamp_seconds: Int,
  timestamp_nanoseconds: Int,
) -> String {
  let bridge.SubmitInfo(action:, method:, page_url:, form_id:, class_name:) =
    info

  json.object([
    #("action", json.string(action)),
    #("method", json.string(method)),
    #("page_url", json.string(page_url)),
    #("form_id", json.string(form_id)),
    #("class_name", json.string(class_name)),
    #("extension_version", json.string(current_extension_version)),
    #("timestamp_seconds", json.int(timestamp_seconds)),
    #("timestamp_nanoseconds", json.int(timestamp_nanoseconds)),
  ])
  |> json.to_string
}

fn report_client_error(
  client_error: extension.Error,
  timestamp_seconds: Int,
  timestamp_nanoseconds: Int,
) -> promise.Promise(Nil) {
  send_report_error(
    error_url,
    extension.error_to_string(client_error),
    timestamp_seconds,
    timestamp_nanoseconds,
  )
  |> promise.map(fn(_) { Nil })
}

fn now() -> #(Int, Int) {
  timestamp.system_time()
  |> timestamp.to_unix_seconds_and_nanoseconds
}
