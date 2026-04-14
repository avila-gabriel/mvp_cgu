insert into evaluation_queue (evaluation_id)
values ($1::uuid)
on conflict (evaluation_id) do nothing
returning
  evaluation_id::text as evaluation_id,
  priority,
  priority_summary
