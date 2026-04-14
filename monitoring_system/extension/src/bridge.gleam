pub type SubmitInfo {
  SubmitInfo(
    action: String,
    method: String,
    page_url: String,
    form_id: String,
    class_name: String,
  )
}

pub type SubmitListenerError {
  EventTargetWasNotForm
}

pub type RuntimeMessageError {
  RuntimeUnavailable
  MessageDispatchRejected(String)
}

pub type BackgroundMessage {
  ForwardEvaluation(
    forward_url: String,
    error_url: String,
    body: String,
    timestamp_seconds: Int,
    timestamp_nanoseconds: Int,
  )
  ReportError(
    error_url: String,
    error: String,
    timestamp_seconds: Int,
    timestamp_nanoseconds: Int,
  )
}

pub type BackgroundListenerError {
  BackgroundRuntimeUnavailable
  InvalidMessage(String)
}
