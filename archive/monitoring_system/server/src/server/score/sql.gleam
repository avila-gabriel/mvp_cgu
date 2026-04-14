//// This module contains the code to run the sql queries defined in
//// `./src/server/score/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option}
import pog
import youid/uuid.{type Uuid}

/// A row you get from running the `candidate` query
/// defined in `./src/server/score/sql/candidate.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CandidateRow {
  CandidateRow(
    change_id: String,
    evaluation_id: String,
    tracked_path_id: String,
    event: MonitoredChangeEvent,
    change_summary: Option(String),
    has_baseline: Bool,
    normalized_diff: String,
    path: String,
    visible_text: Option(String),
    topology_summary: Option(String),
  )
}

/// Runs the `candidate` query
/// defined in `./src/server/score/sql/candidate.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn candidate(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(CandidateRow), pog.QueryError) {
  let decoder = {
    use change_id <- decode.field(0, decode.string)
    use evaluation_id <- decode.field(1, decode.string)
    use tracked_path_id <- decode.field(2, decode.string)
    use event <- decode.field(3, monitored_change_event_decoder())
    use change_summary <- decode.field(4, decode.optional(decode.string))
    use has_baseline <- decode.field(5, decode.bool)
    use normalized_diff <- decode.field(6, decode.string)
    use path <- decode.field(7, decode.string)
    use visible_text <- decode.field(8, decode.optional(decode.string))
    use topology_summary <- decode.field(9, decode.optional(decode.string))
    decode.success(CandidateRow(
      change_id:,
      evaluation_id:,
      tracked_path_id:,
      event:,
      change_summary:,
      has_baseline:,
      normalized_diff:,
      path:,
      visible_text:,
      topology_summary:,
    ))
  }

  "select
  monitored_change.id::text as change_id,
  monitored_change.evaluation_id::text as evaluation_id,
  monitored_change.tracked_path_id::text as tracked_path_id,
  monitored_change.event,
  monitored_change.summary as change_summary,
  monitored_change.previous_snapshot_id is not null as has_baseline,
  monitored_change.normalized_diff,
  tracked_path.path,
  page_snapshot.visible_text,
  page_snapshot.topology_summary
from
  monitored_change
join
  tracked_path
    on tracked_path.id = monitored_change.tracked_path_id
join
  page_snapshot
    on page_snapshot.id = monitored_change.current_snapshot_id
where
  monitored_change.id = $1
  and monitored_change.status = 'pending';
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `due` query
/// defined in `./src/server/score/sql/due.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type DueRow {
  DueRow(change_id: String)
}

/// Runs the `due` query
/// defined in `./src/server/score/sql/due.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn due(db: pog.Connection) -> Result(pog.Returned(DueRow), pog.QueryError) {
  let decoder = {
    use change_id <- decode.field(0, decode.string)
    decode.success(DueRow(change_id:))
  }

  "select
  monitored_change.id::text as change_id
from
  monitored_change
where
  monitored_change.status = 'pending'
  and not exists (
    select
      1
    from
      m25.job
    where
      m25.job.unique_key = 'score:' || monitored_change.id::text
      and m25.job.status not in ('failed', 'cancelled')
  )
order by
  monitored_change.detected_at asc;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `explanation` query
/// defined in `./src/server/score/sql/explanation.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn explanation(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: Json,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into priority_explanation (
  item_priority_id,
  summary,
  detail
)
values (
  $1,
  $2,
  $3
)
on conflict (item_priority_id)
do update
set
  summary = excluded.summary,
  detail = excluded.detail;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(json.to_string(arg_3)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `item` query
/// defined in `./src/server/score/sql/item.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ItemRow {
  ItemRow(
    item_id: String,
    name: String,
    exact_url: Option(String),
    justification: Option(String),
    observed_evidence: Option(String),
    note: Option(String),
  )
}

/// Runs the `item` query
/// defined in `./src/server/score/sql/item.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn item(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(ItemRow), pog.QueryError) {
  let decoder = {
    use item_id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use exact_url <- decode.field(2, decode.optional(decode.string))
    use justification <- decode.field(3, decode.optional(decode.string))
    use observed_evidence <- decode.field(4, decode.optional(decode.string))
    use note <- decode.field(5, decode.optional(decode.string))
    decode.success(ItemRow(
      item_id:,
      name:,
      exact_url:,
      justification:,
      observed_evidence:,
      note:,
    ))
  }

  "select
  evaluation_item.id::text as item_id,
  evaluation_item.name,
  evaluation_item.exact_url,
  evaluation_item.justification,
  evaluation_item.observed_evidence,
  evaluation_item.note
from
  evaluation_item
where
  evaluation_item.evaluation_id = $1
  and evaluation_item.status <> 'fully_complies'
order by
  evaluation_item.inserted_at asc;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `queue` query
/// defined in `./src/server/score/sql/queue.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn queue(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
  arg_3: Float,
  arg_4: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into evaluation_queue (
  evaluation_id,
  top_monitored_change_id,
  priority,
  priority_summary,
  last_prioritized_at
)
values (
  $1,
  $2,
  $3,
  $4,
  timezone('utc', now())
)
on conflict (evaluation_id)
do update
set
  top_monitored_change_id = excluded.top_monitored_change_id,
  priority = excluded.priority,
  priority_summary = excluded.priority_summary,
  last_prioritized_at = excluded.last_prioritized_at;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.float(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `score` query
/// defined in `./src/server/score/sql/score.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ScoreRow {
  ScoreRow(item_priority_id: String)
}

/// Runs the `score` query
/// defined in `./src/server/score/sql/score.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn score(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
  arg_3: PriorityMode,
  arg_4: String,
  arg_5: Float,
) -> Result(pog.Returned(ScoreRow), pog.QueryError) {
  let decoder = {
    use item_priority_id <- decode.field(0, decode.string)
    decode.success(ScoreRow(item_priority_id:))
  }

  "insert into item_priority (
  monitored_change_id,
  evaluation_item_id,
  priority_mode,
  evaluator_name,
  priority
)
values (
  $1,
  $2,
  $3,
  $4,
  $5
)
on conflict (monitored_change_id, evaluation_item_id)
do update
set
  priority_mode = excluded.priority_mode,
  evaluator_name = excluded.evaluator_name,
  priority = excluded.priority
returning
  id::text as item_priority_id;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(priority_mode_encoder(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.float(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `status` query
/// defined in `./src/server/score/sql/status.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn status(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: MonitoredChangeStatus,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "update monitored_change
set
  status = $2
where
  id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(monitored_change_status_encoder(arg_2))
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

/// Corresponds to the Postgres `monitored_change_status` enum.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MonitoredChangeStatus {
  Dismissed
  Prioritized
  Pending
}

fn monitored_change_status_encoder(monitored_change_status) -> pog.Value {
  case monitored_change_status {
    Dismissed -> "dismissed"
    Prioritized -> "prioritized"
    Pending -> "pending"
  }
  |> pog.text
}

/// Corresponds to the Postgres `priority_mode` enum.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PriorityMode {
  Discovery
  Comparison
}

fn priority_mode_encoder(priority_mode) -> pog.Value {
  case priority_mode {
    Discovery -> "discovery"
    Comparison -> "comparison"
  }
  |> pog.text
}
