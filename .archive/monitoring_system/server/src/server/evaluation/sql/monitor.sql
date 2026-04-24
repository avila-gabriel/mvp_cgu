insert into tracked_url (
  evaluation_id,
  evaluation_item_id,
  url,
  non_compliance_reason,
  relevant_evidence,
  last_evaluated_at,
  initial_priority
)
values (
  $1::uuid,
  $2::uuid,
  $3,
  $4,
  $5,
  $6::timestamp,
  $7
)
returning
  id::text as tracked_url_id,
  evaluation_id::text as evaluation_id,
  evaluation_item_id::text as evaluation_item_id,
  url,
  non_compliance_reason,
  relevant_evidence,
  last_evaluated_at,
  initial_priority,
  is_active
