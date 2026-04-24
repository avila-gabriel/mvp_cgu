update work_lease
set
  expires_at = timezone('utc', now()) + ($4 * interval '1 second')
where
  work_item_id = $1::text::uuid
  and id = $2::text::uuid
  and worker_id = $3
  and released_at is null
  and expires_at > timezone('utc', now())
returning expires_at::text as lease_expires_at
