insert into provider_rate_limit (
  provider_key,
  delay_seconds,
  next_available_at
)
values (
  $1,
  $2,
  timezone('utc', now()) + ($2 * interval '1 second')
)
on conflict (provider_key) do update set
  delay_seconds = excluded.delay_seconds,
  next_available_at =
    greatest(
      provider_rate_limit.next_available_at,
      coalesce(provider_rate_limit.cooldown_until, timezone('utc', now())),
      timezone('utc', now())
    ) + (excluded.delay_seconds * interval '1 second')
returning greatest(
  0,
  (
    extract(epoch from (
      next_available_at
        - (delay_seconds * interval '1 second')
        - timezone('utc', now())
    )) * 1000
  )::int
) as delay_ms
