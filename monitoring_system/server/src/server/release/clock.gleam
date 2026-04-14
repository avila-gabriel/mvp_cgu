import clockwork
import pog
import server/clock
import server/log
import server/release

pub const cron_expression = "* * * * *"

pub fn clock(db: pog.Connection, cron: clockwork.Cron) -> clock.Clock {
  clock.Clock(name: "release", cron:, run: fn() { run(db) })
}

pub fn run(db: pog.Connection) -> Nil {
  case release.enqueue(db) {
    Ok(_) -> Nil
    Error(detail) -> log.error("enqueue release job", detail)
  }
}
