import { Ok, Error } from "./gleam.mjs";
import {
  SubmitInfo$SubmitInfo,
  SubmitListenerError$EventTargetWasNotForm,
  RuntimeMessageError$RuntimeUnavailable,
  RuntimeMessageError$MessageDispatchRejected
} from "./bridge.mjs";

function chrome_runtime() {
  return globalThis.chrome?.runtime ?? null;
}

function browser_runtime() {
  return globalThis.browser?.runtime ?? null;
}

function runtime_unavailable_error() {
  return new Error(RuntimeMessageError$RuntimeUnavailable());
}

function message_dispatch_rejected_error(error) {
  return new Error(
    RuntimeMessageError$MessageDispatchRejected(String(error))
  );
}

export function install_submit_listener(callback) {
  document.addEventListener(
    "submit",
    (event) => {
      const form = event?.target;

      if (!(form instanceof HTMLFormElement)) {
        callback(new Error(SubmitListenerError$EventTargetWasNotForm()));
        return;
      }

      callback(
        new Ok(
          SubmitInfo$SubmitInfo(
            form.action || "",
            (form.method || "get").toUpperCase(),
            window.location.href,
            form.id || "",
            typeof form.className === "string" ? form.className : ""
          )
        )
      );
    },
    true
  );
}

export function extension_version() {
  const ext_runtime = chrome_runtime() ?? browser_runtime();
  return ext_runtime?.getManifest?.().version ?? "unknown";
}

function chrome_send_message(payload) {
  return new Promise((resolve) => {
    const ext_runtime = chrome_runtime();

    if (ext_runtime === null) {
      resolve(runtime_unavailable_error());
      return;
    }

    try {
      ext_runtime.sendMessage(payload, () => {
        const last_error = ext_runtime.lastError;

        if (last_error === undefined) {
          resolve(new Ok(undefined));
          return;
        }

        const message = last_error.message ?? last_error;
        resolve(message_dispatch_rejected_error(message));
      });
    } catch (error) {
      resolve(message_dispatch_rejected_error(error));
    }
  });
}

function browser_send_message(payload) {
  const ext_runtime = browser_runtime();

  if (ext_runtime === null) {
    return Promise.resolve(runtime_unavailable_error());
  }

  try {
    return ext_runtime
      .sendMessage(payload)
      .then(() => new Ok(undefined))
      .catch((error) => message_dispatch_rejected_error(error));
  } catch (error) {
    return Promise.resolve(message_dispatch_rejected_error(error));
  }
}

function send_message(payload) {
  if (chrome_runtime() !== null) {
    return chrome_send_message(payload);
  }

  if (browser_runtime() !== null) {
    return browser_send_message(payload);
  }

  return Promise.resolve(runtime_unavailable_error());
}

export function send_forward_evaluation(
  forward_url,
  error_url,
  body,
  timestamp_seconds,
  timestamp_nanoseconds
) {
  return send_message({
    type: "forward_evaluation",
    forward_url,
    error_url,
    body,
    timestamp_seconds,
    timestamp_nanoseconds
  });
}

export function send_report_error(
  error_url,
  error,
  timestamp_seconds,
  timestamp_nanoseconds
) {
  return send_message({
    type: "report_error",
    error_url,
    error,
    timestamp_seconds,
    timestamp_nanoseconds
  });
}
