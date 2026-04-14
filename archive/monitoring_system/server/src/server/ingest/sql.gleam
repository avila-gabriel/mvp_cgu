//// This module contains the code to run the sql queries defined in
//// `./src/server/ingest/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `error` query
/// defined in `./src/server/ingest/sql/error.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ErrorRow {
  ErrorRow(extension_error_id: String, error: String, reported_at: Timestamp)
}

/// Runs the `error` query
/// defined in `./src/server/ingest/sql/error.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn error(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Timestamp,
  arg_4: Json,
) -> Result(pog.Returned(ErrorRow), pog.QueryError) {
  let decoder = {
    use extension_error_id <- decode.field(0, decode.string)
    use error <- decode.field(1, decode.string)
    use reported_at <- decode.field(2, pog.timestamp_decoder())
    decode.success(ErrorRow(extension_error_id:, error:, reported_at:))
  }

  "insert into extension_error (
  error,
  extension_version,
  reported_at,
  payload
)
values (
  $1,
  $2,
  $3::timestamp,
  $4::jsonb
)
returning
  id::text as extension_error_id,
  error,
  reported_at
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.parameter(pog.text(json.to_string(arg_4)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
