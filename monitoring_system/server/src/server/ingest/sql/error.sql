insert into extension_error (
  error,
  extension_version,
  reported_at,
  payload
)
values (
  $1,
  $2,
  $3::timestamp,
  $4::jsonb
)
returning
  id::text as extension_error_id,
  error,
  reported_at
