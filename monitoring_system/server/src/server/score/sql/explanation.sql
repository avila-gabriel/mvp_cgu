insert into priority_explanation (
  item_priority_id,
  summary,
  detail
)
values (
  $1,
  $2,
  $3
)
on conflict (item_priority_id)
do update
set
  summary = excluded.summary,
  detail = excluded.detail;
