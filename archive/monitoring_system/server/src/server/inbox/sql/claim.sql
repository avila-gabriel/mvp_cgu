with inserted_lease as (
  insert into lease (
    evaluation_id,
    claimed_by,
    expires_at
  )
  select
    $1::uuid,
    $2,
    timezone('utc', now()) + ($3 * interval '1 second')
  where
    exists (
      select
        1
      from
        evaluation_queue
      where
        evaluation_id = $1::uuid
    )
    and not exists (
      select
        1
      from
        lease
      where
        evaluation_id = $1::uuid
        and released_at is null
        and expires_at > timezone('utc', now())
    )
  returning
    id::text as lease_id,
    evaluation_id::text as evaluation_id,
    claimed_by,
    claimed_at,
    expires_at
)
select
  lease_id,
  evaluation_id,
  claimed_by,
  claimed_at,
  expires_at
from
  inserted_lease
