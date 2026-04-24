import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/result
import gleam/time/duration
import m25
import pog
import server/monitor/candidate
import server/monitor/fetch
import server/monitor/load
import server/monitor/model
import server/monitor/noise
import server/monitor/normalize
import server/monitor/store

pub type Input {
  Input(evaluation_id: String)
}

pub type Output {
  Output(
    evaluation_id: String,
    visit_count: Int,
    candidate_count: Int,
    discovered_count: Int,
    removed_count: Int,
  )
}

pub fn queue(db: pog.Connection) -> m25.Queue(Input, Output, String) {
  m25.Queue(
    name: "monitor",
    max_concurrency: 4,
    input_to_json: input_to_json,
    input_decoder: input_decoder(),
    output_to_json: output_to_json,
    output_decoder: output_decoder(),
    error_to_json: json.string,
    error_decoder: decode.string,
    handler_function: run(db, _),
    default_job_timeout: duration.minutes(5),
    poll_interval: 1000,
    heartbeat_interval: 1000,
    allowed_heartbeat_misses: 5,
    executor_init_timeout: 1000,
    reserved_timeout: 30_000,
  )
}

pub fn enqueue(db: pog.Connection, evaluation_id: String) {
  let job = m25.new_job(Input(evaluation_id:))

  m25.enqueue(db, queue(db), job)
  |> result.replace(Nil)
  |> result.map_error(fn(_) {
    "failed to enqueue monitor job for evaluation " <> evaluation_id
  })
}

pub fn enqueue_due(db: pog.Connection, evaluation_id: String, slot: Int) {
  let job =
    m25.new_job(Input(evaluation_id:))
    |> m25.unique_key(key: due_key(evaluation_id, slot))

  m25.enqueue(db, queue(db), job)
  |> result.replace(Nil)
  |> result.map_error(fn(_) {
    "failed to enqueue due monitor job for evaluation " <> evaluation_id
  })
}

pub fn due_key(evaluation_id: String, slot: Int) -> String {
  "monitor:" <> evaluation_id <> ":" <> int.to_string(slot)
}

fn run(db: pog.Connection, input: Input) -> Result(Output, String) {
  let Input(evaluation_id:) = input
  use scope <- result.try(load.scope(db, evaluation_id))
  use visit <- result.try(fetch.evaluation(scope))
  let evidence = normalize.evaluation(scope, visit)
  let classified = noise.evidence(evidence)
  let decision = candidate.evaluation(scope.item, classified)
  use _ <- result.try(store.evaluation(db, evaluation_id, evidence, decision))
  Ok(output(evaluation_id, visit, decision))
}

fn output(
  _evaluation_id: String,
  _visit: List(fetch.Visit),
  _decision: List(model.Decision),
) -> Output {
  todo as "derive the monitor job summary from fetched visits and persisted candidate decisions"
}

fn input_to_json(input: Input) -> json.Json {
  let Input(evaluation_id:) = input

  json.object([#("evaluation_id", json.string(evaluation_id))])
}

fn input_decoder() -> decode.Decoder(Input) {
  use evaluation_id <- decode.field("evaluation_id", decode.string)
  decode.success(Input(evaluation_id:))
}

fn output_to_json(output: Output) -> json.Json {
  let Output(
    evaluation_id:,
    visit_count:,
    candidate_count:,
    discovered_count:,
    removed_count:,
  ) = output

  json.object([
    #("evaluation_id", json.string(evaluation_id)),
    #("visit_count", json.int(visit_count)),
    #("candidate_count", json.int(candidate_count)),
    #("discovered_count", json.int(discovered_count)),
    #("removed_count", json.int(removed_count)),
  ])
}

fn output_decoder() -> decode.Decoder(Output) {
  use evaluation_id <- decode.field("evaluation_id", decode.string)
  use visit_count <- decode.field("visit_count", decode.int)
  use candidate_count <- decode.field("candidate_count", decode.int)
  use discovered_count <- decode.field("discovered_count", decode.int)
  use removed_count <- decode.field("removed_count", decode.int)
  decode.success(Output(
    evaluation_id:,
    visit_count:,
    candidate_count:,
    discovered_count:,
    removed_count:,
  ))
}
