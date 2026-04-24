select
  worker_id,
  capacity
from worker_registry
where last_seen_at >= timezone('utc', now()) - ($1 * interval '1 second')
order by worker_id asc
