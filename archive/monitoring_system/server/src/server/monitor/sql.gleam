//// This module contains the code to run the sql queries defined in
//// `./src/server/monitor/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import pog

/// Persist candidate changes that survived the monitor noise and relevance passes.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn candidate(
  db: pog.Connection,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Persist candidate changes that survived the monitor noise and relevance passes.
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Insert newly discovered paths that became relevant during the bounded crawl.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn discover(db: pog.Connection) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Insert newly discovered paths that became relevant during the bounded crawl.
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `due` query
/// defined in `./src/server/monitor/sql/due.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type DueRow {
  DueRow(evaluation_id: String, slot: Int)
}

/// Runs the `due` query
/// defined in `./src/server/monitor/sql/due.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn due(db: pog.Connection) -> Result(pog.Returned(DueRow), pog.QueryError) {
  let decoder = {
    use evaluation_id <- decode.field(0, decode.string)
    use slot <- decode.field(1, decode.int)
    decode.success(DueRow(evaluation_id:, slot:))
  }

  "with picked as (
  select
    evaluation.id,
    evaluation.next_monitor_at
  from
    evaluation
  where
    evaluation.is_active
    and evaluation.next_monitor_at <= timezone('utc', now())
    and exists (
      select
        1
      from
        evaluation_item
      where
        evaluation_item.evaluation_id = evaluation.id
        and evaluation_item.status <> 'fully_complies'
    )
  order by
    evaluation.next_monitor_at asc
  for update skip locked
),
updated as (
  update evaluation
  set
    next_monitor_at = timezone('utc', now()) + interval '30 minutes'
  from
    picked
  where
    evaluation.id = picked.id
  returning
    evaluation.id::text as evaluation_id,
    extract(epoch from picked.next_monitor_at)::int as slot
)
select
  evaluation_id,
  slot
from
  updated;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Mark previously known paths as removed when they disappear from the current crawl.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn remove(db: pog.Connection) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Mark previously known paths as removed when they disappear from the current crawl.
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Load the full monitoring scope for one evaluation:
/// active items, monitored URLs, known paths, and latest baseline snapshots.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn scope(db: pog.Connection) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Load the full monitoring scope for one evaluation:
-- active items, monitored URLs, known paths, and latest baseline snapshots.
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Persist the latest normalized snapshot rows produced by the monitor job.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn snapshot(db: pog.Connection) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Persist the latest normalized snapshot rows produced by the monitor job.
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Update freshness markers such as last seen timestamps for known paths.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn touch(db: pog.Connection) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Update freshness markers such as last seen timestamps for known paths.
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}
