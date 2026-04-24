with upserted_subject as (
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
