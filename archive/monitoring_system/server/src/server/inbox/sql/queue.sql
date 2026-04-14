select
  eq.evaluation_id::text as evaluation_id,
  e.organization_name,
  e.base_url,
  eq.priority,
  eq.priority_summary,
  eq.aging_deadline_at,
  eq.last_prioritized_at,
  eq.updated_at,
  mc.event,
  tp.url as top_url,
  top_item.explanation_summary,
  top_item.top_item_priority
from
  evaluation_queue eq
inner join evaluation e
  on e.id = eq.evaluation_id
left join monitored_change mc
  on mc.id = eq.top_monitored_change_id
left join tracked_path tp
  on tp.id = mc.tracked_path_id
left join lateral (
  select
    ip.priority as top_item_priority,
    pe.summary as explanation_summary
  from
    item_priority ip
  left join priority_explanation pe
    on pe.item_priority_id = ip.id
  where
    ip.monitored_change_id = mc.id
  order by
    ip.priority desc,
    ip.created_at desc
  limit 1
) as top_item
  on true
left join lease l
  on l.evaluation_id = eq.evaluation_id
  and l.released_at is null
  and l.expires_at > timezone('utc', now())
where
  e.is_active
  and eq.priority is not null
  and l.id is null
order by
  eq.priority desc nulls last,
  coalesce(eq.aging_deadline_at, eq.updated_at) asc,
  eq.updated_at asc
