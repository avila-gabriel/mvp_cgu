//// Startup boundary for worker-wide fail-fast checks.
////
//// Runtime modules such as `worker/archive_crawl` and the worker loop should
//// return typed outcomes rather than crashing. Hard invariants for the worker
//// process are checked here before the supervision tree starts.

import envoy
import gleam/float
import gleam/int
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/string
import gleam/uri
import worker/config

pub fn load_config() -> config.Config {
  let assert Ok(master_base_url) = required_env("MASTER_BASE_URL")
    as "MASTER_BASE_URL is required"
  let master_access_key = optional_env("MASTER_ACCESS_KEY")
  let assert Ok(worker_id) = required_env("WORKER_ID")
    as "WORKER_ID is required"
  let assert Ok(poll_interval_ms) = required_int("WORKER_POLL_INTERVAL_MS")
    as "WORKER_POLL_INTERVAL_MS must be an integer"
  let assert Ok(lease_seconds) = required_float("WORKER_LEASE_SECONDS")
    as "WORKER_LEASE_SECONDS must be a float"
  let assert Ok(request_timeout_ms) = required_int("WORKER_REQUEST_TIMEOUT_MS")
    as "WORKER_REQUEST_TIMEOUT_MS must be an integer"
  let assert Ok(archive_max_visits) = required_int("WORKER_ARCHIVE_MAX_VISITS")
    as "WORKER_ARCHIVE_MAX_VISITS must be an integer"
  let assert Ok(failure_backoff_seconds) =
    required_float("WORKER_FAILURE_BACKOFF_SECONDS")
    as "WORKER_FAILURE_BACKOFF_SECONDS must be a float"

  config.Config(
    master_base_url: trim_trailing_slash(master_base_url),
    master_access_key:,
    worker_id:,
    poll_interval_ms:,
    lease_seconds:,
    request_timeout_ms:,
    archive_max_visits:,
    failure_backoff_seconds:,
  )
}

pub fn check(config: config.Config) -> Nil {
  let assert Ok(_) = uri.parse(config.master_base_url)
    as "MASTER_BASE_URL must be a valid absolute URL"
  let assert True = config.archive_max_visits > 0
    as "WORKER_ARCHIVE_MAX_VISITS must be greater than zero"
  let assert True = config.poll_interval_ms >= 0
    as "WORKER_POLL_INTERVAL_MS must be zero or greater"
  let assert True = config.request_timeout_ms > 0
    as "WORKER_REQUEST_TIMEOUT_MS must be greater than zero"

  Nil
}

pub fn start_supervisor(child: supervision.ChildSpecification(Nil)) -> Nil {
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child)
    |> supervisor.start
    as "worker supervisor failed to start"

  Nil
}

fn required_env(name: String) -> Result(String, Nil) {
  case envoy.get(name) {
    Ok(value) -> Ok(value)
    Error(Nil) -> Error(Nil)
  }
}

fn optional_env(name: String) -> String {
  case envoy.get(name) {
    Ok(value) -> value
    Error(Nil) -> ""
  }
}

fn required_int(name: String) -> Result(Int, Nil) {
  case envoy.get(name) {
    Ok(value) -> int.parse(value)
    Error(Nil) -> Error(Nil)
  }
}

fn required_float(name: String) -> Result(Float, Nil) {
  case envoy.get(name) {
    Ok(value) -> float.parse(value)
    Error(Nil) -> Error(Nil)
  }
}

fn trim_trailing_slash(url: String) -> String {
  case url {
    "" -> url
    _ ->
      case string.ends_with(url, "/") {
        True -> string.drop_end(url, 1)
        False -> url
      }
  }
}
