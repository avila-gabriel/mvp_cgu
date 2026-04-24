update
  lease
set
  released_at = timezone('utc', now()),
  release_reason = 'expired'
where
  released_at is null
  and expires_at <= timezone('utc', now())
returning
  id::text as lease_id,
  evaluation_id::text as evaluation_id,
  claimed_by,
  release_reason
