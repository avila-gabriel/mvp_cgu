import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/string
import master/db
import master/log
import master/storage
import pog
import wisp.{type Request, type Response}

pub type Context {
  Context(db: pog.Connection, storage: storage.Config)
}

pub fn require_many_query(
  attempt: Result(pog.Returned(row), pog.QueryError),
  while action: String,
  next next: fn(List(row)) -> Response,
) -> Response {
  db.query_many(attempt, on_query: query_error(action, _), next: next)
}

pub fn require_optional_query(
  attempt: Result(pog.Returned(row), pog.QueryError),
  while action: String,
  next next: fn(Option(row)) -> Response,
) -> Response {
  db.query_optional(
    attempt,
    on_query: query_error(action, _),
    on_cardinality: fn() { one_query_error(action) },
    next: next,
  )
}

pub fn require_one_query(
  attempt: Result(pog.Returned(row), pog.QueryError),
  while action: String,
  next next: fn(row) -> Response,
) -> Response {
  db.query_one(
    attempt,
    on_query: query_error(action, _),
    on_cardinality: fn() { one_query_error(action) },
    next: next,
  )
}

fn query_error(action: String, query_error: pog.QueryError) -> Response {
  log.query_error(action, query_error)
  wisp.internal_server_error()
}

fn one_query_error(action: String) -> Response {
  log.query_cardinality_error(action, "one row")
  wisp.internal_server_error()
}

pub fn require_parsed_json(
  req: Request,
  decoder: decode.Decoder(value),
  next: fn(value) -> Response,
) -> Response {
  use json <- wisp.require_json(req)
  case decode.run(json, decoder) {
    Ok(value) -> next(value)
    Error(error) ->
      wisp.bad_request(
        "JSON payload does not match the expected shape: "
        <> string.inspect(error),
      )
  }
}

pub fn middleware(req: Request, next: fn(Request) -> Response) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes()
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)

  next(req)
}
