select
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
