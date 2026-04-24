select
  status::text as label,
  count(*)::int as count
from work_item
group by status
order by count desc, label asc
