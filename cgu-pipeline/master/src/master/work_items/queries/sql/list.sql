select
  count(*) over () as total_count,
  id::text as work_item_id,
  subject_id,
  kind::text as kind,
  url,
  archive_date,
  status::text as status,
  priority,
  attempts,
  max_attempts,
  last_error,
  available_at::text as available_at,
  inserted_at::text as inserted_at,
  updated_at::text as updated_at
from work_item
order by
  priority desc,
  available_at asc,
  inserted_at asc
limit $1
offset $2
