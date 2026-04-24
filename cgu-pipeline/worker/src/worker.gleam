import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import worker/manager
import worker/startup

pub fn main() -> Nil {
  let config = startup.load_config()
  startup.check(config)
  let slot_supervisor_name = process.new_name(prefix: "worker_slot_supervisor")
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(manager.slot_supervisor(slot_supervisor_name))
    |> supervisor.add(manager.supervised(config, slot_supervisor_name))
    |> supervisor.start
    as "worker supervisor failed to start"
  process.sleep_forever()
}
