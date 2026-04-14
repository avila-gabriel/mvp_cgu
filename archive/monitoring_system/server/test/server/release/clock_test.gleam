import clockwork
import gleam/time/calendar
import gleam/time/timestamp
import server/clock
import server/release
import server/release/clock as release_clock

pub fn cron_test() {
  let assert Ok(cron) = clockwork.from_string(release_clock.cron_expression)
  let next =
    clock.next(
      clock.Clock(name: "release", cron:, run: fn() { Nil }),
      timestamp.from_calendar(
        date: calendar.Date(2026, calendar.April, 17),
        time: calendar.TimeOfDay(10, 2, 10, 0),
        offset: calendar.utc_offset,
      ),
    )

  assert timestamp.to_rfc3339(next, calendar.utc_offset)
    == "2026-04-17T10:03:00Z"
}

pub fn key_test() {
  assert release.key() == "release"
}
