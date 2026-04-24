with candidate as (
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
