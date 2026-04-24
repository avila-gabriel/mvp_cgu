with active_lease as (
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
