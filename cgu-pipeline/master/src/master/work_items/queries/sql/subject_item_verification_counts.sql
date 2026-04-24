select
  verification_status::text as label,
  count(*)::int as count
from subject_item
group by verification_status
order by count desc, label asc
