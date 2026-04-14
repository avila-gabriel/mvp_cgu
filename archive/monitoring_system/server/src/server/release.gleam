import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/time/duration
import m25
import pog
import server/db
import server/inbox/sql

pub type Input {
  Input
}

pub type Output {
  Output(released_count: Int)
}

pub fn queue(db: pog.Connection) -> m25.Queue(Input, Output, String) {
  m25.Queue(
    name: "release",
    max_concurrency: 1,
    input_to_json: input_to_json,
    input_decoder: input_decoder(),
    output_to_json: output_to_json,
    output_decoder: output_decoder(),
    error_to_json: json.string,
    error_decoder: decode.string,
    handler_function: run(db, _),
    default_job_timeout: duration.minutes(1),
    poll_interval: 1000,
    heartbeat_interval: 1000,
    allowed_heartbeat_misses: 5,
    executor_init_timeout: 1000,
    reserved_timeout: 30_000,
  )
}

pub fn enqueue(db: pog.Connection) {
  let job = m25.new_job(Input) |> m25.unique_key(key: key())

  m25.enqueue(db, queue(db), job)
  |> result.replace(Nil)
  |> result.map_error(release_enqueue_error)
}

pub fn key() -> String {
  "release"
}

fn run(db: pog.Connection, _input: Input) -> Result(Output, String) {
  use released_count <- db.count(sql.release(db), on_query: release_query_error)
  Ok(Output(released_count:))
}

fn release_enqueue_error(_error) -> String {
  "failed to enqueue release job"
}

fn release_query_error(_error: pog.QueryError) -> Result(a, String) {
  Error("failed to release expired claims")
}

fn input_to_json(_input: Input) -> json.Json {
  json.object([])
}

fn input_decoder() -> decode.Decoder(Input) {
  decode.success(Input)
}

fn output_to_json(output: Output) -> json.Json {
  let Output(released_count:) = output
  json.object([#("released_count", json.int(released_count))])
}

fn output_decoder() -> decode.Decoder(Output) {
  use released_count <- decode.field("released_count", decode.int)
  decode.success(Output(released_count:))
}
