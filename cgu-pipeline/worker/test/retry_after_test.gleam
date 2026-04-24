import gleam/option.{None, Some}
import worker/retry_after

pub fn parses_delta_seconds_test() {
  assert retry_after.parse(Some("120")) == Some(120.0)
}

pub fn trims_delta_seconds_test() {
  assert retry_after.parse(Some(" 5 ")) == Some(5.0)
}

pub fn ignores_negative_delta_seconds_test() {
  assert retry_after.parse(Some("-1")) == None
}

pub fn ignores_http_date_for_now_test() {
  assert retry_after.parse(Some("Wed, 21 Oct 2015 07:28:00 GMT")) == None
}
