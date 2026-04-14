//// This module contains the code to run the sql queries defined in
//// `./src/server/inbox/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog
import youid/uuid.{type Uuid}

/// A row you get from running the `claim` query
/// defined in `./src/server/inbox/sql/claim.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ClaimRow {
  ClaimRow(
    lease_id: String,
    evaluation_id: String,
    claimed_by: String,
    claimed_at: Timestamp,
    expires_at: Timestamp,
  )
}

/// Runs the `claim` query
/// defined in `./src/server/inbox/sql/claim.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn claim(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: Float,
) -> Result(pog.Returned(ClaimRow), pog.QueryError) {
  let decoder = {
    use lease_id <- decode.field(0, decode.string)
    use evaluation_id <- decode.field(1, decode.string)
    use claimed_by <- decode.field(2, decode.string)
    use claimed_at <- decode.field(3, pog.timestamp_decoder())
    use expires_at <- decode.field(4, pog.timestamp_decoder())
    decode.success(ClaimRow(
      lease_id:,
      evaluation_id:,
      claimed_by:,
      claimed_at:,
      expires_at:,
    ))
  }

  "with inserted_lease as (
  insert into lease (
    evaluation_id,
    claimed_by,
    expires_at
  )
  select
    $1::uuid,
    $2,
    timezone('utc', now()) + ($3 * interval '1 second')
  where
    exists (
      select
        1
      from
        evaluation_queue
      where
        evaluation_id = $1::uuid
    )
    and not exists (
      select
        1
      from
        lease
      where
        evaluation_id = $1::uuid
        and released_at is null
        and expires_at > timezone('utc', now())
    )
  returning
    id::text as lease_id,
    evaluation_id::text as evaluation_id,
    claimed_by,
    claimed_at,
    expires_at
)
select
  lease_id,
  evaluation_id,
  claimed_by,
  claimed_at,
  expires_at
from
  inserted_lease
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.float(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `queue` query
/// defined in `./src/server/inbox/sql/queue.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type QueueRow {
  QueueRow(
    evaluation_id: String,
    organization_name: String,
    base_url: String,
    priority: Option(Float),
    priority_summary: Option(String),
    aging_deadline_at: Option(Timestamp),
    last_prioritized_at: Option(Timestamp),
    updated_at: Timestamp,
    event: Option(MonitoredChangeEvent),
    top_url: Option(String),
    explanation_summary: Option(String),
    top_item_priority: Option(Float),
  )
}

/// Runs the `queue` query
/// defined in `./src/server/inbox/sql/queue.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn queue(
  db: pog.Connection,
) -> Result(pog.Returned(QueueRow), pog.QueryError) {
  let decoder = {
    use evaluation_id <- decode.field(0, decode.string)
    use organization_name <- decode.field(1, decode.string)
    use base_url <- decode.field(2, decode.string)
    use priority <- decode.field(3, decode.optional(decode.float))
    use priority_summary <- decode.field(4, decode.optional(decode.string))
    use aging_deadline_at <- decode.field(
      5,
      decode.optional(pog.timestamp_decoder()),
    )
    use last_prioritized_at <- decode.field(
      6,
      decode.optional(pog.timestamp_decoder()),
    )
    use updated_at <- decode.field(7, pog.timestamp_decoder())
    use event <- decode.field(
      8,
      decode.optional(monitored_change_event_decoder()),
    )
    use top_url <- decode.field(9, decode.optional(decode.string))
    use explanation_summary <- decode.field(10, decode.optional(decode.string))
    use top_item_priority <- decode.field(11, decode.optional(decode.float))
    decode.success(QueueRow(
      evaluation_id:,
      organization_name:,
      base_url:,
      priority:,
      priority_summary:,
      aging_deadline_at:,
      last_prioritized_at:,
      updated_at:,
      event:,
      top_url:,
      explanation_summary:,
      top_item_priority:,
    ))
  }

  "select
  eq.evaluation_id::text as evaluation_id,
  e.organization_name,
  e.base_url,
  eq.priority,
  eq.priority_summary,
  eq.aging_deadline_at,
  eq.last_prioritized_at,
  eq.updated_at,
  mc.event,
  tp.url as top_url,
  top_item.explanation_summary,
  top_item.top_item_priority
from
  evaluation_queue eq
inner join evaluation e
  on e.id = eq.evaluation_id
left join monitored_change mc
  on mc.id = eq.top_monitored_change_id
left join tracked_path tp
  on tp.id = mc.tracked_path_id
left join lateral (
  select
    ip.priority as top_item_priority,
    pe.summary as explanation_summary
  from
    item_priority ip
  left join priority_explanation pe
    on pe.item_priority_id = ip.id
  where
    ip.monitored_change_id = mc.id
  order by
    ip.priority desc,
    ip.created_at desc
  limit 1
) as top_item
  on true
left join lease l
  on l.evaluation_id = eq.evaluation_id
  and l.released_at is null
  and l.expires_at > timezone('utc', now())
where
  e.is_active
  and eq.priority is not null
  and l.id is null
order by
  eq.priority desc nulls last,
  coalesce(eq.aging_deadline_at, eq.updated_at) asc,
  eq.updated_at asc
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `release` query
/// defined in `./src/server/inbox/sql/release.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReleaseRow {
  ReleaseRow(
    lease_id: String,
    evaluation_id: String,
    claimed_by: String,
    release_reason: Option(String),
  )
}

/// Runs the `release` query
/// defined in `./src/server/inbox/sql/release.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn release(
  db: pog.Connection,
) -> Result(pog.Returned(ReleaseRow), pog.QueryError) {
  let decoder = {
    use lease_id <- decode.field(0, decode.string)
    use evaluation_id <- decode.field(1, decode.string)
    use claimed_by <- decode.field(2, decode.string)
    use release_reason <- decode.field(3, decode.optional(decode.string))
    decode.success(ReleaseRow(
      lease_id:,
      evaluation_id:,
      claimed_by:,
      release_reason:,
    ))
  }

  "update
  lease
set
  released_at = timezone('utc', now()),
  release_reason = 'expired'
where
  released_at is null
  and expires_at <= timezone('utc', now())
returning
  id::text as lease_id,
  evaluation_id::text as evaluation_id,
  claimed_by,
  release_reason
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Enums -------------------------------------------------------------------

/// Corresponds to the Postgres `monitored_change_event` enum.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MonitoredChangeEvent {
  TopologyChanged
  PathRemoved
  PathDiscovered
  PageChanged
}

fn monitored_change_event_decoder() -> decode.Decoder(MonitoredChangeEvent) {
  use monitored_change_event <- decode.then(decode.string)
  case monitored_change_event {
    "topology_changed" -> decode.success(TopologyChanged)
    "path_removed" -> decode.success(PathRemoved)
    "path_discovered" -> decode.success(PathDiscovered)
    "page_changed" -> decode.success(PageChanged)
    _ -> decode.failure(TopologyChanged, "MonitoredChangeEvent")
  }
}
