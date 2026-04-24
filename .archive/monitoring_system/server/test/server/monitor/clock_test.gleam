import clockwork
import gleam/time/calendar
import gleam/time/timestamp
import server/clock
import server/monitor
import server/monitor/clock as monitor_clock

pub fn cron_test() {
  let assert Ok(cron) = clockwork.from_string(monitor_clock.cron_expression)
  let next =
    clock.next(
      clock.Clock(name: "monitor", cron:, run: fn() { Nil }),
      timestamp.from_calendar(
        date: calendar.Date(2026, calendar.April, 16),
        time: calendar.TimeOfDay(10, 2, 10, 0),
        offset: calendar.utc_offset,
      ),
    )

  assert timestamp.to_rfc3339(next, calendar.utc_offset)
    == "2026-04-16T10:30:00Z"
}

pub fn due_key_test() {
  assert monitor.due_key("evaluation-123", 1_760_000_000)
    == "monitor:evaluation-123:1760000000"
}
