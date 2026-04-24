update worker_registry
set assigned_slots = 0
where last_seen_at < timezone('utc', now()) - ($1 * interval '1 second')
returning worker_id
