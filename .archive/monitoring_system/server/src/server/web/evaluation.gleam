import cors_builder
import gleam/http.{Options, Post}
import gleam/string
import server/evaluation
import server/log
import server/web.{type Context}
import wisp.{type Request, type Response}

const extension_origin = "chrome-extension://REPLACE_EXTENSION_ID"

pub fn ingest(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use _req <- cors_builder.wisp_middleware(req, cors())

  case evaluation.process(ctx.db, req) {
    Ok(_) -> wisp.created()
    Error(detail) -> {
      log.error("ingest evaluation", detail)
      wisp.internal_server_error()
    }
  }
}

fn cors() -> cors_builder.Cors {
  cors_builder.new()
  |> cors_builder.allow_origin(extension_origin)
  |> cors_builder.allow_method(Post)
  |> cors_builder.allow_method(Options)
  |> cors_builder.allow_header("content-type")
  |> cors_builder.max_age(600)
}

pub fn check() -> Result(Nil, String) {
  case
    string.starts_with(extension_origin, "chrome-extension://")
    || string.starts_with(extension_origin, "moz-extension://")
  {
    True -> Ok(Nil)
    False ->
      Error(
        "server/web/evaluation.extension_origin must be a valid browser extension origin like chrome-extension://<id> or moz-extension://<id>",
      )
  }
}
