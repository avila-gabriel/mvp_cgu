select
  a.work_item_id::text as work_item_id,
  a.id::text as artifact_id,
  'succeeded' as status
from artifact a
inner join work_lease l on l.id = a.lease_id
where
  a.work_item_id = $1::text::uuid
  and a.lease_id = $2::text::uuid
  and l.worker_id = $3
