import { Ok, Error } from "./gleam.mjs";
import {
  BackgroundMessage$ForwardEvaluation,
  BackgroundMessage$ReportError,
  BackgroundListenerError$BackgroundRuntimeUnavailable,
  BackgroundListenerError$InvalidMessage
} from "./bridge.mjs";

function runtime() {
  return globalThis.chrome?.runtime ?? globalThis.browser?.runtime ?? null;
}

function invalid_message(detail) {
  return new Error(BackgroundListenerError$InvalidMessage(detail));
}

function parse_forward_evaluation(message) {
  if (typeof message.forward_url !== "string") {
    return invalid_message("forward_evaluation.forward_url_was_not_string");
  }

  if (typeof message.error_url !== "string") {
    return invalid_message("forward_evaluation.error_url_was_not_string");
  }

  if (typeof message.body !== "string") {
    return invalid_message("forward_evaluation.body_was_not_string");
  }

  if (!Number.isInteger(message.timestamp_seconds)) {
    return invalid_message("forward_evaluation.timestamp_seconds_was_not_int");
  }

  if (!Number.isInteger(message.timestamp_nanoseconds)) {
    return invalid_message("forward_evaluation.timestamp_nanoseconds_was_not_int");
  }

  return new Ok(
    BackgroundMessage$ForwardEvaluation(
      message.forward_url,
      message.error_url,
      message.body,
      message.timestamp_seconds,
      message.timestamp_nanoseconds
    )
  );
}

function parse_report_error(message) {
  if (typeof message.error_url !== "string") {
    return invalid_message("report_error.error_url_was_not_string");
  }

  if (typeof message.error !== "string") {
    return invalid_message("report_error.error_was_not_string");
  }

  if (!Number.isInteger(message.timestamp_seconds)) {
    return invalid_message("report_error.timestamp_seconds_was_not_int");
  }

  if (!Number.isInteger(message.timestamp_nanoseconds)) {
    return invalid_message("report_error.timestamp_nanoseconds_was_not_int");
  }

  return new Ok(
    BackgroundMessage$ReportError(
      message.error_url,
      message.error,
      message.timestamp_seconds,
      message.timestamp_nanoseconds
    )
  );
}

export function install_listener(callback) {
  const ext_runtime = runtime();

  if (ext_runtime === null) {
    return new Error(BackgroundListenerError$BackgroundRuntimeUnavailable());
  }

  ext_runtime.onMessage.addListener((message) => {
    if (message === null || typeof message !== "object") {
      callback(invalid_message("message_was_not_object"));
      return;
    }

    switch (message.type) {
      case "forward_evaluation":
        callback(parse_forward_evaluation(message));
        break;

      case "report_error":
        callback(parse_report_error(message));
        break;

      default:
        callback(invalid_message(`unknown_message_type:${String(message.type)}`));
        break;
    }
  });

  return new Ok(undefined);
}

export function extension_version() {
  return runtime()?.getManifest?.().version ?? "unknown";
}

export function log_error(message) {
  console.error(message);
}
