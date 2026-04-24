update worker_registry
set assigned_slots = $2
where worker_id = $1
returning assigned_slots
