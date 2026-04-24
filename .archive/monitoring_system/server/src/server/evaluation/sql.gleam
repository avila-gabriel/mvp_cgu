//// This module contains the code to run the sql queries defined in
//// `./src/server/evaluation/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog
import youid/uuid.{type Uuid}

/// A row you get from running the `evaluation` query
/// defined in `./src/server/evaluation/sql/evaluation.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type EvaluationRow {
  EvaluationRow(
    evaluation_id: String,
    organization_name: String,
    base_url: String,
    extension_version: String,
    evaluated_at: Timestamp,
    evaluator_name: String,
    kind: EvaluationKind,
    evaluation_note: Option(String),
    source_payload: String,
    is_active: Bool,
  )
}

/// Runs the `evaluation` query
/// defined in `./src/server/evaluation/sql/evaluation.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn evaluation(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: Timestamp,
  arg_5: String,
  arg_6: EvaluationKind,
  arg_7: String,
  arg_8: Json,
) -> Result(pog.Returned(EvaluationRow), pog.QueryError) {
  let decoder = {
    use evaluation_id <- decode.field(0, decode.string)
    use organization_name <- decode.field(1, decode.string)
    use base_url <- decode.field(2, decode.string)
    use extension_version <- decode.field(3, decode.string)
    use evaluated_at <- decode.field(4, pog.timestamp_decoder())
    use evaluator_name <- decode.field(5, decode.string)
    use kind <- decode.field(6, evaluation_kind_decoder())
    use evaluation_note <- decode.field(7, decode.optional(decode.string))
    use source_payload <- decode.field(8, decode.string)
    use is_active <- decode.field(9, decode.bool)
    decode.success(EvaluationRow(
      evaluation_id:,
      organization_name:,
      base_url:,
      extension_version:,
      evaluated_at:,
      evaluator_name:,
      kind:,
      evaluation_note:,
      source_payload:,
      is_active:,
    ))
  }

  "insert into evaluation (
  organization_name,
  base_url,
  extension_version,
  evaluated_at,
  evaluator_name,
  kind,
  evaluation_note,
  source_payload
)
values (
  $1,
  $2,
  $3,
  $4::timestamp,
  $5,
  $6,
  $7,
  $8::jsonb
)
returning
  id::text as evaluation_id,
  organization_name,
  base_url,
  extension_version,
  evaluated_at,
  evaluator_name,
  kind,
  evaluation_note,
  source_payload,
  is_active
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.timestamp(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(evaluation_kind_encoder(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.text(json.to_string(arg_8)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `item` query
/// defined in `./src/server/evaluation/sql/item.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ItemRow {
  ItemRow(
    evaluation_item_id: String,
    evaluation_id: String,
    external_id: String,
    name: String,
    status: EvaluationItemStatus,
    exact_url: Option(String),
    justification: Option(String),
    observed_evidence: Option(String),
    note: Option(String),
  )
}

/// Runs the `item` query
/// defined in `./src/server/evaluation/sql/item.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn item(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: String,
  arg_4: EvaluationItemStatus,
  arg_5: String,
  arg_6: String,
  arg_7: String,
  arg_8: String,
) -> Result(pog.Returned(ItemRow), pog.QueryError) {
  let decoder = {
    use evaluation_item_id <- decode.field(0, decode.string)
    use evaluation_id <- decode.field(1, decode.string)
    use external_id <- decode.field(2, decode.string)
    use name <- decode.field(3, decode.string)
    use status <- decode.field(4, evaluation_item_status_decoder())
    use exact_url <- decode.field(5, decode.optional(decode.string))
    use justification <- decode.field(6, decode.optional(decode.string))
    use observed_evidence <- decode.field(7, decode.optional(decode.string))
    use note <- decode.field(8, decode.optional(decode.string))
    decode.success(ItemRow(
      evaluation_item_id:,
      evaluation_id:,
      external_id:,
      name:,
      status:,
      exact_url:,
      justification:,
      observed_evidence:,
      note:,
    ))
  }

  "insert into evaluation_item (
  evaluation_id,
  external_id,
  name,
  status,
  exact_url,
  justification,
  observed_evidence,
  note
)
values (
  $1::uuid,
  $2,
  $3,
  $4,
  $5,
  $6,
  $7,
  $8
)
returning
  id::text as evaluation_item_id,
  evaluation_id::text as evaluation_id,
  external_id,
  name,
  status,
  exact_url,
  justification,
  observed_evidence,
  note
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(evaluation_item_status_encoder(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.text(arg_8))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `monitor` query
/// defined in `./src/server/evaluation/sql/monitor.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MonitorRow {
  MonitorRow(
    tracked_url_id: String,
    evaluation_id: String,
    evaluation_item_id: String,
    url: String,
    non_compliance_reason: Option(String),
    relevant_evidence: Option(String),
    last_evaluated_at: Option(Timestamp),
    initial_priority: PriorityLevel,
    is_active: Bool,
  )
}

/// Runs the `monitor` query
/// defined in `./src/server/evaluation/sql/monitor.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn monitor(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: Timestamp,
  arg_7: PriorityLevel,
) -> Result(pog.Returned(MonitorRow), pog.QueryError) {
  let decoder = {
    use tracked_url_id <- decode.field(0, decode.string)
    use evaluation_id <- decode.field(1, decode.string)
    use evaluation_item_id <- decode.field(2, decode.string)
    use url <- decode.field(3, decode.string)
    use non_compliance_reason <- decode.field(4, decode.optional(decode.string))
    use relevant_evidence <- decode.field(5, decode.optional(decode.string))
    use last_evaluated_at <- decode.field(
      6,
      decode.optional(pog.timestamp_decoder()),
    )
    use initial_priority <- decode.field(7, priority_level_decoder())
    use is_active <- decode.field(8, decode.bool)
    decode.success(MonitorRow(
      tracked_url_id:,
      evaluation_id:,
      evaluation_item_id:,
      url:,
      non_compliance_reason:,
      relevant_evidence:,
      last_evaluated_at:,
      initial_priority:,
      is_active:,
    ))
  }

  "insert into tracked_url (
  evaluation_id,
  evaluation_item_id,
  url,
  non_compliance_reason,
  relevant_evidence,
  last_evaluated_at,
  initial_priority
)
values (
  $1::uuid,
  $2::uuid,
  $3,
  $4,
  $5,
  $6::timestamp,
  $7
)
returning
  id::text as tracked_url_id,
  evaluation_id::text as evaluation_id,
  evaluation_item_id::text as evaluation_item_id,
  url,
  non_compliance_reason,
  relevant_evidence,
  last_evaluated_at,
  initial_priority,
  is_active
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.timestamp(arg_6))
  |> pog.parameter(priority_level_encoder(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `queue` query
/// defined in `./src/server/evaluation/sql/queue.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type QueueRow {
  QueueRow(
    evaluation_id: String,
    priority: Option(Float),
    priority_summary: Option(String),
  )
}

/// Runs the `queue` query
/// defined in `./src/server/evaluation/sql/queue.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn queue(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(QueueRow), pog.QueryError) {
  let decoder = {
    use evaluation_id <- decode.field(0, decode.string)
    use priority <- decode.field(1, decode.optional(decode.float))
    use priority_summary <- decode.field(2, decode.optional(decode.string))
    decode.success(QueueRow(evaluation_id:, priority:, priority_summary:))
  }

  "insert into evaluation_queue (evaluation_id)
values ($1::uuid)
on conflict (evaluation_id) do nothing
returning
  evaluation_id::text as evaluation_id,
  priority,
  priority_summary
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Enums -------------------------------------------------------------------

/// Corresponds to the Postgres `evaluation_item_status` enum.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type EvaluationItemStatus {
  NotVerified
  DoesNotComply
  PartiallyComplies
  FullyComplies
}

fn evaluation_item_status_decoder() -> decode.Decoder(EvaluationItemStatus) {
  use evaluation_item_status <- decode.then(decode.string)
  case evaluation_item_status {
    "not_verified" -> decode.success(NotVerified)
    "does_not_comply" -> decode.success(DoesNotComply)
    "partially_complies" -> decode.success(PartiallyComplies)
    "fully_complies" -> decode.success(FullyComplies)
    _ -> decode.failure(NotVerified, "EvaluationItemStatus")
  }
}

fn evaluation_item_status_encoder(evaluation_item_status) -> pog.Value {
  case evaluation_item_status {
    NotVerified -> "not_verified"
    DoesNotComply -> "does_not_comply"
    PartiallyComplies -> "partially_complies"
    FullyComplies -> "fully_complies"
  }
  |> pog.text
}

/// Corresponds to the Postgres `evaluation_kind` enum.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type EvaluationKind {
  Reevaluation
  Initial
}

fn evaluation_kind_decoder() -> decode.Decoder(EvaluationKind) {
  use evaluation_kind <- decode.then(decode.string)
  case evaluation_kind {
    "reevaluation" -> decode.success(Reevaluation)
    "initial" -> decode.success(Initial)
    _ -> decode.failure(Reevaluation, "EvaluationKind")
  }
}

fn evaluation_kind_encoder(evaluation_kind) -> pog.Value {
  case evaluation_kind {
    Reevaluation -> "reevaluation"
    Initial -> "initial"
  }
  |> pog.text
}

/// Corresponds to the Postgres `priority_level` enum.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PriorityLevel {
  High
  Medium
  Low
}

fn priority_level_decoder() -> decode.Decoder(PriorityLevel) {
  use priority_level <- decode.then(decode.string)
  case priority_level {
    "high" -> decode.success(High)
    "medium" -> decode.success(Medium)
    "low" -> decode.success(Low)
    _ -> decode.failure(High, "PriorityLevel")
  }
}

fn priority_level_encoder(priority_level) -> pog.Value {
  case priority_level {
    High -> "high"
    Medium -> "medium"
    Low -> "low"
  }
  |> pog.text
}
