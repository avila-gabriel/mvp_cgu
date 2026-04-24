insert into worker_registry (
  worker_id,
  capacity,
  last_seen_at
)
values (
  $1,
  greatest($2, 0),
  timezone('utc', now())
)
on conflict (worker_id) do update set
  capacity = greatest(excluded.capacity, 0),
  last_seen_at = excluded.last_seen_at
returning
  worker_id,
  capacity
