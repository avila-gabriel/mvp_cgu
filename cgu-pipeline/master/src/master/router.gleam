import envoy
import gleam/http/request
import gleam/http/response
import gleam/option
import gleam/string
import master/web.{type Context}
import master/web/analysis
import master/web/health
import master/web/preparation
import master/web/provider_slots
import master/web/work_items
import master/web/workers
import wisp.{type Request, type Response}

const max_request_body_size = 104_857_600

pub fn handle_request(req: Request, ctx: Context) -> Response {
  let req = wisp.set_max_body_size(req, max_request_body_size)
  use req <- web.middleware(req)
  let assert Ok(priv) = wisp.priv_directory("master")
    as "master priv directory is required"
  let static_dir = priv <> "/static"
  use <- wisp.serve_static(req, under: "/", from: static_dir)

  let segments = wisp.path_segments(req)
  case segments {
    ["api", ..] ->
      case is_authorized(req) {
        True -> route(segments, req, ctx, static_dir)
        False -> unauthorized()
      }
    _ -> route(segments, req, ctx, static_dir)
  }
}

fn route(
  segments: List(String),
  req: Request,
  ctx: Context,
  static_dir: String,
) -> Response {
  case segments {
    [] -> serve_app(static_dir)
    ["health"] -> health.health(req, ctx)
    ["api", "work-items"] -> work_items.work_items(req, ctx)
    ["api", "work-items", "claim"] -> work_items.claim(req, ctx)
    ["api", "work-items", work_item_id, "renew-lease"] ->
      work_items.renew_lease(req, ctx, work_item_id)
    ["api", "work-items", work_item_id, "complete"] ->
      work_items.complete(req, ctx, work_item_id)
    ["api", "work-items", work_item_id, "fail"] ->
      work_items.fail(req, ctx, work_item_id)
    ["api", "workers", "heartbeat"] -> workers.heartbeat(req, ctx)
    ["api", "provider-slots", "acquire"] -> provider_slots.acquire(req, ctx)
    ["api", "provider-slots", "report"] -> provider_slots.report(req, ctx)
    ["api", "csv", "ingest"] -> work_items.csv_ingest(req, ctx)
    ["api", "xlsx", "ingest"] -> work_items.xlsx_ingest(req, ctx)
    ["api", "analysis", "data-insights"] -> analysis.data_insights(req, ctx)
    ["api", "analysis", "prepared-items"] -> analysis.prepared_items(req, ctx)
    ["api", "preparation", "artifacts", "claim"] -> preparation.claim(req, ctx)
    ["api", "preparation", "artifacts", artifact_id, "body"] ->
      preparation.artifact_body(req, ctx, artifact_id)
    ["api", "preparation", "artifacts", artifact_id, "extraction"] ->
      preparation.extraction(req, ctx, artifact_id)
    _ -> wisp.not_found()
  }
}

fn is_authorized(req: Request) -> Bool {
  case access_key() {
    "" -> True
    expected -> {
      request.get_header(req, "x-master-access-key") == Ok(expected)
      || bearer_token(req) == Ok(expected)
    }
  }
}

fn access_key() -> String {
  case envoy.get("MASTER_ACCESS_KEY") {
    Ok(value) -> string.trim(value)
    Error(Nil) -> ""
  }
}

fn bearer_token(req: Request) -> Result(String, Nil) {
  case request.get_header(req, "authorization") {
    Ok(header) ->
      case string.starts_with(header, "Bearer ") {
        True -> Ok(string.drop_start(header, 7))
        False -> Error(Nil)
      }
    Error(Nil) -> Error(Nil)
  }
}

fn unauthorized() -> Response {
  "{\"error\":\"unauthorized\"}"
  |> wisp.json_response(401)
  |> response.set_header("www-authenticate", "Bearer")
}

fn serve_app(static_dir: String) -> Response {
  wisp.response(200)
  |> response.set_header("content-type", "text/html; charset=utf-8")
  |> wisp.set_body(wisp.File(
    path: static_dir <> "/index.html",
    offset: 0,
    limit: option.None,
  ))
}
