insert into provider_rate_limit (
  provider_key,
  delay_seconds,
  cooldown_until,
  last_status_code
)
values (
  $1,
  $3,
  case
    when $2 = 429 then timezone('utc', now()) + (300.0 * interval '1 second')
    else null
  end,
  $2
)
on conflict (provider_key) do update set
  delay_seconds = excluded.delay_seconds,
  cooldown_until = case
    when excluded.last_status_code = 429
      then greatest(
        coalesce(provider_rate_limit.cooldown_until, timezone('utc', now())),
        excluded.cooldown_until
      )
    else provider_rate_limit.cooldown_until
  end,
  last_status_code = excluded.last_status_code
returning provider_key
