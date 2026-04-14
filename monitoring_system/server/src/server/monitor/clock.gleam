import clockwork
import gleam/list
import pog
import server/clock
import server/db
import server/log
import server/monitor
import server/monitor/sql

type Due {
  Due(evaluation_id: String, slot: Int)
}

pub const cron_expression = "*/30 * * * *"

pub fn clock(db: pog.Connection, cron: clockwork.Cron) -> clock.Clock {
  clock.Clock(name: "monitor", cron:, run: fn() { run(db) })
}

pub fn run(db: pog.Connection) -> Nil {
  case due(db) {
    Ok(due_evaluations) ->
      list.each(due_evaluations, fn(entry) {
        let Due(evaluation_id:, slot:) = entry

        case monitor.enqueue_due(db, evaluation_id, slot) {
          Ok(_) -> Nil
          Error(detail) -> log.error("enqueue due monitor job", detail)
        }
      })

    Error(detail) -> log.error("load due monitor evaluations", detail)
  }
}

fn due(conn: pog.Connection) -> Result(List(Due), String) {
  use rows <- db.require_many(
    sql.due(conn),
    on_error: Error("failed to load due monitor evaluations"),
  )
  Ok(
    list.map(rows, fn(row) {
      let sql.DueRow(evaluation_id:, slot:) = row
      Due(evaluation_id:, slot:)
    }),
  )
}
