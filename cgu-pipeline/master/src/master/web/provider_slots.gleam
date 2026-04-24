import gleam/http.{Post}
import gleam/json
import gleam/option.{type Option, None, Some}
import master/web.{type Context}
import master/work_items/queries/sql as query
import shared/work_items as transport
import wisp.{type Request, type Response}

pub fn acquire(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use input <- web.require_parsed_json(
    req,
    transport.provider_slot_acquire_request_decoder(),
  )
  use delay <- require_provider_delay(input.provider_key)
  use row <- web.require_one_query(
    query.provider_slot_acquire(ctx.db, input.provider_key, delay),
    while: "acquire provider slot",
  )

  transport.ProviderSlotAcquireResponse(delay_ms: row.delay_ms)
  |> transport.provider_slot_acquire_response_to_json
  |> json.to_string
  |> wisp.json_response(200)
}

pub fn report(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use input <- web.require_parsed_json(
    req,
    transport.provider_slot_report_request_decoder(),
  )
  use delay <- require_provider_delay(input.provider_key)
  use _ <- web.require_one_query(
    query.provider_slot_report(
      ctx.db,
      input.provider_key,
      input.status_code,
      delay,
    ),
    while: "report provider status",
  )

  json.object([#("ok", json.bool(True))])
  |> json.to_string
  |> wisp.json_response(200)
}

fn require_provider_delay(
  provider_key: String,
  next: fn(Float) -> Response,
) -> Response {
  case provider_delay(provider_key) {
    Some(delay) -> next(delay)
    None -> wisp.bad_request("provider_key is not supported.")
  }
}

fn provider_delay(provider_key: String) -> Option(Float) {
  case provider_key {
    "wayback_lookup" -> Some(1.0)
    "wayback_replay" -> Some(1.0)
    "arquivo_lookup" -> Some(1.0)
    "arquivo_replay" -> Some(1.0)
    "archive_it_lookup" -> Some(1.0)
    "archive_it_replay" -> Some(1.0)
    "loc_lookup" -> Some(3.0)
    "loc_replay" -> Some(3.0)
    _ -> None
  }
}
