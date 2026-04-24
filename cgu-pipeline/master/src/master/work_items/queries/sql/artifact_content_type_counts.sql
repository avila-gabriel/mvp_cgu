select
  coalesce(nullif(split_part(lower(content_type), ';', 1), ''), 'missing') as label,
  count(*)::int as count
from artifact
group by coalesce(nullif(split_part(lower(content_type), ';', 1), ''), 'missing')
order by count desc, label asc
limit 12
