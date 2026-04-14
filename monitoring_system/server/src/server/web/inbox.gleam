import gleam/http.{Get, Post}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/calendar
import gleam/time/timestamp
import server/inbox/sql
import server/web.{type Context}
import shared/inbox
import wisp.{type Request, type Response}
import youid/uuid

const lease_holder = "lease"

pub fn page(req: Request, _ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)
  wisp.html_response(page_html(), 200)
}

pub fn queue(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)
  use rows <- web.require_many_query(
    sql.queue(ctx.db),
    while: "load inbox queue",
  )

  let entry =
    rows
    |> list.map(queue_row_to_entry)
    |> option.values

  wisp.json_response(
    entry
      |> json.array(inbox.entry_to_json)
      |> json.to_string,
    200,
  )
}

pub fn claim(req: Request, ctx: Context, evaluation_id: String) -> Response {
  use <- wisp.require_method(req, Post)

  use evaluation_id <- web.require_value(
    value: evaluation_id,
    parse: uuid.from_string,
    on_invalid: wisp.bad_request("Invalid evaluation id."),
  )
  use claimed_count <- web.require_count(
    sql.claim(ctx.db, evaluation_id, lease_holder, 1800.0),
    while: "claim evaluation",
  )

  case claimed_count > 0 {
    True -> wisp.created()
    False -> wisp.unprocessable_content()
  }
}

fn page_html() -> String {
  "
<!doctype html>
<html lang=\"en\">
  <head>
    <meta charset=\"utf-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
    <title>Priority Queue</title>
    <link rel=\"stylesheet\" href=\"/static/client.css\">
  </head>
  <body>
    <div id=\"app\"></div>
    <script type=\"module\" src=\"/static/client.js\"></script>
  </body>
</html>
"
}

fn queue_row_to_entry(row: sql.QueueRow) -> Option(inbox.QueueEntry) {
  let sql.QueueRow(
    evaluation_id:,
    organization_name:,
    base_url:,
    priority:,
    priority_summary:,
    aging_deadline_at:,
    last_prioritized_at:,
    updated_at: _,
    event:,
    top_url:,
    explanation_summary:,
    top_item_priority:,
  ) = row

  case priority {
    Some(priority) ->
      Some(inbox.QueueEntry(
        evaluation_id:,
        organization_name:,
        base_url:,
        priority:,
        priority_summary:,
        aging_deadline_at: option.map(aging_deadline_at, timestamp.to_rfc3339(
          _,
          calendar.utc_offset,
        )),
        last_prioritized_at: option.map(
          last_prioritized_at,
          timestamp.to_rfc3339(_, calendar.utc_offset),
        ),
        event: option.map(event, event_to_shared),
        top_url:,
        explanation_summary:,
        top_item_priority:,
      ))

    None -> None
  }
}

fn event_to_shared(event: sql.MonitoredChangeEvent) -> inbox.Event {
  case event {
    sql.PageChanged -> inbox.PageChanged
    sql.PathDiscovered -> inbox.PathDiscovered
    sql.PathRemoved -> inbox.PathRemoved
    sql.TopologyChanged -> inbox.TopologyChanged
  }
}
