import clockwork
import gleam/erlang/process
import gleam/list
import gleam/time/duration
import gleam/time/timestamp

pub type Clock {
  Clock(name: String, cron: clockwork.Cron, run: fn() -> Nil)
}

pub fn start(clock: List(Clock)) -> Nil {
  list.each(clock, fn(clock) {
    let _ = process.spawn(fn() { loop(clock) })
    Nil
  })
}

pub fn next(clock: Clock, from: timestamp.Timestamp) -> timestamp.Timestamp {
  let Clock(cron:, ..) = clock

  clockwork.next_occurrence(
    given: cron,
    from: from,
    with_offset: duration.seconds(0),
  )
}

fn loop(clock: Clock) -> Nil {
  let now = timestamp.system_time()
  let at = next(clock, now)
  let wait = timestamp.difference(now, at) |> duration.to_milliseconds
  let Clock(run:, ..) = clock

  process.sleep(wait)
  run()
  loop(clock)
}
