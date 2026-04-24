insert into evaluation_queue (
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
