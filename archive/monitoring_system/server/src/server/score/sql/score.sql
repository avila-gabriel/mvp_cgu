insert into item_priority (
  monitored_change_id,
  evaluation_item_id,
  priority_mode,
  evaluator_name,
  priority
)
values (
  $1,
  $2,
  $3,
  $4,
  $5
)
on conflict (monitored_change_id, evaluation_item_id)
do update
set
  priority_mode = excluded.priority_mode,
  evaluator_name = excluded.evaluator_name,
  priority = excluded.priority
returning
  id::text as item_priority_id;
