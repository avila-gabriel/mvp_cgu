import cigogne
import gleam/erlang/process
import m25
import mist
import server/clock
import server/router
import startup
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()
  let startup.Startup(
    port:,
    secret_key_base:,
    migration_engine:,
    clocks:,
    jobs:,
    context:,
  ) = startup.check()

  let assert Ok(_) = cigogne.apply_all(migration_engine) as "migration failed"
  let assert Ok(_) = m25.start(jobs, 1000) as "m25 failed to start"
  clock.start(clocks)

  let assert Ok(_) =
    router.handle_request(_, context)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(port)
    |> mist.start
    as "mist start failed"

  process.sleep_forever()
}
