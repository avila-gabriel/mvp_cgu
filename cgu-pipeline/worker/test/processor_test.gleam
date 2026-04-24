import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleeunit/should
import shared/work_items
import worker/config
import worker/processor

fn test_config() -> config.Config {
  config.Config(
    master_base_url: "http://127.0.0.1",
    master_access_key: "",
    worker_id: "worker-test",
    poll_interval_ms: 1,
    lease_seconds: 30.0,
    request_timeout_ms: 1,
    archive_max_visits: 1,
    failure_backoff_seconds: 10.0,
  )
}

fn claimed_item(
  url url: String,
  archive_date archive_date: Option(String),
) -> work_items.ClaimedWorkItem {
  work_items.ClaimedWorkItem(
    lease_id: "lease-test",
    lease_expires_at: "2026-01-01T00:00:00Z",
    work_item_id: "work-item-test",
    subject_id: "subject-test",
    kind: work_items.SnapshotArchive,
    url:,
    archive_date:,
    metadata_json: "{}",
    attempts: 1,
    max_attempts: 3,
  )
}

pub fn missing_archive_date_failure_is_structured_test() {
  let outcome =
    processor.process(
      test_config(),
      claimed_item(url: "https://example.gov.br", archive_date: None),
    )

  let assert processor.Failed(error, False, 0.0) = outcome

  json.parse(error, decode.at(["case"], decode.string))
  |> should.equal(Ok("missing_archive_date"))
  json.parse(error, decode.at(["requested_url"], decode.string))
  |> should.equal(Ok("https://example.gov.br"))
}

pub fn invalid_seed_url_failure_is_structured_test() {
  let outcome =
    processor.process(
      test_config(),
      claimed_item(url: "not a url", archive_date: Some("20240101")),
    )

  let assert processor.Failed(error, False, 0.0) = outcome

  json.parse(error, decode.at(["case"], decode.string))
  |> should.equal(Ok("invalid_archive_seed_url"))
  json.parse(error, decode.at(["requested_url"], decode.string))
  |> should.equal(Ok("not a url"))
}

pub fn invalid_archive_limit_failure_is_structured_test() {
  let config = config.Config(..test_config(), archive_max_visits: 0)
  let outcome =
    processor.process(
      config,
      claimed_item(
        url: "https://example.gov.br",
        archive_date: Some("20240101"),
      ),
    )

  let assert processor.Failed(error, False, 0.0) = outcome

  json.parse(error, decode.at(["case"], decode.string))
  |> should.equal(Ok("invalid_config"))
  json.parse(error, decode.at(["config_key"], decode.string))
  |> should.equal(Ok("WORKER_ARCHIVE_MAX_VISITS"))
  json.parse(error, decode.at(["configured_value"], decode.int))
  |> should.equal(Ok(0))
}
