import gleam/bit_array
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/json
import gleam/option.{None, Some}
import master/log
import master/storage
import master/web.{type Context}
import master/work_items/queries/sql as query
import wisp.{type Request, type Response}
import youid/uuid

const max_batch_limit = 500

const extractor = "deboiler"

const extractor_version = "2023.46.150"

pub fn claim(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use input <- web.require_parsed_json(req, claim_decoder())
  let limit = clamp(input.limit, 1, max_batch_limit)

  use rows <- web.require_many_query(
    query.preparation_claim(ctx.db, input.worker_id, input.lease_seconds, limit),
    while: "claim preparation artifacts",
  )

  json.object([
    #("limit", json.int(limit)),
    #("artifacts", json.array(rows, artifact_to_json)),
  ])
  |> json.to_string
  |> wisp.json_response(200)
}

pub fn artifact_body(
  req: Request,
  ctx: Context,
  artifact_id: String,
) -> Response {
  use <- wisp.require_method(req, Get)
  use id <- require_uuid(artifact_id)
  use row <- web.require_optional_query(
    query.artifact_body(ctx.db, id),
    while: "load artifact body metadata",
  )

  case row {
    None -> wisp.not_found()
    Some(row) -> {
      let query.ArtifactBodyRow(storage_url:) = row
      case storage.load(ctx.storage, storage_url) {
        Ok(body) ->
          json.object([
            #("artifact_id", json.string(artifact_id)),
            #("body_base64", json.string(bit_array.base64_encode(body, True))),
          ])
          |> json.to_string
          |> wisp.json_response(200)

        Error(error) -> {
          log.error("load artifact body", storage.describe_error(error))
          wisp.internal_server_error()
        }
      }
    }
  }
}

pub fn extraction(req: Request, ctx: Context, artifact_id: String) -> Response {
  use <- wisp.require_method(req, Post)
  use id <- require_uuid(artifact_id)
  use input <- web.require_parsed_json(req, extraction_decoder())
  use row <- web.require_optional_query(
    query.complete_artifact_text(
      ctx.db,
      id,
      input.extraction_status,
      input.title,
      input.headings,
      input.lists,
      input.breadcrumbs,
      input.language,
      input.raw_text,
      input.cleaned_text,
      input.cleaned_html,
      input.char_count,
      input.cleaned_char_count,
      input.content_type,
      extractor,
      extractor_version,
      input.error,
      input.worker_id,
    ),
    while: "complete artifact extraction",
  )

  case row {
    Some(_) ->
      json.object([#("artifact_id", json.string(artifact_id))])
      |> json.to_string
      |> wisp.json_response(200)

    None ->
      json.object([#("error", json.string("preparation_lease_conflict"))])
      |> json.to_string
      |> wisp.json_response(409)
  }
}

type ExtractionInput {
  ExtractionInput(
    extraction_status: String,
    title: String,
    headings: String,
    lists: String,
    breadcrumbs: String,
    language: String,
    raw_text: String,
    cleaned_text: String,
    cleaned_html: String,
    char_count: Int,
    cleaned_char_count: Int,
    content_type: String,
    error: String,
    worker_id: String,
  )
}

type ClaimInput {
  ClaimInput(worker_id: String, lease_seconds: Float, limit: Int)
}

fn artifact_to_json(row: query.PreparationClaimRow) -> json.Json {
  let query.PreparationClaimRow(
    artifact_id:,
    subject_id:,
    fetch_host:,
    source_url:,
    fetched_url:,
    content_type:,
    body_sha256:,
    body_size_bytes:,
  ) = row

  json.object([
    #("artifact_id", json.string(artifact_id)),
    #("subject_id", json.string(subject_id)),
    #("host", json.string(fetch_host)),
    #("source_url", json.string(source_url)),
    #("fetched_url", json.string(fetched_url)),
    #("content_type", case content_type {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #("body_sha256", json.string(body_sha256)),
    #("body_size_bytes", json.int(body_size_bytes)),
  ])
}

fn claim_decoder() -> decode.Decoder(ClaimInput) {
  use worker_id <- decode.field("worker_id", decode.string)
  use lease_seconds <- decode.field("lease_seconds", decode.float)
  use limit <- decode.field("limit", decode.int)
  decode.success(ClaimInput(worker_id:, lease_seconds:, limit:))
}

fn extraction_decoder() -> decode.Decoder(ExtractionInput) {
  use extraction_status <- decode.field("extraction_status", decode.string)
  use title <- decode.optional_field("title", "", decode.string)
  use headings <- decode.optional_field("headings", "", decode.string)
  use lists <- decode.optional_field("lists", "", decode.string)
  use breadcrumbs <- decode.optional_field("breadcrumbs", "", decode.string)
  use language <- decode.optional_field("language", "", decode.string)
  use raw_text <- decode.optional_field("raw_text", "", decode.string)
  use cleaned_text <- decode.optional_field("cleaned_text", "", decode.string)
  use cleaned_html <- decode.optional_field("cleaned_html", "", decode.string)
  use char_count <- decode.field("char_count", decode.int)
  use cleaned_char_count <- decode.field("cleaned_char_count", decode.int)
  use content_type <- decode.optional_field("content_type", "", decode.string)
  use error <- decode.optional_field("error", "", decode.string)
  use worker_id <- decode.field("worker_id", decode.string)
  decode.success(ExtractionInput(
    extraction_status:,
    title:,
    headings:,
    lists:,
    breadcrumbs:,
    language:,
    raw_text:,
    cleaned_text:,
    cleaned_html:,
    char_count:,
    cleaned_char_count:,
    content_type:,
    error:,
    worker_id:,
  ))
}

fn require_uuid(id: String, next: fn(uuid.Uuid) -> Response) -> Response {
  case uuid.from_string(id) {
    Ok(id) -> next(id)
    Error(Nil) -> wisp.bad_request("artifact_id must be a UUID.")
  }
}

fn clamp(value: Int, minimum: Int, maximum: Int) -> Int {
  case value < minimum {
    True -> minimum
    False ->
      case value > maximum {
        True -> maximum
        False -> value
      }
  }
}
