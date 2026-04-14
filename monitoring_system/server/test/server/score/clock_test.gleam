import clockwork
import gleam/time/calendar
import gleam/time/timestamp
import server/clock
import server/score
import server/score/clock as score_clock

pub fn cron_test() {
  let assert Ok(cron) = clockwork.from_string(score_clock.cron_expression)
  let next =
    clock.next(
      clock.Clock(name: "score", cron:, run: fn() { Nil }),
      timestamp.from_calendar(
        date: calendar.Date(2026, calendar.April, 16),
        time: calendar.TimeOfDay(10, 2, 10, 0),
        offset: calendar.utc_offset,
      ),
    )

  assert timestamp.to_rfc3339(next, calendar.utc_offset)
    == "2026-04-16T10:04:00Z"
}

pub fn key_test() {
  assert score.key("candidate-123") == "score:candidate-123"
}
