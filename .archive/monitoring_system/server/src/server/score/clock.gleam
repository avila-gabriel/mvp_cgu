import clockwork
import gleam/list
import pog
import server/clock
import server/db
import server/log
import server/score
import server/score/sql

type Due {
  Due(change_id: String)
}

pub const cron_expression = "*/2 * * * *"

pub fn clock(db: pog.Connection, cron: clockwork.Cron) -> clock.Clock {
  clock.Clock(name: "score", cron:, run: fn() { run(db) })
}

pub fn run(db: pog.Connection) -> Nil {
  case due(db) {
    Ok(due_change) ->
      list.each(due_change, fn(entry) {
        let Due(change_id:) = entry

        case score.enqueue(db, change_id) {
          Ok(_) -> Nil
          Error(detail) -> log.error("enqueue score job", detail)
        }
      })

    Error(detail) -> log.error("load due score candidates", detail)
  }
}

fn due(conn: pog.Connection) -> Result(List(Due), String) {
  use rows <- db.require_many(
    sql.due(conn),
    on_error: Error("failed to load due score candidates"),
  )
  Ok(
    list.map(rows, fn(row) {
      let sql.DueRow(change_id:) = row
      Due(change_id:)
    }),
  )
}
