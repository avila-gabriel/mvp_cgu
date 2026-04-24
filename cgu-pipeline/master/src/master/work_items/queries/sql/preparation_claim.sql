with candidate as (
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
