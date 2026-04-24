select
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
