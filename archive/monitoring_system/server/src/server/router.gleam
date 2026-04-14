import server/web.{type Context}
import server/web/error
import server/web/evaluation
import server/web/inbox
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] | ["inbox"] -> inbox.page(req, ctx)
    ["api", "evaluation", "ingest"] -> evaluation.ingest(req, ctx)
    ["api", "ingest", "error"] -> error.error(req, ctx)
    ["api", "inbox", "queue"] -> inbox.queue(req, ctx)
    ["inbox", evaluation_id, "claim"] -> inbox.claim(req, ctx, evaluation_id)
    _ -> wisp.not_found()
  }
}
