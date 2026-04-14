import bridge
import shared/extension

pub fn from_submit_listener_error(
  error: bridge.SubmitListenerError,
) -> extension.Error {
  case error {
    bridge.EventTargetWasNotForm -> extension.SubmitEventTargetWasNotForm
  }
}

pub fn from_content_runtime_message_error(
  error: bridge.RuntimeMessageError,
) -> extension.Error {
  case error {
    bridge.RuntimeUnavailable -> extension.ContentRuntimeUnavailable
    bridge.MessageDispatchRejected(message) ->
      extension.ContentMessageDispatchRejected(message)
  }
}

pub fn from_background_listener_error(
  error: bridge.BackgroundListenerError,
) -> extension.Error {
  case error {
    bridge.BackgroundRuntimeUnavailable ->
      extension.BackgroundRuntimeUnavailable
    bridge.InvalidMessage(message) ->
      extension.BackgroundInvalidMessage(message)
  }
}
