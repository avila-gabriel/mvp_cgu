with picked as (
  select
    evaluation.id,
    evaluation.next_monitor_at
  from
    evaluation
  where
    evaluation.is_active
    and evaluation.next_monitor_at <= timezone('utc', now())
    and exists (
      select
        1
      from
        evaluation_item
      where
        evaluation_item.evaluation_id = evaluation.id
        and evaluation_item.status <> 'fully_complies'
    )
  order by
    evaluation.next_monitor_at asc
  for update skip locked
),
updated as (
  update evaluation
  set
    next_monitor_at = timezone('utc', now()) + interval '30 minutes'
  from
    picked
  where
    evaluation.id = picked.id
  returning
    evaluation.id::text as evaluation_id,
    extract(epoch from picked.next_monitor_at)::int as slot
)
select
  evaluation_id,
  slot
from
  updated;
