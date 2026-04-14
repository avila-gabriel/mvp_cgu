import cors_builder
import gleam/dynamic/decode
import gleam/http.{Options, Post}
import gleam/string
import gleam/time/timestamp
import server/ingest/sql
import server/web.{type Context}
import shared/extension
import wisp.{type Request, type Response}

const extension_origin = "chrome-extension://REPLACE_EXTENSION_ID"

pub fn error(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use _req <- cors_builder.wisp_middleware(req, cors())
  use json <- wisp.require_json(req)

  case decode.run(json, extension.error_report_decoder()) {
    Ok(report) -> {
      let extension.ErrorReport(
        error:,
        extension_version:,
        timestamp_seconds:,
        timestamp_nanoseconds:,
      ) = report

      use _ <- web.require_query(
        sql.error(
          ctx.db,
          error,
          extension_version,
          timestamp.from_unix_seconds_and_nanoseconds(
            seconds: timestamp_seconds,
            nanoseconds: timestamp_nanoseconds,
          ),
          extension.error_report_to_json(report),
        ),
        while: "persist extension error",
      )

      wisp.created()
    }

    Error(_decode_error) -> wisp.unprocessable_content()
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
        "server/web/error.extension_origin must be a valid browser extension origin like chrome-extension://<id> or moz-extension://<id>",
      )
  }
}
