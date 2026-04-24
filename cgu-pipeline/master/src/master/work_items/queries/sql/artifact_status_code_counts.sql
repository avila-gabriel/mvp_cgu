select
  coalesce(status_code::text, 'missing') as label,
  count(*)::int as count
from artifact
group by coalesce(status_code::text, 'missing')
order by count desc, label asc
limit 12
