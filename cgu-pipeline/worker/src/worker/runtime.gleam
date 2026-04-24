import gleam/bit_array
import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import gleam/otp/supervision
import shared/work_items as transport
import worker/config.{type Config}
import worker/master_client
import worker/processor

pub type Message {
  Tick
  Drain
}

type State {
  State(config: Config, control: process.Subject(Message))
}

pub fn supervised(config: Config) -> supervision.ChildSpecification(Nil) {
  supervision.worker(fn() { start(config) })
  |> supervision.map_data(fn(_) { Nil })
}

pub fn start(
  config: Config,
) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {
  actor.new_with_initialiser(1000, initialise(config, _))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn initialise(
  config: Config,
  control: process.Subject(Message),
) -> Result(actor.Initialised(State, Message, process.Subject(Message)), String) {
  let _ = process.send_after(control, 0, Tick)
  Ok(actor.initialised(State(config:, control:)) |> actor.returning(control))
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Tick -> {
      let delay = step(state.config)
      let _ = process.send_after(state.control, delay, Tick)
      actor.continue(state)
    }
    Drain -> actor.stop()
  }
}

pub fn drain(subject: process.Subject(Message)) -> Nil {
  process.send(subject, Drain)
}

fn step(config: Config) -> Int {
  case master_client.claim(config) {
    Ok(master_client.NoWork) -> config.poll_interval_ms
    Ok(master_client.Claimed(item)) -> process_claimed(config, item)
    Error(error) -> {
      log("claim_failed", master_client.describe_error(error))
      config.poll_interval_ms
    }
  }
}

fn process_claimed(config: Config, item: transport.ClaimedWorkItem) -> Int {
  log("claimed_work_item", item.work_item_id)

  case processor.process(config, item) {
    processor.Completed(fetched) ->
      case
        master_client.complete(
          config,
          item.work_item_id,
          transport.CompleteRequest(
            worker_id: config.worker_id,
            lease_id: item.lease_id,
            fetched_url: fetched.fetched_url,
            status_code: fetched.status_code,
            content_type: fetched.content_type,
            body_base64: bit_array.base64_encode(fetched.body, True),
            metadata_json: fetched.metadata_json,
          ),
        )
      {
        Ok(_) -> {
          log("completed_work_item", item.work_item_id)
          0
        }
        Error(error) -> {
          log("complete_failed", master_client.describe_error(error))
          config.poll_interval_ms
        }
      }

    processor.Failed(error, retryable, backoff_seconds) ->
      case
        master_client.fail(
          config,
          item.work_item_id,
          transport.FailRequest(
            worker_id: config.worker_id,
            lease_id: item.lease_id,
            error: error,
            retryable: retryable,
            backoff_seconds: backoff_seconds,
          ),
        )
      {
        Ok(_) -> {
          log("failed_work_item", item.work_item_id <> ": " <> error)
          0
        }
        Error(report_error) -> {
          log("fail_report_failed", master_client.describe_error(report_error))
          config.poll_interval_ms
        }
      }

    processor.LeaseLost(detail) -> {
      log("lease_lost", item.work_item_id <> ": " <> detail)
      config.poll_interval_ms
    }
  }
}

fn log(event: String, detail: String) -> Nil {
  io.println("[worker] " <> event <> " " <> detail)
}
