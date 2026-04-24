import pog
import server/db
import server/log
import wisp.{type Request, type Response}

pub type Context {
  Context(db: pog.Connection)
}

pub fn require_value(
  value value: value,
  parse parse: fn(value) -> Result(parsed, Nil),
  on_invalid on_invalid: return,
  next next: fn(parsed) -> return,
) -> return {
  case parse(value) {
    Ok(parsed) -> next(parsed)
    Error(Nil) -> on_invalid
  }
}

pub fn require_query(
  attempt: Result(pog.Returned(row), pog.QueryError),
  while action: String,
  next next: fn(row) -> Response,
) -> Response {
  db.query_one(
    attempt,
    on_query: query_error(action, _),
    on_cardinality: one_query_error(action),
    next: next,
  )
}

pub fn require_many_query(
  attempt: Result(pog.Returned(row), pog.QueryError),
  while action: String,
  next next: fn(List(row)) -> Response,
) -> Response {
  db.query_many(attempt, on_query: query_error(action, _), next: next)
}

pub fn require_count(
  attempt: Result(pog.Returned(row), pog.QueryError),
  while action: String,
  next next: fn(Int) -> Response,
) -> Response {
  db.count(attempt, on_query: query_error(action, _), next: next)
}

fn query_error(action: String, query_error: pog.QueryError) -> Response {
  log.query_error(action, query_error)
  wisp.internal_server_error()
}

fn one_query_error(action: String) -> Response {
  log.query_cardinality_error(action, "one row")
  wisp.internal_server_error()
}

pub fn middleware(req: Request, next: fn(Request) -> Response) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes()
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)
  use <- wisp.serve_static(req, under: "/static", from: "priv/static")

  next(req)
}
