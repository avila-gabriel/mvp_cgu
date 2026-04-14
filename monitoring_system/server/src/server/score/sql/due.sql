select
  monitored_change.id::text as change_id
from
  monitored_change
where
  monitored_change.status = 'pending'
  and not exists (
    select
      1
    from
      m25.job
    where
      m25.job.unique_key = 'score:' || monitored_change.id::text
      and m25.job.status not in ('failed', 'cancelled')
  )
order by
  monitored_change.detected_at asc;
