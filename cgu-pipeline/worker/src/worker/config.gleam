pub type Config {
  Config(
    master_base_url: String,
    master_access_key: String,
    worker_id: String,
    poll_interval_ms: Int,
    lease_seconds: Float,
    request_timeout_ms: Int,
    archive_max_visits: Int,
    failure_backoff_seconds: Float,
  )
}
