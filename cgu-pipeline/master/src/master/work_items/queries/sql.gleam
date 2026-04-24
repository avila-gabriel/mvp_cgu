//// This module contains the code to run the sql queries defined in
//// `./src/master/work_items/queries/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import pog
import youid/uuid.{type Uuid}

/// A row you get from running the `active_workers` query
/// defined in `./src/master/work_items/queries/sql/active_workers.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ActiveWorkersRow {
  ActiveWorkersRow(worker_id: String, capacity: Int)
}

/// Runs the `active_workers` query
/// defined in `./src/master/work_items/queries/sql/active_workers.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn active_workers(
  db: pog.Connection,
  arg_1: Float,
) -> Result(pog.Returned(ActiveWorkersRow), pog.QueryError) {
  let decoder = {
    use worker_id <- decode.field(0, decode.string)
    use capacity <- decode.field(1, decode.int)
    decode.success(ActiveWorkersRow(worker_id:, capacity:))
  }

  "select
  worker_id,
  capacity
from worker_registry
where last_seen_at >= timezone('utc', now()) - ($1 * interval '1 second')
order by worker_id asc
"
  |> pog.query
  |> pog.parameter(pog.float(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `artifact_body` query
/// defined in `./src/master/work_items/queries/sql/artifact_body.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ArtifactBodyRow {
  ArtifactBodyRow(storage_url: String)
}

/// Runs the `artifact_body` query
/// defined in `./src/master/work_items/queries/sql/artifact_body.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn artifact_body(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(ArtifactBodyRow), pog.QueryError) {
  let decoder = {
    use storage_url <- decode.field(0, decode.string)
    decode.success(ArtifactBodyRow(storage_url:))
  }

  "select
  storage_url
from artifact
where id = $1
  and body_size_bytes > 0
  and storage_content_encoding = 'br'
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `artifact_content_type_counts` query
/// defined in `./src/master/work_items/queries/sql/artifact_content_type_counts.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ArtifactContentTypeCountsRow {
  ArtifactContentTypeCountsRow(label: String, count: Int)
}

/// Runs the `artifact_content_type_counts` query
/// defined in `./src/master/work_items/queries/sql/artifact_content_type_counts.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn artifact_content_type_counts(
  db: pog.Connection,
) -> Result(pog.Returned(ArtifactContentTypeCountsRow), pog.QueryError) {
  let decoder = {
    use label <- decode.field(0, decode.string)
    use count <- decode.field(1, decode.int)
    decode.success(ArtifactContentTypeCountsRow(label:, count:))
  }

  "select
  coalesce(nullif(split_part(lower(content_type), ';', 1), ''), 'missing') as label,
  count(*)::int as count
from artifact
group by coalesce(nullif(split_part(lower(content_type), ';', 1), ''), 'missing')
order by count desc, label asc
limit 12
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `artifact_status_code_counts` query
/// defined in `./src/master/work_items/queries/sql/artifact_status_code_counts.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ArtifactStatusCodeCountsRow {
  ArtifactStatusCodeCountsRow(label: String, count: Int)
}

/// Runs the `artifact_status_code_counts` query
/// defined in `./src/master/work_items/queries/sql/artifact_status_code_counts.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn artifact_status_code_counts(
  db: pog.Connection,
) -> Result(pog.Returned(ArtifactStatusCodeCountsRow), pog.QueryError) {
  let decoder = {
    use label <- decode.field(0, decode.string)
    use count <- decode.field(1, decode.int)
    decode.success(ArtifactStatusCodeCountsRow(label:, count:))
  }

  "select
  coalesce(status_code::text, 'missing') as label,
  count(*)::int as count
from artifact
group by coalesce(status_code::text, 'missing')
order by count desc, label asc
limit 12
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `claim` query
/// defined in `./src/master/work_items/queries/sql/claim.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ClaimRow {
  ClaimRow(
    lease_id: String,
    lease_expires_at: String,
    work_item_id: String,
    subject_id: String,
    kind: String,
    url: String,
    archive_date: Option(String),
    metadata_json: String,
    attempts: Int,
    max_attempts: Int,
  )
}

/// Runs the `claim` query
/// defined in `./src/master/work_items/queries/sql/claim.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn claim(
  db: pog.Connection,
  arg_1: String,
  arg_2: Float,
) -> Result(pog.Returned(ClaimRow), pog.QueryError) {
  let decoder = {
    use lease_id <- decode.field(0, decode.string)
    use lease_expires_at <- decode.field(1, decode.string)
    use work_item_id <- decode.field(2, decode.string)
    use subject_id <- decode.field(3, decode.string)
    use kind <- decode.field(4, decode.string)
    use url <- decode.field(5, decode.string)
    use archive_date <- decode.field(6, decode.optional(decode.string))
    use metadata_json <- decode.field(7, decode.string)
    use attempts <- decode.field(8, decode.int)
    use max_attempts <- decode.field(9, decode.int)
    decode.success(ClaimRow(
      lease_id:,
      lease_expires_at:,
      work_item_id:,
      subject_id:,
      kind:,
      url:,
      archive_date:,
      metadata_json:,
      attempts:,
      max_attempts:,
    ))
  }

  "with candidate as (
  select
    j.id,
    j.fetch_host
  from work_item j
  inner join host_rate_limit h
    on h.host = j.fetch_host
  left join work_lease l
    on l.work_item_id = j.id
    and l.released_at is null
    and l.expires_at > timezone('utc', now())
  where
    l.id is null
    and j.status in ('pending', 'running')
    and j.available_at <= timezone('utc', now())
    and j.attempts < j.max_attempts
    and h.next_available_at <= timezone('utc', now())
  order by
    j.priority desc,
    j.available_at asc,
    j.inserted_at asc
  for update of j, h skip locked
  limit 1
),
reserved_host as (
  update host_rate_limit h
  set
    next_available_at = timezone('utc', now()) + (h.delay_seconds * interval '1 second'),
    updated_at = timezone('utc', now())
  from candidate
  where h.host = candidate.fetch_host
  returning h.host
),
updated_job as (
  update work_item j
  set
    status = 'running',
    attempts = j.attempts + 1,
    updated_at = timezone('utc', now())
  from candidate
  inner join reserved_host
    on reserved_host.host = candidate.fetch_host
  where j.id = candidate.id
  returning
    j.id,
    j.subject_id,
    j.kind,
    j.url,
    j.archive_date,
    j.metadata::text as metadata_json,
    j.attempts,
    j.max_attempts
),
inserted_lease as (
  insert into work_lease (
    work_item_id,
    worker_id,
    expires_at
  )
  select
    id,
    $1,
    timezone('utc', now()) + ($2 * interval '1 second')
  from updated_job
  returning
    id,
    work_item_id,
    expires_at
)
select
  inserted_lease.id::text as lease_id,
  inserted_lease.expires_at::text as lease_expires_at,
  updated_job.id::text as work_item_id,
  updated_job.subject_id,
  updated_job.kind::text as kind,
  updated_job.url,
  updated_job.archive_date,
  updated_job.metadata_json,
  updated_job.attempts,
  updated_job.max_attempts
from inserted_lease
inner join updated_job
  on updated_job.id = inserted_lease.work_item_id
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.float(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `clear_inactive_worker_assignments` query
/// defined in `./src/master/work_items/queries/sql/clear_inactive_worker_assignments.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ClearInactiveWorkerAssignmentsRow {
  ClearInactiveWorkerAssignmentsRow(worker_id: String)
}

/// Runs the `clear_inactive_worker_assignments` query
/// defined in `./src/master/work_items/queries/sql/clear_inactive_worker_assignments.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn clear_inactive_worker_assignments(
  db: pog.Connection,
  arg_1: Float,
) -> Result(pog.Returned(ClearInactiveWorkerAssignmentsRow), pog.QueryError) {
  let decoder = {
    use worker_id <- decode.field(0, decode.string)
    decode.success(ClearInactiveWorkerAssignmentsRow(worker_id:))
  }

  "update worker_registry
set assigned_slots = 0
where last_seen_at < timezone('utc', now()) - ($1 * interval '1 second')
returning worker_id
"
  |> pog.query
  |> pog.parameter(pog.float(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `complete` query
/// defined in `./src/master/work_items/queries/sql/complete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CompleteRow {
  CompleteRow(work_item_id: String, artifact_id: String, status: String)
}

/// Runs the `complete` query
/// defined in `./src/master/work_items/queries/sql/complete.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn complete(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: Int,
  arg_6: String,
  arg_7: String,
  arg_8: Int,
  arg_9: String,
  arg_10: String,
  arg_11: Int,
  arg_12: String,
  arg_13: String,
) -> Result(pog.Returned(CompleteRow), pog.QueryError) {
  let decoder = {
    use work_item_id <- decode.field(0, decode.string)
    use artifact_id <- decode.field(1, decode.string)
    use status <- decode.field(2, decode.string)
    decode.success(CompleteRow(work_item_id:, artifact_id:, status:))
  }

  "with existing_artifact as (
  select
    a.work_item_id,
    a.id as artifact_id
  from artifact a
  inner join work_lease l on l.id = a.lease_id
  where
    a.work_item_id = $1::text::uuid
    and a.lease_id = $2::text::uuid
    and l.worker_id = $3
),
active_lease as (
  select
    id,
    work_item_id
  from work_lease
  where
    work_item_id = $1::text::uuid
    and id = $2::text::uuid
    and worker_id = $3
    and released_at is null
    and expires_at > timezone('utc', now())
    and not exists (select 1 from existing_artifact)
),
released_lease as (
  update work_lease l
  set
    released_at = timezone('utc', now()),
    release_reason = 'completed'
  from active_lease
  where l.id = active_lease.id
  returning l.work_item_id
),
updated_job as (
  update work_item j
  set
    status = 'succeeded',
    last_error = null,
    updated_at = timezone('utc', now())
  from active_lease
  where j.id = active_lease.work_item_id
  returning
    j.id,
    j.subject_id,
    j.subject_item_id,
    j.kind,
    j.url,
    j.fetch_host
),
rate_limited_host as (
  update host_rate_limit h
  set
    next_available_at = greatest(
      h.next_available_at,
      timezone('utc', now()) + (60.0 * interval '1 second')
    ),
    delay_seconds = greatest(h.delay_seconds, 60.0),
    last_status_code = $5,
    updated_at = timezone('utc', now())
  from updated_job
  where
    h.host = updated_job.fetch_host
    and $5 = 429
  returning h.host
),
artifact_payload as (
  select gen_random_uuid() as artifact_id
),
inserted_artifact as (
  insert into artifact (
    id,
    work_item_id,
    lease_id,
    subject_id,
    subject_item_id,
    kind,
    source_url,
    fetched_url,
    status_code,
    content_type,
    body_sha256,
    body_size_bytes,
    storage_url,
    storage_sha256,
    storage_size_bytes,
    storage_content_encoding,
    metadata
  )
  select
    artifact_payload.artifact_id,
    id,
    $2::text::uuid,
    subject_id,
    subject_item_id,
    kind,
    url,
    $4,
    $5,
    $6,
    $7,
    $8,
    $9,
    $10,
    $11,
    $12,
    $13::text::jsonb
  from updated_job
  cross join artifact_payload
  returning
    id,
    work_item_id
)
select
  inserted_artifact.work_item_id::text as work_item_id,
  inserted_artifact.id::text as artifact_id,
  'succeeded' as status
from inserted_artifact
union all
select
  existing_artifact.work_item_id::text as work_item_id,
  existing_artifact.artifact_id::text as artifact_id,
  'succeeded' as status
from existing_artifact
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.int(arg_8))
  |> pog.parameter(pog.text(arg_9))
  |> pog.parameter(pog.text(arg_10))
  |> pog.parameter(pog.int(arg_11))
  |> pog.parameter(pog.text(arg_12))
  |> pog.parameter(pog.text(arg_13))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `complete_artifact_text` query
/// defined in `./src/master/work_items/queries/sql/complete_artifact_text.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CompleteArtifactTextRow {
  CompleteArtifactTextRow(artifact_id: String)
}

/// Runs the `complete_artifact_text` query
/// defined in `./src/master/work_items/queries/sql/complete_artifact_text.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn complete_artifact_text(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: String,
  arg_8: String,
  arg_9: String,
  arg_10: String,
  arg_11: Int,
  arg_12: Int,
  arg_13: String,
  arg_14: String,
  arg_15: String,
  arg_16: String,
  arg_17: String,
) -> Result(pog.Returned(CompleteArtifactTextRow), pog.QueryError) {
  let decoder = {
    use artifact_id <- decode.field(0, decode.string)
    decode.success(CompleteArtifactTextRow(artifact_id:))
  }

  "update artifact_text
set
  extraction_status = $2,
  title = $3,
  headings = $4,
  lists = $5,
  breadcrumbs = $6,
  language = $7,
  raw_text = $8,
  cleaned_text = $9,
  cleaned_html = $10,
  char_count = $11,
  cleaned_char_count = $12,
  content_type = $13,
  extractor = $14,
  extractor_version = $15,
  error = $16,
  worker_id = null,
  lease_expires_at = null,
  updated_at = timezone('utc', now())
where artifact_id = $1
  and extraction_status = 'running'
  and worker_id = $17
returning artifact_id::text
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.text(arg_8))
  |> pog.parameter(pog.text(arg_9))
  |> pog.parameter(pog.text(arg_10))
  |> pog.parameter(pog.int(arg_11))
  |> pog.parameter(pog.int(arg_12))
  |> pog.parameter(pog.text(arg_13))
  |> pog.parameter(pog.text(arg_14))
  |> pog.parameter(pog.text(arg_15))
  |> pog.parameter(pog.text(arg_16))
  |> pog.parameter(pog.text(arg_17))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `complete_without_content_type` query
/// defined in `./src/master/work_items/queries/sql/complete_without_content_type.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CompleteWithoutContentTypeRow {
  CompleteWithoutContentTypeRow(
    work_item_id: String,
    artifact_id: String,
    status: String,
  )
}

/// Runs the `complete_without_content_type` query
/// defined in `./src/master/work_items/queries/sql/complete_without_content_type.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn complete_without_content_type(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: Int,
  arg_6: String,
  arg_7: Int,
  arg_8: String,
  arg_9: String,
  arg_10: Int,
  arg_11: String,
  arg_12: String,
) -> Result(pog.Returned(CompleteWithoutContentTypeRow), pog.QueryError) {
  let decoder = {
    use work_item_id <- decode.field(0, decode.string)
    use artifact_id <- decode.field(1, decode.string)
    use status <- decode.field(2, decode.string)
    decode.success(CompleteWithoutContentTypeRow(
      work_item_id:,
      artifact_id:,
      status:,
    ))
  }

  "with existing_artifact as (
  select
    a.work_item_id,
    a.id as artifact_id
  from artifact a
  inner join work_lease l on l.id = a.lease_id
  where
    a.work_item_id = $1::text::uuid
    and a.lease_id = $2::text::uuid
    and l.worker_id = $3
),
active_lease as (
  select
    id,
    work_item_id
  from work_lease
  where
    work_item_id = $1::text::uuid
    and id = $2::text::uuid
    and worker_id = $3
    and released_at is null
    and expires_at > timezone('utc', now())
    and not exists (select 1 from existing_artifact)
),
released_lease as (
  update work_lease l
  set
    released_at = timezone('utc', now()),
    release_reason = 'completed'
  from active_lease
  where l.id = active_lease.id
  returning l.work_item_id
),
updated_job as (
  update work_item j
  set
    status = 'succeeded',
    last_error = null,
    updated_at = timezone('utc', now())
  from active_lease
  where j.id = active_lease.work_item_id
  returning
    j.id,
    j.subject_id,
    j.subject_item_id,
    j.kind,
    j.url,
    j.fetch_host
),
rate_limited_host as (
  update host_rate_limit h
  set
    next_available_at = greatest(
      h.next_available_at,
      timezone('utc', now()) + (60.0 * interval '1 second')
    ),
    delay_seconds = greatest(h.delay_seconds, 60.0),
    last_status_code = $5,
    updated_at = timezone('utc', now())
  from updated_job
  where
    h.host = updated_job.fetch_host
    and $5 = 429
  returning h.host
),
artifact_payload as (
  select gen_random_uuid() as artifact_id
),
inserted_artifact as (
  insert into artifact (
    id,
    work_item_id,
    lease_id,
    subject_id,
    subject_item_id,
    kind,
    source_url,
    fetched_url,
    status_code,
    content_type,
    body_sha256,
    body_size_bytes,
    storage_url,
    storage_sha256,
    storage_size_bytes,
    storage_content_encoding,
    metadata
  )
  select
    artifact_payload.artifact_id,
    id,
    $2::text::uuid,
    subject_id,
    subject_item_id,
    kind,
    url,
    $4,
    $5,
    null,
    $6,
    $7,
    $8,
    $9,
    $10,
    $11,
    $12::text::jsonb
  from updated_job
  cross join artifact_payload
  returning
    id,
    work_item_id
)
select
  inserted_artifact.work_item_id::text as work_item_id,
  inserted_artifact.id::text as artifact_id,
  'succeeded' as status
from inserted_artifact
union all
select
  existing_artifact.work_item_id::text as work_item_id,
  existing_artifact.artifact_id::text as artifact_id,
  'succeeded' as status
from existing_artifact
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.parameter(pog.text(arg_8))
  |> pog.parameter(pog.text(arg_9))
  |> pog.parameter(pog.int(arg_10))
  |> pog.parameter(pog.text(arg_11))
  |> pog.parameter(pog.text(arg_12))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `complete_without_response_details` query
/// defined in `./src/master/work_items/queries/sql/complete_without_response_details.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CompleteWithoutResponseDetailsRow {
  CompleteWithoutResponseDetailsRow(
    work_item_id: String,
    artifact_id: String,
    status: String,
  )
}

/// Runs the `complete_without_response_details` query
/// defined in `./src/master/work_items/queries/sql/complete_without_response_details.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn complete_without_response_details(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: Int,
  arg_7: String,
  arg_8: String,
  arg_9: Int,
  arg_10: String,
  arg_11: String,
) -> Result(pog.Returned(CompleteWithoutResponseDetailsRow), pog.QueryError) {
  let decoder = {
    use work_item_id <- decode.field(0, decode.string)
    use artifact_id <- decode.field(1, decode.string)
    use status <- decode.field(2, decode.string)
    decode.success(CompleteWithoutResponseDetailsRow(
      work_item_id:,
      artifact_id:,
      status:,
    ))
  }

  "with existing_artifact as (
  select
    a.work_item_id,
    a.id as artifact_id
  from artifact a
  inner join work_lease l on l.id = a.lease_id
  where
    a.work_item_id = $1::text::uuid
    and a.lease_id = $2::text::uuid
    and l.worker_id = $3
),
active_lease as (
  select
    id,
    work_item_id
  from work_lease
  where
    work_item_id = $1::text::uuid
    and id = $2::text::uuid
    and worker_id = $3
    and released_at is null
    and expires_at > timezone('utc', now())
    and not exists (select 1 from existing_artifact)
),
released_lease as (
  update work_lease l
  set
    released_at = timezone('utc', now()),
    release_reason = 'completed'
  from active_lease
  where l.id = active_lease.id
  returning l.work_item_id
),
updated_job as (
  update work_item j
  set
    status = 'succeeded',
    last_error = null,
    updated_at = timezone('utc', now())
  from active_lease
  where j.id = active_lease.work_item_id
  returning
    j.id,
    j.subject_id,
    j.subject_item_id,
    j.kind,
    j.url
),
artifact_payload as (
  select gen_random_uuid() as artifact_id
),
inserted_artifact as (
  insert into artifact (
    id,
    work_item_id,
    lease_id,
    subject_id,
    subject_item_id,
    kind,
    source_url,
    fetched_url,
    status_code,
    content_type,
    body_sha256,
    body_size_bytes,
    storage_url,
    storage_sha256,
    storage_size_bytes,
    storage_content_encoding,
    metadata
  )
  select
    artifact_payload.artifact_id,
    id,
    $2::text::uuid,
    subject_id,
    subject_item_id,
    kind,
    url,
    $4,
    null,
    null,
    $5,
    $6,
    $7,
    $8,
    $9,
    $10,
    $11::text::jsonb
  from updated_job
  cross join artifact_payload
  returning
    id,
    work_item_id
)
select
  inserted_artifact.work_item_id::text as work_item_id,
  inserted_artifact.id::text as artifact_id,
  'succeeded' as status
from inserted_artifact
union all
select
  existing_artifact.work_item_id::text as work_item_id,
  existing_artifact.artifact_id::text as artifact_id,
  'succeeded' as status
from existing_artifact
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.text(arg_8))
  |> pog.parameter(pog.int(arg_9))
  |> pog.parameter(pog.text(arg_10))
  |> pog.parameter(pog.text(arg_11))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `complete_without_status_code` query
/// defined in `./src/master/work_items/queries/sql/complete_without_status_code.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CompleteWithoutStatusCodeRow {
  CompleteWithoutStatusCodeRow(
    work_item_id: String,
    artifact_id: String,
    status: String,
  )
}

/// Runs the `complete_without_status_code` query
/// defined in `./src/master/work_items/queries/sql/complete_without_status_code.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn complete_without_status_code(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: Int,
  arg_8: String,
  arg_9: String,
  arg_10: Int,
  arg_11: String,
  arg_12: String,
) -> Result(pog.Returned(CompleteWithoutStatusCodeRow), pog.QueryError) {
  let decoder = {
    use work_item_id <- decode.field(0, decode.string)
    use artifact_id <- decode.field(1, decode.string)
    use status <- decode.field(2, decode.string)
    decode.success(CompleteWithoutStatusCodeRow(
      work_item_id:,
      artifact_id:,
      status:,
    ))
  }

  "with existing_artifact as (
  select
    a.work_item_id,
    a.id as artifact_id
  from artifact a
  inner join work_lease l on l.id = a.lease_id
  where
    a.work_item_id = $1::text::uuid
    and a.lease_id = $2::text::uuid
    and l.worker_id = $3
),
active_lease as (
  select
    id,
    work_item_id
  from work_lease
  where
    work_item_id = $1::text::uuid
    and id = $2::text::uuid
    and worker_id = $3
    and released_at is null
    and expires_at > timezone('utc', now())
    and not exists (select 1 from existing_artifact)
),
released_lease as (
  update work_lease l
  set
    released_at = timezone('utc', now()),
    release_reason = 'completed'
  from active_lease
  where l.id = active_lease.id
  returning l.work_item_id
),
updated_job as (
  update work_item j
  set
    status = 'succeeded',
    last_error = null,
    updated_at = timezone('utc', now())
  from active_lease
  where j.id = active_lease.work_item_id
  returning
    j.id,
    j.subject_id,
    j.subject_item_id,
    j.kind,
    j.url
),
artifact_payload as (
  select gen_random_uuid() as artifact_id
),
inserted_artifact as (
  insert into artifact (
    id,
    work_item_id,
    lease_id,
    subject_id,
    subject_item_id,
    kind,
    source_url,
    fetched_url,
    status_code,
    content_type,
    body_sha256,
    body_size_bytes,
    storage_url,
    storage_sha256,
    storage_size_bytes,
    storage_content_encoding,
    metadata
  )
  select
    artifact_payload.artifact_id,
    id,
    $2::text::uuid,
    subject_id,
    subject_item_id,
    kind,
    url,
    $4,
    null,
    $5,
    $6,
    $7,
    $8,
    $9,
    $10,
    $11,
    $12::text::jsonb
  from updated_job
  cross join artifact_payload
  returning
    id,
    work_item_id
)
select
  inserted_artifact.work_item_id::text as work_item_id,
  inserted_artifact.id::text as artifact_id,
  'succeeded' as status
from inserted_artifact
union all
select
  existing_artifact.work_item_id::text as work_item_id,
  existing_artifact.artifact_id::text as artifact_id,
  'succeeded' as status
from existing_artifact
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.parameter(pog.text(arg_8))
  |> pog.parameter(pog.text(arg_9))
  |> pog.parameter(pog.int(arg_10))
  |> pog.parameter(pog.text(arg_11))
  |> pog.parameter(pog.text(arg_12))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `completed_by_lease` query
/// defined in `./src/master/work_items/queries/sql/completed_by_lease.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CompletedByLeaseRow {
  CompletedByLeaseRow(work_item_id: String, artifact_id: String, status: String)
}

/// Runs the `completed_by_lease` query
/// defined in `./src/master/work_items/queries/sql/completed_by_lease.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn completed_by_lease(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
) -> Result(pog.Returned(CompletedByLeaseRow), pog.QueryError) {
  let decoder = {
    use work_item_id <- decode.field(0, decode.string)
    use artifact_id <- decode.field(1, decode.string)
    use status <- decode.field(2, decode.string)
    decode.success(CompletedByLeaseRow(work_item_id:, artifact_id:, status:))
  }

  "select
  a.work_item_id::text as work_item_id,
  a.id::text as artifact_id,
  'succeeded' as status
from artifact a
inner join work_lease l on l.id = a.lease_id
where
  a.work_item_id = $1::text::uuid
  and a.lease_id = $2::text::uuid
  and l.worker_id = $3
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `data_insights` query
/// defined in `./src/master/work_items/queries/sql/data_insights.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type DataInsightsRow {
  DataInsightsRow(
    subject_count: Int,
    subject_item_count: Int,
    fetched_subject_item_count: Int,
    not_fetched_subject_item_count: Int,
    work_item_count: Int,
    fetched_work_item_count: Int,
    not_fetched_work_item_count: Int,
    open_work_item_count: Int,
    failed_work_item_count: Int,
    artifact_count: Int,
    avg_body_size_bytes: Int,
    median_body_size_bytes: Int,
    p95_body_size_bytes: Int,
  )
}

/// Runs the `data_insights` query
/// defined in `./src/master/work_items/queries/sql/data_insights.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn data_insights(
  db: pog.Connection,
) -> Result(pog.Returned(DataInsightsRow), pog.QueryError) {
  let decoder = {
    use subject_count <- decode.field(0, decode.int)
    use subject_item_count <- decode.field(1, decode.int)
    use fetched_subject_item_count <- decode.field(2, decode.int)
    use not_fetched_subject_item_count <- decode.field(3, decode.int)
    use work_item_count <- decode.field(4, decode.int)
    use fetched_work_item_count <- decode.field(5, decode.int)
    use not_fetched_work_item_count <- decode.field(6, decode.int)
    use open_work_item_count <- decode.field(7, decode.int)
    use failed_work_item_count <- decode.field(8, decode.int)
    use artifact_count <- decode.field(9, decode.int)
    use avg_body_size_bytes <- decode.field(10, decode.int)
    use median_body_size_bytes <- decode.field(11, decode.int)
    use p95_body_size_bytes <- decode.field(12, decode.int)
    decode.success(DataInsightsRow(
      subject_count:,
      subject_item_count:,
      fetched_subject_item_count:,
      not_fetched_subject_item_count:,
      work_item_count:,
      fetched_work_item_count:,
      not_fetched_work_item_count:,
      open_work_item_count:,
      failed_work_item_count:,
      artifact_count:,
      avg_body_size_bytes:,
      median_body_size_bytes:,
      p95_body_size_bytes:,
    ))
  }

  "select
  (select count(*)::int from subject) as subject_count,
  (select count(*)::int from subject_item) as subject_item_count,
  (
    select count(distinct si.id)::int
    from subject_item si
    join work_item wi on wi.subject_item_id = si.id
    join artifact ar on ar.work_item_id = wi.id
  ) as fetched_subject_item_count,
  (
    select count(*)::int
    from subject_item si
    where not exists (
      select 1
      from work_item wi
      join artifact ar on ar.work_item_id = wi.id
      where wi.subject_item_id = si.id
    )
  ) as not_fetched_subject_item_count,
  count(distinct w.id)::int as work_item_count,
  count(distinct w.id) filter (where a.id is not null)::int as fetched_work_item_count,
  count(distinct w.id) filter (where a.id is null)::int as not_fetched_work_item_count,
  count(distinct w.id) filter (where w.status in ('pending', 'running'))::int as open_work_item_count,
  count(distinct w.id) filter (where w.status in ('failed', 'dead'))::int as failed_work_item_count,
  count(a.id)::int as artifact_count,
  coalesce(round(avg(a.body_size_bytes)), 0)::int as avg_body_size_bytes,
  coalesce(percentile_cont(0.5) within group (order by a.body_size_bytes), 0)::int as median_body_size_bytes,
  coalesce(percentile_cont(0.95) within group (order by a.body_size_bytes), 0)::int as p95_body_size_bytes
from work_item w
left join artifact a on a.work_item_id = w.id
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `enqueue_sta_item` query
/// defined in `./src/master/work_items/queries/sql/enqueue_sta_item.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type EnqueueStaItemRow {
  EnqueueStaItemRow(
    work_item_id: String,
    subject_id: String,
    kind: String,
    status: String,
  )
}

/// Runs the `enqueue_sta_item` query
/// defined in `./src/master/work_items/queries/sql/enqueue_sta_item.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn enqueue_sta_item(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: VerificationStatus,
  arg_5: Int,
  arg_6: String,
  arg_7: String,
  arg_8: String,
  arg_9: String,
  arg_10: String,
) -> Result(pog.Returned(EnqueueStaItemRow), pog.QueryError) {
  let decoder = {
    use work_item_id <- decode.field(0, decode.string)
    use subject_id <- decode.field(1, decode.string)
    use kind <- decode.field(2, decode.string)
    use status <- decode.field(3, decode.string)
    decode.success(EnqueueStaItemRow(work_item_id:, subject_id:, kind:, status:))
  }

  "with upserted_subject as (
  insert into subject (
    id
  )
  values (
    $1
  )
  on conflict (id) do update set
    id = excluded.id,
    updated_at = timezone('utc', now())
  returning
    id
),
upserted_item as (
  insert into subject_item (
    subject_id,
    source_key,
    url,
    verification_status,
    metadata
  )
  select
    id,
    $2,
    $3,
    $4::verification_status,
    $10::text::jsonb
  from upserted_subject
  on conflict (subject_id, source_key) do update set
    url = excluded.url,
    verification_status = excluded.verification_status,
    metadata = excluded.metadata,
    updated_at = timezone('utc', now())
  returning
    id,
    subject_id,
    url
),
upserted_host as (
  insert into host_rate_limit (host)
  values ($6)
  on conflict (host) do update set
    host = excluded.host
  returning host
),
current_work as (
  insert into work_item (
    subject_id,
    subject_item_id,
    kind,
    url,
    archive_date,
    fetch_host,
    priority,
    metadata
  )
  select
    subject_id,
    id,
    'snapshot.current',
    url,
    $7::text,
    $6,
    $5,
    jsonb_build_object(
      'source', 'sta',
      'role', 'evaluation',
      'target_date', $7::text
    )
  from upserted_item
  cross join upserted_host
  on conflict (subject_item_id, kind, archive_date) do update set
    subject_item_id = excluded.subject_item_id,
    url = excluded.url,
    archive_date = excluded.archive_date,
    fetch_host = excluded.fetch_host,
    priority = excluded.priority,
    metadata = excluded.metadata,
    updated_at = timezone('utc', now())
  returning
    id::text as work_item_id,
    subject_id,
    kind::text as kind,
    status::text as status
),
archive_work as (
  insert into work_item (
    subject_id,
    subject_item_id,
    kind,
    url,
    archive_date,
    fetch_host,
    priority,
    metadata
  )
  select
    subject_id,
    id,
    'snapshot.archive',
    url,
    $8::text,
    $6,
    $5,
    jsonb_build_object(
      'source', 'sta',
      'role', 'before_update',
      'target_dates', $9::text::jsonb
    )
  from upserted_item
  cross join upserted_host
  where $8::text <> ''
  on conflict (subject_item_id, kind, archive_date) do update set
    subject_item_id = excluded.subject_item_id,
    url = excluded.url,
    archive_date = excluded.archive_date,
    fetch_host = excluded.fetch_host,
    priority = excluded.priority,
    metadata = excluded.metadata,
    updated_at = timezone('utc', now())
  returning
    id::text as work_item_id,
    subject_id,
    kind::text as kind,
    status::text as status
)
select * from current_work
union all
select * from archive_work
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(verification_status_encoder(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.text(arg_8))
  |> pog.parameter(pog.text(arg_9))
  |> pog.parameter(pog.text(arg_10))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `expire_leases` query
/// defined in `./src/master/work_items/queries/sql/expire_leases.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ExpireLeasesRow {
  ExpireLeasesRow(lease_id: String)
}

/// Runs the `expire_leases` query
/// defined in `./src/master/work_items/queries/sql/expire_leases.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn expire_leases(
  db: pog.Connection,
) -> Result(pog.Returned(ExpireLeasesRow), pog.QueryError) {
  let decoder = {
    use lease_id <- decode.field(0, decode.string)
    decode.success(ExpireLeasesRow(lease_id:))
  }

  "update work_lease
set
  released_at = timezone('utc', now()),
  release_reason = 'expired'
where
  released_at is null
  and expires_at <= timezone('utc', now())
returning id::text as lease_id
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `fail` query
/// defined in `./src/master/work_items/queries/sql/fail.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FailRow {
  FailRow(
    work_item_id: String,
    status: String,
    attempts: Int,
    max_attempts: Int,
  )
}

/// Runs the `fail` query
/// defined in `./src/master/work_items/queries/sql/fail.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn fail(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: Bool,
  arg_6: Float,
) -> Result(pog.Returned(FailRow), pog.QueryError) {
  let decoder = {
    use work_item_id <- decode.field(0, decode.string)
    use status <- decode.field(1, decode.string)
    use attempts <- decode.field(2, decode.int)
    use max_attempts <- decode.field(3, decode.int)
    decode.success(FailRow(work_item_id:, status:, attempts:, max_attempts:))
  }

  "with active_lease as (
  select
    id,
    work_item_id
  from work_lease
  where
    work_item_id = $1::text::uuid
    and id = $2::text::uuid
    and worker_id = $3
    and released_at is null
    and expires_at > timezone('utc', now())
),
released_lease as (
  update work_lease l
  set
    released_at = timezone('utc', now()),
    release_reason = 'failed'
  from active_lease
  where l.id = active_lease.id
  returning l.work_item_id
),
updated_job as (
  update work_item j
  set
    status = case
      when $5::boolean and j.attempts < j.max_attempts then 'pending'::work_status
      when $5::boolean then 'dead'::work_status
      else 'failed'::work_status
    end,
    last_error = $4,
    available_at = case
      when $5::boolean and j.attempts < j.max_attempts
        then timezone('utc', now()) + ($6 * interval '1 second')
      else j.available_at
    end,
    updated_at = timezone('utc', now())
  from active_lease
  where j.id = active_lease.work_item_id
  returning
    j.id::text as work_item_id,
    j.fetch_host,
    j.status::text as status,
    j.attempts,
    j.max_attempts
),
retry_host_cooldown as (
  update host_rate_limit h
  set
    next_available_at = greatest(
      h.next_available_at,
      timezone('utc', now()) + ($6 * interval '1 second')
    ),
    updated_at = timezone('utc', now())
  from updated_job
  where
    h.host = updated_job.fetch_host
    and $5::boolean
  returning h.host
)
select
  work_item_id,
  status,
  attempts,
  max_attempts
from updated_job
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.bool(arg_5))
  |> pog.parameter(pog.float(arg_6))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list` query
/// defined in `./src/master/work_items/queries/sql/list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListRow {
  ListRow(
    total_count: Int,
    work_item_id: String,
    subject_id: String,
    kind: String,
    url: String,
    archive_date: Option(String),
    status: String,
    priority: Int,
    attempts: Int,
    max_attempts: Int,
    last_error: Option(String),
    available_at: String,
    inserted_at: String,
    updated_at: String,
  )
}

/// Runs the `list` query
/// defined in `./src/master/work_items/queries/sql/list.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ListRow), pog.QueryError) {
  let decoder = {
    use total_count <- decode.field(0, decode.int)
    use work_item_id <- decode.field(1, decode.string)
    use subject_id <- decode.field(2, decode.string)
    use kind <- decode.field(3, decode.string)
    use url <- decode.field(4, decode.string)
    use archive_date <- decode.field(5, decode.optional(decode.string))
    use status <- decode.field(6, decode.string)
    use priority <- decode.field(7, decode.int)
    use attempts <- decode.field(8, decode.int)
    use max_attempts <- decode.field(9, decode.int)
    use last_error <- decode.field(10, decode.optional(decode.string))
    use available_at <- decode.field(11, decode.string)
    use inserted_at <- decode.field(12, decode.string)
    use updated_at <- decode.field(13, decode.string)
    decode.success(ListRow(
      total_count:,
      work_item_id:,
      subject_id:,
      kind:,
      url:,
      archive_date:,
      status:,
      priority:,
      attempts:,
      max_attempts:,
      last_error:,
      available_at:,
      inserted_at:,
      updated_at:,
    ))
  }

  "select
  count(*) over () as total_count,
  id::text as work_item_id,
  subject_id,
  kind::text as kind,
  url,
  archive_date,
  status::text as status,
  priority,
  attempts,
  max_attempts,
  last_error,
  available_at::text as available_at,
  inserted_at::text as inserted_at,
  updated_at::text as updated_at
from work_item
order by
  priority desc,
  available_at asc,
  inserted_at asc
limit $1
offset $2
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `preparation_claim` query
/// defined in `./src/master/work_items/queries/sql/preparation_claim.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PreparationClaimRow {
  PreparationClaimRow(
    artifact_id: String,
    subject_id: String,
    fetch_host: String,
    source_url: String,
    fetched_url: String,
    content_type: Option(String),
    body_sha256: String,
    body_size_bytes: Int,
  )
}

/// Runs the `preparation_claim` query
/// defined in `./src/master/work_items/queries/sql/preparation_claim.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn preparation_claim(
  db: pog.Connection,
  arg_1: String,
  arg_2: Float,
  arg_3: Int,
) -> Result(pog.Returned(PreparationClaimRow), pog.QueryError) {
  let decoder = {
    use artifact_id <- decode.field(0, decode.string)
    use subject_id <- decode.field(1, decode.string)
    use fetch_host <- decode.field(2, decode.string)
    use source_url <- decode.field(3, decode.string)
    use fetched_url <- decode.field(4, decode.string)
    use content_type <- decode.field(5, decode.optional(decode.string))
    use body_sha256 <- decode.field(6, decode.string)
    use body_size_bytes <- decode.field(7, decode.int)
    decode.success(PreparationClaimRow(
      artifact_id:,
      subject_id:,
      fetch_host:,
      source_url:,
      fetched_url:,
      content_type:,
      body_sha256:,
      body_size_bytes:,
    ))
  }

  "with candidate as (
  select
    a.id as artifact_id,
    a.subject_id,
    w.fetch_host,
    a.source_url,
    a.fetched_url,
    a.content_type,
    a.body_sha256,
    a.body_size_bytes,
    t.extraction_status,
    t.attempts,
    t.max_attempts,
    t.lease_expires_at
  from artifact a
  join work_item w on w.id = a.work_item_id
  left join artifact_text t on t.artifact_id = a.id
  where a.body_size_bytes > 0
    and a.storage_content_encoding = 'br'
    and a.content_type is not null
    and lower(a.content_type) like 'text/html%'
    and (
      t.artifact_id is null
      or (
        t.extraction_status = 'running'
        and t.lease_expires_at <= timezone('utc', now())
      )
      or (
        t.extraction_status in ('failed', 'empty_body', 'html_parse_error')
        and t.attempts < t.max_attempts
      )
    )
  order by a.subject_id, w.fetch_host, a.fetched_url, a.id
  for update of a skip locked
  limit $3
),
claimed as (
  insert into artifact_text (
    artifact_id,
    extraction_status,
    worker_id,
    attempts,
    max_attempts,
    lease_expires_at,
    updated_at
  )
  select
    artifact_id,
    'running',
    $1,
    coalesce(attempts, 0) + 1,
    coalesce(max_attempts, 3),
    timezone('utc', now()) + ($2 * interval '1 second'),
    timezone('utc', now())
  from candidate
  on conflict (artifact_id) do update set
    extraction_status = 'running',
    worker_id = excluded.worker_id,
    attempts = artifact_text.attempts + 1,
    lease_expires_at = excluded.lease_expires_at,
    error = null,
    updated_at = timezone('utc', now())
  where
    (
      artifact_text.extraction_status = 'running'
      and artifact_text.lease_expires_at <= timezone('utc', now())
    )
    or (
      artifact_text.extraction_status in ('failed', 'empty_body', 'html_parse_error')
      and artifact_text.attempts < artifact_text.max_attempts
    )
  returning artifact_id
)
select
  candidate.artifact_id::text as artifact_id,
  candidate.subject_id,
  candidate.fetch_host,
  candidate.source_url,
  candidate.fetched_url,
  candidate.content_type,
  candidate.body_sha256,
  candidate.body_size_bytes
from candidate
join claimed on claimed.artifact_id = candidate.artifact_id
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.float(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `prepared_items` query
/// defined in `./src/master/work_items/queries/sql/prepared_items.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PreparedItemsRow {
  PreparedItemsRow(
    total_count: Int,
    subject_item_id: String,
    subject_id: String,
    source_key: String,
    url: String,
    verification_status: String,
    assunto: String,
    item: String,
    resposta_orgao: String,
    avaliacao_cgu: String,
    work_item_id: String,
    work_kind: Option(String),
    work_status: String,
    fetch_host: Option(String),
    artifact_id: String,
    status_code: Option(Int),
    content_type: Option(String),
    body_size_bytes: Int,
    fetched_url: Option(String),
    extraction_status: Option(String),
    char_count: Option(Int),
    cleaned_char_count: Option(Int),
    title: Option(String),
    cleaned_text_excerpt: String,
    extraction_updated_at: String,
  )
}

/// Runs the `prepared_items` query
/// defined in `./src/master/work_items/queries/sql/prepared_items.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn prepared_items(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(PreparedItemsRow), pog.QueryError) {
  let decoder = {
    use total_count <- decode.field(0, decode.int)
    use subject_item_id <- decode.field(1, decode.string)
    use subject_id <- decode.field(2, decode.string)
    use source_key <- decode.field(3, decode.string)
    use url <- decode.field(4, decode.string)
    use verification_status <- decode.field(5, decode.string)
    use assunto <- decode.field(6, decode.string)
    use item <- decode.field(7, decode.string)
    use resposta_orgao <- decode.field(8, decode.string)
    use avaliacao_cgu <- decode.field(9, decode.string)
    use work_item_id <- decode.field(10, decode.string)
    use work_kind <- decode.field(11, decode.optional(decode.string))
    use work_status <- decode.field(12, decode.string)
    use fetch_host <- decode.field(13, decode.optional(decode.string))
    use artifact_id <- decode.field(14, decode.string)
    use status_code <- decode.field(15, decode.optional(decode.int))
    use content_type <- decode.field(16, decode.optional(decode.string))
    use body_size_bytes <- decode.field(17, decode.int)
    use fetched_url <- decode.field(18, decode.optional(decode.string))
    use extraction_status <- decode.field(19, decode.optional(decode.string))
    use char_count <- decode.field(20, decode.optional(decode.int))
    use cleaned_char_count <- decode.field(21, decode.optional(decode.int))
    use title <- decode.field(22, decode.optional(decode.string))
    use cleaned_text_excerpt <- decode.field(23, decode.string)
    use extraction_updated_at <- decode.field(24, decode.string)
    decode.success(PreparedItemsRow(
      total_count:,
      subject_item_id:,
      subject_id:,
      source_key:,
      url:,
      verification_status:,
      assunto:,
      item:,
      resposta_orgao:,
      avaliacao_cgu:,
      work_item_id:,
      work_kind:,
      work_status:,
      fetch_host:,
      artifact_id:,
      status_code:,
      content_type:,
      body_size_bytes:,
      fetched_url:,
      extraction_status:,
      char_count:,
      cleaned_char_count:,
      title:,
      cleaned_text_excerpt:,
      extraction_updated_at:,
    ))
  }

  "select
  count(*) over ()::int as total_count,
  si.id::text as subject_item_id,
  si.subject_id,
  si.source_key,
  si.url,
  si.verification_status::text as verification_status,
  coalesce(si.metadata->>'assunto', si.metadata->>'Assunto', '') as assunto,
  coalesce(si.metadata->>'item', si.metadata->>'Item', '') as item,
  coalesce(si.metadata->>'resposta_orgao', si.metadata->>'RespostaOrgao', '') as resposta_orgao,
  coalesce(si.metadata->>'avaliacao_cgu', si.metadata->>'AvaliacaoCGU', '') as avaliacao_cgu,
  coalesce(w.id::text, '') as work_item_id,
  w.kind::text as work_kind,
  coalesce(w.status::text, '') as work_status,
  w.fetch_host,
  coalesce(a.id::text, '') as artifact_id,
  a.status_code,
  a.content_type,
  coalesce(a.body_size_bytes::int, 0) as body_size_bytes,
  a.fetched_url,
  t.extraction_status,
  t.char_count,
  t.cleaned_char_count,
  t.title,
  coalesce(left(t.cleaned_text, 1200), '') as cleaned_text_excerpt,
  coalesce(t.updated_at::text, '') as extraction_updated_at
from subject_item si
left join work_item w on w.subject_item_id = si.id
left join artifact a on a.work_item_id = w.id
left join artifact_text t on t.artifact_id = a.id
order by
  si.subject_id,
  si.source_key,
  w.kind nulls last,
  a.fetched_at desc nulls last
limit $1
offset $2
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `prepared_summary` query
/// defined in `./src/master/work_items/queries/sql/prepared_summary.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PreparedSummaryRow {
  PreparedSummaryRow(
    subject_item_count: Int,
    artifact_count: Int,
    extraction_count: Int,
    succeeded_count: Int,
    running_count: Int,
    failed_count: Int,
    empty_text_count: Int,
    median_cleaned_char_count: Int,
    p95_cleaned_char_count: Int,
  )
}

/// Runs the `prepared_summary` query
/// defined in `./src/master/work_items/queries/sql/prepared_summary.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn prepared_summary(
  db: pog.Connection,
) -> Result(pog.Returned(PreparedSummaryRow), pog.QueryError) {
  let decoder = {
    use subject_item_count <- decode.field(0, decode.int)
    use artifact_count <- decode.field(1, decode.int)
    use extraction_count <- decode.field(2, decode.int)
    use succeeded_count <- decode.field(3, decode.int)
    use running_count <- decode.field(4, decode.int)
    use failed_count <- decode.field(5, decode.int)
    use empty_text_count <- decode.field(6, decode.int)
    use median_cleaned_char_count <- decode.field(7, decode.int)
    use p95_cleaned_char_count <- decode.field(8, decode.int)
    decode.success(PreparedSummaryRow(
      subject_item_count:,
      artifact_count:,
      extraction_count:,
      succeeded_count:,
      running_count:,
      failed_count:,
      empty_text_count:,
      median_cleaned_char_count:,
      p95_cleaned_char_count:,
    ))
  }

  "select
  (select count(*)::int from subject_item) as subject_item_count,
  (select count(*)::int from artifact) as artifact_count,
  count(*)::int as extraction_count,
  count(*) filter (where extraction_status = 'succeeded')::int as succeeded_count,
  count(*) filter (where extraction_status = 'running')::int as running_count,
  count(*) filter (
    where extraction_status in ('failed', 'empty_body', 'empty_text', 'html_parse_error', 'extraction_error')
  )::int as failed_count,
  count(*) filter (where cleaned_char_count = 0)::int as empty_text_count,
  coalesce(percentile_cont(0.5) within group (order by cleaned_char_count), 0)::int as median_cleaned_char_count,
  coalesce(percentile_cont(0.95) within group (order by cleaned_char_count), 0)::int as p95_cleaned_char_count
from artifact_text
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `provider_slot_acquire` query
/// defined in `./src/master/work_items/queries/sql/provider_slot_acquire.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProviderSlotAcquireRow {
  ProviderSlotAcquireRow(delay_ms: Int)
}

/// Runs the `provider_slot_acquire` query
/// defined in `./src/master/work_items/queries/sql/provider_slot_acquire.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn provider_slot_acquire(
  db: pog.Connection,
  arg_1: String,
  arg_2: Float,
) -> Result(pog.Returned(ProviderSlotAcquireRow), pog.QueryError) {
  let decoder = {
    use delay_ms <- decode.field(0, decode.int)
    decode.success(ProviderSlotAcquireRow(delay_ms:))
  }

  "insert into provider_rate_limit (
  provider_key,
  delay_seconds,
  next_available_at
)
values (
  $1,
  $2,
  timezone('utc', now()) + ($2 * interval '1 second')
)
on conflict (provider_key) do update set
  delay_seconds = excluded.delay_seconds,
  next_available_at =
    greatest(
      provider_rate_limit.next_available_at,
      coalesce(provider_rate_limit.cooldown_until, timezone('utc', now())),
      timezone('utc', now())
    ) + (excluded.delay_seconds * interval '1 second')
returning greatest(
  0,
  (
    extract(epoch from (
      next_available_at
        - (delay_seconds * interval '1 second')
        - timezone('utc', now())
    )) * 1000
  )::int
) as delay_ms
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.float(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `provider_slot_report` query
/// defined in `./src/master/work_items/queries/sql/provider_slot_report.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProviderSlotReportRow {
  ProviderSlotReportRow(provider_key: String)
}

/// Runs the `provider_slot_report` query
/// defined in `./src/master/work_items/queries/sql/provider_slot_report.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn provider_slot_report(
  db: pog.Connection,
  arg_1: String,
  arg_2: Int,
  arg_3: Float,
) -> Result(pog.Returned(ProviderSlotReportRow), pog.QueryError) {
  let decoder = {
    use provider_key <- decode.field(0, decode.string)
    decode.success(ProviderSlotReportRow(provider_key:))
  }

  "insert into provider_rate_limit (
  provider_key,
  delay_seconds,
  cooldown_until,
  last_status_code
)
values (
  $1,
  $3,
  case
    when $2 = 429 then timezone('utc', now()) + (300.0 * interval '1 second')
    else null
  end,
  $2
)
on conflict (provider_key) do update set
  delay_seconds = excluded.delay_seconds,
  cooldown_until = case
    when excluded.last_status_code = 429
      then greatest(
        coalesce(provider_rate_limit.cooldown_until, timezone('utc', now())),
        excluded.cooldown_until
      )
    else provider_rate_limit.cooldown_until
  end,
  last_status_code = excluded.last_status_code
returning provider_key
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.float(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `renew_lease` query
/// defined in `./src/master/work_items/queries/sql/renew_lease.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RenewLeaseRow {
  RenewLeaseRow(lease_expires_at: String)
}

/// Runs the `renew_lease` query
/// defined in `./src/master/work_items/queries/sql/renew_lease.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn renew_lease(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: Float,
) -> Result(pog.Returned(RenewLeaseRow), pog.QueryError) {
  let decoder = {
    use lease_expires_at <- decode.field(0, decode.string)
    decode.success(RenewLeaseRow(lease_expires_at:))
  }

  "update work_lease
set
  expires_at = timezone('utc', now()) + ($4 * interval '1 second')
where
  work_item_id = $1::text::uuid
  and id = $2::text::uuid
  and worker_id = $3
  and released_at is null
  and expires_at > timezone('utc', now())
returning expires_at::text as lease_expires_at
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.float(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `subject_item_verification_counts` query
/// defined in `./src/master/work_items/queries/sql/subject_item_verification_counts.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SubjectItemVerificationCountsRow {
  SubjectItemVerificationCountsRow(label: String, count: Int)
}

/// Runs the `subject_item_verification_counts` query
/// defined in `./src/master/work_items/queries/sql/subject_item_verification_counts.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn subject_item_verification_counts(
  db: pog.Connection,
) -> Result(pog.Returned(SubjectItemVerificationCountsRow), pog.QueryError) {
  let decoder = {
    use label <- decode.field(0, decode.string)
    use count <- decode.field(1, decode.int)
    decode.success(SubjectItemVerificationCountsRow(label:, count:))
  }

  "select
  verification_status::text as label,
  count(*)::int as count
from subject_item
group by verification_status
order by count desc, label asc
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `update_worker_assignment` query
/// defined in `./src/master/work_items/queries/sql/update_worker_assignment.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UpdateWorkerAssignmentRow {
  UpdateWorkerAssignmentRow(assigned_slots: Int)
}

/// Runs the `update_worker_assignment` query
/// defined in `./src/master/work_items/queries/sql/update_worker_assignment.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_worker_assignment(
  db: pog.Connection,
  arg_1: String,
  arg_2: Int,
) -> Result(pog.Returned(UpdateWorkerAssignmentRow), pog.QueryError) {
  let decoder = {
    use assigned_slots <- decode.field(0, decode.int)
    decode.success(UpdateWorkerAssignmentRow(assigned_slots:))
  }

  "update worker_registry
set assigned_slots = $2
where worker_id = $1
returning assigned_slots
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `upsert_worker_heartbeat` query
/// defined in `./src/master/work_items/queries/sql/upsert_worker_heartbeat.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UpsertWorkerHeartbeatRow {
  UpsertWorkerHeartbeatRow(worker_id: String, capacity: Int)
}

/// Runs the `upsert_worker_heartbeat` query
/// defined in `./src/master/work_items/queries/sql/upsert_worker_heartbeat.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn upsert_worker_heartbeat(
  db: pog.Connection,
  arg_1: String,
  arg_2: Int,
) -> Result(pog.Returned(UpsertWorkerHeartbeatRow), pog.QueryError) {
  let decoder = {
    use worker_id <- decode.field(0, decode.string)
    use capacity <- decode.field(1, decode.int)
    decode.success(UpsertWorkerHeartbeatRow(worker_id:, capacity:))
  }

  "insert into worker_registry (
  worker_id,
  capacity,
  last_seen_at
)
values (
  $1,
  greatest($2, 0),
  timezone('utc', now())
)
on conflict (worker_id) do update set
  capacity = greatest(excluded.capacity, 0),
  last_seen_at = excluded.last_seen_at
returning
  worker_id,
  capacity
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `work_item_kind_counts` query
/// defined in `./src/master/work_items/queries/sql/work_item_kind_counts.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type WorkItemKindCountsRow {
  WorkItemKindCountsRow(label: String, count: Int)
}

/// Runs the `work_item_kind_counts` query
/// defined in `./src/master/work_items/queries/sql/work_item_kind_counts.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn work_item_kind_counts(
  db: pog.Connection,
) -> Result(pog.Returned(WorkItemKindCountsRow), pog.QueryError) {
  let decoder = {
    use label <- decode.field(0, decode.string)
    use count <- decode.field(1, decode.int)
    decode.success(WorkItemKindCountsRow(label:, count:))
  }

  "select
  kind as label,
  count(*)::int as count
from work_item
group by kind
order by count desc, label asc
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `work_item_status_counts` query
/// defined in `./src/master/work_items/queries/sql/work_item_status_counts.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type WorkItemStatusCountsRow {
  WorkItemStatusCountsRow(label: String, count: Int)
}

/// Runs the `work_item_status_counts` query
/// defined in `./src/master/work_items/queries/sql/work_item_status_counts.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn work_item_status_counts(
  db: pog.Connection,
) -> Result(pog.Returned(WorkItemStatusCountsRow), pog.QueryError) {
  let decoder = {
    use label <- decode.field(0, decode.string)
    use count <- decode.field(1, decode.int)
    decode.success(WorkItemStatusCountsRow(label:, count:))
  }

  "select
  status::text as label,
  count(*)::int as count
from work_item
group by status
order by count desc, label asc
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Enums -------------------------------------------------------------------

/// Corresponds to the Postgres `verification_status` enum.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type VerificationStatus {
  NonConform
  Conform
  NotVerified
}

fn verification_status_encoder(verification_status) -> pog.Value {
  case verification_status {
    NonConform -> "non_conform"
    Conform -> "conform"
    NotVerified -> "not_verified"
  }
  |> pog.text
}
