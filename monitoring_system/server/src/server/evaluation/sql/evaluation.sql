insert into evaluation (
  organization_name,
  base_url,
  extension_version,
  evaluated_at,
  evaluator_name,
  kind,
  evaluation_note,
  source_payload
)
values (
  $1,
  $2,
  $3,
  $4::timestamp,
  $5,
  $6,
  $7,
  $8::jsonb
)
returning
  id::text as evaluation_id,
  organization_name,
  base_url,
  extension_version,
  evaluated_at,
  evaluator_name,
  kind,
  evaluation_note,
  source_payload,
  is_active
