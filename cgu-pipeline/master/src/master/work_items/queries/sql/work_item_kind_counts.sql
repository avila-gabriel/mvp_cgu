select
  kind as label,
  count(*)::int as count
from work_item
group by kind
order by count desc, label asc
