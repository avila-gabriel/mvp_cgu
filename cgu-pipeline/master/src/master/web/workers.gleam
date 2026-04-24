import gleam/http.{Post}
import gleam/json
import gleam/list
import master/web.{type Context}
import master/work_items/queries/sql as query
import master/worker_slots
import shared/work_items as transport
import wisp.{type Request, type Response}

const heartbeat_timeout_seconds = 30.0

const global_fetch_slots = 2

pub fn heartbeat(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use input <- web.require_parsed_json(
    req,
    transport.worker_heartbeat_request_decoder(),
  )
  use heartbeat <- web.require_one_query(
    query.upsert_worker_heartbeat(ctx.db, input.worker_id, input.capacity),
    while: "record worker heartbeat",
  )
  use active_workers <- web.require_many_query(
    query.active_workers(ctx.db, heartbeat_timeout_seconds),
    while: "list active workers",
  )
  use _ <- web.require_many_query(
    query.clear_inactive_worker_assignments(ctx.db, heartbeat_timeout_seconds),
    while: "clear inactive worker assignments",
  )

  let assignments =
    worker_slots.assign(
      global_fetch_slots,
      list.map(active_workers, fn(row) {
        worker_slots.Worker(worker_id: row.worker_id, capacity: row.capacity)
      }),
    )

  use assigned_slots <- update_assignments(
    ctx,
    assignments,
    heartbeat.worker_id,
  )

  transport.WorkerHeartbeatResponse(assigned_fetch_slots: assigned_slots)
  |> transport.worker_heartbeat_response_to_json
  |> json.to_string
  |> wisp.json_response(200)
}

fn update_assignments(
  ctx: Context,
  assignments: List(worker_slots.Assignment),
  worker_id: String,
  next: fn(Int) -> Response,
) -> Response {
  case assignments {
    [] -> next(0)
    [assignment, ..rest] -> {
      let worker_slots.Assignment(
        worker_id: assigned_worker_id,
        assigned_slots:,
      ) = assignment
      use _ <- web.require_one_query(
        query.update_worker_assignment(
          ctx.db,
          assigned_worker_id,
          assigned_slots,
        ),
        while: "update worker assignment",
      )
      update_assignments(
        ctx,
        rest,
        worker_id,
        next_assigned_slots(worker_id, assigned_worker_id, assigned_slots, next),
      )
    }
  }
}

fn next_assigned_slots(
  worker_id: String,
  assigned_worker_id: String,
  assigned_slots: Int,
  next: fn(Int) -> Response,
) -> fn(Int) -> Response {
  fn(current_assigned_slots) {
    case worker_id == assigned_worker_id {
      True -> next(assigned_slots)
      False -> next(current_assigned_slots)
    }
  }
}
