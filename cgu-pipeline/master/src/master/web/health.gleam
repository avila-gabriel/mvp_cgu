import gleam/http.{Get}
import gleam/json
import master/web.{type Context}
import wisp.{type Request, type Response}

pub fn health(req: Request, _ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)

  json.object([#("status", json.string("ok"))])
  |> json.to_string
  |> wisp.json_response(200)
}
