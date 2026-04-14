select
  evaluation_item.id::text as item_id,
  evaluation_item.name,
  evaluation_item.exact_url,
  evaluation_item.justification,
  evaluation_item.observed_evidence,
  evaluation_item.note
from
  evaluation_item
where
  evaluation_item.evaluation_id = $1
  and evaluation_item.status <> 'fully_complies'
order by
  evaluation_item.inserted_at asc;
