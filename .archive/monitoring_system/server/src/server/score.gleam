import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/time/duration
import m25
import pog
import server/score/evaluate
import server/score/load
import server/score/rank
import server/score/store

pub type Input {
  Input(change_id: String)
}

pub type Output {
  Output(change_id: String)
}

pub fn queue(db: pog.Connection) -> m25.Queue(Input, Output, String) {
  m25.Queue(
    name: "score",
    max_concurrency: 4,
    input_to_json: input_to_json,
    input_decoder: input_decoder(),
    output_to_json: output_to_json,
    output_decoder: output_decoder(),
    error_to_json: json.string,
    error_decoder: decode.string,
    handler_function: run(db, _),
    default_job_timeout: duration.minutes(2),
    poll_interval: 1000,
    heartbeat_interval: 1000,
    allowed_heartbeat_misses: 5,
    executor_init_timeout: 1000,
    reserved_timeout: 30_000,
  )
}

pub fn enqueue(db: pog.Connection, change_id: String) {
  let job =
    m25.new_job(Input(change_id:))
    |> m25.unique_key(key: key(change_id))

  m25.enqueue(db, queue(db), job)
  |> result.replace(Nil)
  |> result.map_error(fn(_) {
    "failed to enqueue score job for monitored change " <> change_id
  })
}

pub fn key(change_id: String) -> String {
  "score:" <> change_id
}

fn run(db: pog.Connection, input: Input) -> Result(Output, String) {
  let Input(change_id:) = input
  use scope <- result.try(load.scope(db, change_id))
  let priority = evaluate.scope(scope)
  let signal = rank.signal(scope.change_signal, priority)
  use _ <- result.try(store.prioritization(
    db,
    scope.change_signal,
    priority,
    signal,
  ))
  Ok(Output(change_id:))
}

fn input_to_json(input: Input) -> json.Json {
  let Input(change_id:) = input

  json.object([#("change_id", json.string(change_id))])
}

fn input_decoder() -> decode.Decoder(Input) {
  use change_id <- decode.field("change_id", decode.string)
  decode.success(Input(change_id:))
}

fn output_to_json(output: Output) -> json.Json {
  let Output(change_id:) = output

  json.object([#("change_id", json.string(change_id))])
}

fn output_decoder() -> decode.Decoder(Output) {
  use change_id <- decode.field("change_id", decode.string)
  decode.success(Output(change_id:))
}
