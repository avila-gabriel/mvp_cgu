insert into evaluation_item (
  evaluation_id,
  external_id,
  name,
  status,
  exact_url,
  justification,
  observed_evidence,
  note
)
values (
  $1::uuid,
  $2,
  $3,
  $4,
  $5,
  $6,
  $7,
  $8
)
returning
  id::text as evaluation_item_id,
  evaluation_id::text as evaluation_id,
  external_id,
  name,
  status,
  exact_url,
  justification,
  observed_evidence,
  note
