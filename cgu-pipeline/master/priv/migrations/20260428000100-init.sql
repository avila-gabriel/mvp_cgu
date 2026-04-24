--- migration:up
create extension if not exists pgcrypto;

create type work_status as enum (
  'pending',
  'running',
  'succeeded',
  'failed',
  'dead'
);

create type verification_status as enum (
  'not_verified',
  'conform',
  'non_conform'
);

create or replace function touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table subject (
  id text primary key check (id <> ''),
  metadata jsonb not null default '{}',
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now())
);

create table subject_item (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null references subject(id) on delete cascade,
  source_key text not null check (source_key <> ''),
  url text not null check (url <> ''),
  verification_status verification_status not null default 'not_verified',
  metadata jsonb not null default '{}',
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now()),
  unique (subject_id, source_key)
);

create table host_rate_limit (
  host text primary key check (host <> ''),
  next_available_at timestamp not null default timezone('utc', now()),
  delay_seconds double precision not null default 1.0 check (delay_seconds >= 0),
  last_status_code int,
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now())
);

create table work_item (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null references subject(id) on delete cascade,
  subject_item_id uuid references subject_item(id) on delete cascade,
  kind text not null check (kind <> ''),
  url text not null check (url <> ''),
  archive_date text check (archive_date is null or archive_date <> ''),
  fetch_host text not null references host_rate_limit(host),
  status work_status not null default 'pending',
  priority int not null default 0,
  attempts int not null default 0 check (attempts >= 0),
  max_attempts int not null default 5 check (max_attempts > 0),
  last_error text check (last_error is null or last_error <> ''),
  metadata jsonb not null default '{}',
  available_at timestamp not null default timezone('utc', now()),
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now()),
  unique (subject_item_id, kind, archive_date)
);

create table work_lease (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null references work_item(id) on delete cascade,
  worker_id text not null check (worker_id <> ''),
  claimed_at timestamp not null default timezone('utc', now()),
  expires_at timestamp not null,
  released_at timestamp,
  release_reason text check (release_reason is null or release_reason <> '')
);

create table artifact (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null references work_item(id) on delete cascade,
  lease_id uuid not null references work_lease(id) on delete restrict,
  subject_id text not null references subject(id) on delete cascade,
  subject_item_id uuid references subject_item(id) on delete set null,
  kind text not null check (kind <> ''),
  source_url text not null check (source_url <> ''),
  fetched_url text not null check (fetched_url <> ''),
  status_code int,
  content_type text check (content_type is null or content_type <> ''),
  body_sha256 text not null check (body_sha256 <> ''),
  body_size_bytes bigint not null check (body_size_bytes >= 0),
  storage_url text not null check (storage_url <> ''),
  storage_sha256 text not null check (storage_sha256 <> ''),
  storage_size_bytes bigint not null check (storage_size_bytes >= 0),
  storage_content_encoding text not null check (storage_content_encoding = 'br'),
  metadata jsonb not null default '{}',
  fetched_at timestamp not null default timezone('utc', now())
);

create table artifact_text (
  artifact_id uuid primary key references artifact(id) on delete cascade,
  extraction_status text not null check (extraction_status <> ''),
  title text,
  headings text,
  lists text,
  breadcrumbs text,
  language text,
  raw_text text,
  cleaned_text text,
  cleaned_html text,
  char_count int not null default 0 check (char_count >= 0),
  cleaned_char_count int not null default 0 check (cleaned_char_count >= 0),
  content_type text,
  extractor text not null default 'deboiler' check (extractor <> ''),
  extractor_version text,
  error text,
  worker_id text,
  attempts int not null default 0 check (attempts >= 0),
  max_attempts int not null default 3 check (max_attempts > 0),
  lease_expires_at timestamp,
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now())
);

create table worker_registry (
  worker_id text primary key check (worker_id <> ''),
  capacity int not null check (capacity >= 0),
  assigned_slots int not null default 0 check (assigned_slots >= 0),
  last_seen_at timestamp not null default timezone('utc', now()),
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now())
);

create table provider_rate_limit (
  provider_key text primary key check (provider_key <> ''),
  next_available_at timestamp not null default timezone('utc', now()),
  delay_seconds double precision not null check (delay_seconds >= 0),
  cooldown_until timestamp,
  last_status_code int,
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now())
);

create unique index work_item_one_active_lease_idx
  on work_lease (work_item_id)
  where released_at is null;

create index work_item_claimable_idx
  on work_item (status, priority desc, available_at asc, inserted_at asc);

create index work_item_claimable_host_idx
  on work_item (fetch_host, status, priority desc, available_at asc, inserted_at asc);

create index subject_item_subject_url_idx
  on subject_item (subject_id, url);

create index work_lease_expires_at_idx
  on work_lease (expires_at)
  where released_at is null;

create index artifact_work_item_id_idx
  on artifact (work_item_id, fetched_at desc);

create unique index artifact_work_item_lease_id_idx
  on artifact (work_item_id, lease_id);

create index artifact_text_status_idx
  on artifact_text (extraction_status);

create index artifact_text_lease_idx
  on artifact_text (extraction_status, lease_expires_at);

create index worker_registry_last_seen_idx
  on worker_registry (last_seen_at);

create trigger subject_touch_updated_at
before update on subject
for each row
execute function touch_updated_at();

create trigger subject_item_touch_updated_at
before update on subject_item
for each row
execute function touch_updated_at();

create trigger host_rate_limit_touch_updated_at
before update on host_rate_limit
for each row
execute function touch_updated_at();

create trigger work_item_touch_updated_at
before update on work_item
for each row
execute function touch_updated_at();

create trigger artifact_text_touch_updated_at
before update on artifact_text
for each row
execute function touch_updated_at();

create trigger worker_registry_touch_updated_at
before update on worker_registry
for each row
execute function touch_updated_at();

create trigger provider_rate_limit_touch_updated_at
before update on provider_rate_limit
for each row
execute function touch_updated_at();

--- migration:down
drop trigger if exists provider_rate_limit_touch_updated_at on provider_rate_limit;
drop trigger if exists worker_registry_touch_updated_at on worker_registry;
drop trigger if exists artifact_text_touch_updated_at on artifact_text;
drop trigger if exists work_item_touch_updated_at on work_item;
drop trigger if exists host_rate_limit_touch_updated_at on host_rate_limit;
drop trigger if exists subject_item_touch_updated_at on subject_item;
drop trigger if exists subject_touch_updated_at on subject;
drop table if exists provider_rate_limit;
drop table if exists worker_registry;
drop table if exists artifact_text;
drop table if exists artifact;
drop table if exists work_lease;
drop table if exists work_item;
drop table if exists host_rate_limit;
drop table if exists subject_item;
drop table if exists subject;
drop function if exists touch_updated_at();
drop type if exists verification_status;
drop type if exists work_status;
--- migration:end
