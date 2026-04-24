import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/otp/factory_supervisor as factory
import gleam/otp/supervision
import gleam/string
import worker/config.{type Config, Config}
import worker/master_client
import worker/runtime

const heartbeat_interval_ms = 10_000

const worker_capacity = 2

pub type SlotConfig {
  SlotConfig(config: Config, slot_number: Int)
}

pub type Message {
  Heartbeat
}

type Slot {
  Slot(
    slot_number: Int,
    subject: process.Subject(runtime.Message),
    draining: Bool,
  )
}

type State {
  State(
    config: Config,
    slot_supervisor: factory.Supervisor(
      SlotConfig,
      process.Subject(runtime.Message),
    ),
    control: process.Subject(Message),
    slots: List(Slot),
  )
}

pub fn slot_supervisor(
  name: process.Name(
    factory.Message(SlotConfig, process.Subject(runtime.Message)),
  ),
) -> supervision.ChildSpecification(
  factory.Supervisor(SlotConfig, process.Subject(runtime.Message)),
) {
  factory.worker_child(start_slot)
  |> factory.named(name)
  |> factory.supervised
}

pub fn supervised(
  config: Config,
  slot_supervisor_name: process.Name(
    factory.Message(SlotConfig, process.Subject(runtime.Message)),
  ),
) -> supervision.ChildSpecification(Nil) {
  supervision.worker(fn() { start(config, slot_supervisor_name) })
  |> supervision.map_data(fn(_) { Nil })
}

fn start_slot(slot_config: SlotConfig) {
  let SlotConfig(config:, slot_number:) = slot_config
  runtime.start(
    Config(..config, worker_id: slot_worker_id(config.worker_id, slot_number)),
  )
}

fn start(
  config: Config,
  slot_supervisor_name: process.Name(
    factory.Message(SlotConfig, process.Subject(runtime.Message)),
  ),
) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {
  actor.new_with_initialiser(1000, initialise(config, slot_supervisor_name, _))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn initialise(
  config: Config,
  slot_supervisor_name: process.Name(
    factory.Message(SlotConfig, process.Subject(runtime.Message)),
  ),
  control: process.Subject(Message),
) -> Result(actor.Initialised(State, Message, process.Subject(Message)), String) {
  let _ = process.send_after(control, 0, Heartbeat)
  Ok(
    actor.initialised(
      State(
        config:,
        slot_supervisor: factory.get_by_name(slot_supervisor_name),
        control:,
        slots: [],
      ),
    )
    |> actor.returning(control),
  )
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Heartbeat -> {
      let state = heartbeat(state)
      let _ =
        process.send_after(state.control, heartbeat_interval_ms, Heartbeat)
      actor.continue(state)
    }
  }
}

fn heartbeat(state: State) -> State {
  case master_client.heartbeat(state.config, worker_capacity) {
    Ok(response) -> reconcile(state, response.assigned_fetch_slots)
    Error(error) -> {
      log("heartbeat_failed", master_client.describe_error(error))
      state
    }
  }
}

fn reconcile(state: State, assigned_slots: Int) -> State {
  let assigned_slots = clamp(assigned_slots, 0, worker_capacity)
  let active_count = active_slot_count(state.slots)

  case active_count < assigned_slots {
    True -> start_missing_slots(state, assigned_slots)
    False ->
      case active_count > assigned_slots {
        True -> drain_extra_slots(state, active_count - assigned_slots)
        False -> state
      }
  }
}

fn start_missing_slots(state: State, assigned_slots: Int) -> State {
  let next_slot = next_slot_number(state.slots)

  case active_slot_count(state.slots) < assigned_slots {
    True ->
      case
        factory.start_child(
          state.slot_supervisor,
          SlotConfig(config: state.config, slot_number: next_slot),
        )
      {
        Ok(started) ->
          start_missing_slots(
            State(..state, slots: [
              Slot(
                slot_number: next_slot,
                subject: started.data,
                draining: False,
              ),
              ..state.slots
            ]),
            assigned_slots,
          )

        Error(error) -> {
          log(
            "slot_start_failed: " <> string.inspect(error),
            int.to_string(next_slot),
          )
          state
        }
      }

    False -> state
  }
}

fn drain_extra_slots(state: State, count: Int) -> State {
  let #(slots, _remaining) =
    list.fold(state.slots, #([], count), fn(acc, slot) {
      let #(slots, remaining) = acc

      case remaining > 0 && !slot.draining {
        True -> {
          runtime.drain(slot.subject)
          #([Slot(..slot, draining: True), ..slots], remaining - 1)
        }
        False -> #([slot, ..slots], remaining)
      }
    })

  State(..state, slots: list.reverse(slots))
}

fn active_slot_count(slots: List(Slot)) -> Int {
  slots
  |> list.filter(fn(slot) { !slot.draining })
  |> list.length
}

fn next_slot_number(slots: List(Slot)) -> Int {
  slots
  |> list.map(fn(slot) { slot.slot_number })
  |> list.fold(0, int.max)
  |> int.add(1)
}

fn slot_worker_id(worker_id: String, slot_number: Int) -> String {
  worker_id <> "#" <> int.to_string(slot_number)
}

fn clamp(value: Int, minimum: Int, maximum: Int) -> Int {
  case value < minimum {
    True -> minimum
    False ->
      case value > maximum {
        True -> maximum
        False -> value
      }
  }
}

fn log(event: String, detail: String) -> Nil {
  io.println("[worker-manager] " <> event <> " " <> detail)
}
