with existing_artifact as (
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
