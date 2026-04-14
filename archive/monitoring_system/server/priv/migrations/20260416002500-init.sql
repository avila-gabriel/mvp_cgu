--- migration:up
create extension if not exists pgcrypto;

create type evaluation_kind as enum (
  'initial',
  'reevaluation'
);

create type evaluation_item_status as enum (
  'fully_complies',
  'partially_complies',
  'does_not_comply',
  'not_verified'
);

create type priority_level as enum (
  'low',
  'medium',
  'high'
);

create type monitored_change_event as enum (
  'page_changed',
  'path_discovered',
  'path_removed',
  'topology_changed'
);

create type monitored_change_status as enum (
  'pending',
  'prioritized',
  'dismissed'
);

create type priority_mode as enum (
  'comparison',
  'discovery'
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

create table evaluation (
  id uuid primary key default gen_random_uuid(),
  organization_name text not null check (organization_name <> ''),
  base_url text not null check (base_url <> ''),
  extension_version text not null check (extension_version <> ''),
  evaluated_at timestamp not null,
  evaluator_name text not null check (evaluator_name <> ''),
  kind evaluation_kind not null,
  evaluation_note text check (evaluation_note is null or evaluation_note <> ''),
  source_payload jsonb not null,
  is_active boolean not null default true,
  next_monitor_at timestamp not null default timezone('utc', now()),
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now())
);

create table evaluation_item (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references evaluation(id) on delete cascade,
  external_id text not null check (external_id <> ''),
  name text not null check (name <> ''),
  status evaluation_item_status not null,
  exact_url text check (exact_url is null or exact_url <> ''),
  justification text check (justification is null or justification <> ''),
  observed_evidence text check (
    observed_evidence is null or observed_evidence <> ''
  ),
  note text check (note is null or note <> ''),
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now()),
  unique (evaluation_id, external_id)
);

create table tracked_url (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references evaluation(id) on delete cascade,
  evaluation_item_id uuid not null references evaluation_item(id) on delete cascade,
  url text not null check (url <> ''),
  non_compliance_reason text check (
    non_compliance_reason is null or non_compliance_reason <> ''
  ),
  relevant_evidence text check (
    relevant_evidence is null or relevant_evidence <> ''
  ),
  last_evaluated_at timestamp,
  initial_priority priority_level not null,
  is_active boolean not null default true,
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now()),
  unique (evaluation_item_id, url)
);

create table tracked_path (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references evaluation(id) on delete cascade,
  url text not null check (url <> ''),
  normalized_url text not null check (normalized_url <> ''),
  path text not null check (path <> ''),
  depth int not null default 0 check (depth >= 0),
  first_discovered_at timestamp not null default timezone('utc', now()),
  last_seen_at timestamp not null default timezone('utc', now()),
  last_changed_at timestamp,
  removal_detected_at timestamp,
  is_active boolean not null default true,
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now()),
  unique (evaluation_id, normalized_url)
);

create table page_snapshot (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references evaluation(id) on delete cascade,
  tracked_path_id uuid not null references tracked_path(id) on delete cascade,
  fetched_at timestamp not null default timezone('utc', now()),
  http_status int,
  content_type text check (content_type is null or content_type <> ''),
  raw_body text,
  normalized_body text,
  visible_text text,
  body_hash text check (body_hash is null or body_hash <> ''),
  topology_summary jsonb,
  fetch_error text check (fetch_error is null or fetch_error <> ''),
  is_baseline boolean not null default false
);

create table monitored_change (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references evaluation(id) on delete cascade,
  tracked_path_id uuid not null references tracked_path(id) on delete cascade,
  previous_snapshot_id uuid references page_snapshot(id) on delete set null,
  current_snapshot_id uuid not null references page_snapshot(id) on delete cascade,
  event monitored_change_event not null,
  status monitored_change_status not null default 'pending',
  summary text check (summary is null or summary <> ''),
  normalized_diff jsonb not null,
  detected_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now()),
  unique (tracked_path_id, current_snapshot_id)
);

create table item_priority (
  id uuid primary key default gen_random_uuid(),
  monitored_change_id uuid not null references monitored_change(id) on delete cascade,
  evaluation_item_id uuid not null references evaluation_item(id) on delete cascade,
  priority_mode priority_mode not null,
  evaluator_name text not null check (evaluator_name <> ''),
  priority float8 not null check (priority >= 0 and priority <= 1),
  created_at timestamp not null default timezone('utc', now()),
  unique (monitored_change_id, evaluation_item_id)
);

create table priority_explanation (
  id uuid primary key default gen_random_uuid(),
  item_priority_id uuid not null unique references item_priority(id) on delete cascade,
  summary text check (summary is null or summary <> ''),
  detail jsonb not null,
  created_at timestamp not null default timezone('utc', now())
);

create table evaluation_queue (
  evaluation_id uuid primary key references evaluation(id) on delete cascade,
  top_monitored_change_id uuid references monitored_change(id) on delete set null,
  priority float8 check (priority is null or priority >= 0 and priority <= 1),
  priority_summary text check (priority_summary is null or priority_summary <> ''),
  aging_deadline_at timestamp,
  last_prioritized_at timestamp,
  inserted_at timestamp not null default timezone('utc', now()),
  updated_at timestamp not null default timezone('utc', now())
);

create table lease (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references evaluation(id) on delete cascade,
  claimed_by text not null check (claimed_by <> ''),
  claimed_at timestamp not null default timezone('utc', now()),
  expires_at timestamp not null,
  released_at timestamp,
  release_reason text check (release_reason is null or release_reason <> '')
);

create table extension_error (
  id uuid primary key default gen_random_uuid(),
  error text not null check (error <> ''),
  extension_version text not null check (extension_version <> ''),
  reported_at timestamp not null,
  payload jsonb not null,
  inserted_at timestamp not null default timezone('utc', now())
);

create unique index lease_one_active_per_evaluation_idx
  on lease (evaluation_id)
  where released_at is null;

create index evaluation_active_idx
  on evaluation (is_active, evaluated_at desc);

create index evaluation_monitor_due_idx
  on evaluation (is_active, next_monitor_at asc);

create index evaluation_item_evaluation_id_idx
  on evaluation_item (evaluation_id);

create index evaluation_item_status_idx
  on evaluation_item (status);

create index tracked_url_evaluation_id_idx
  on tracked_url (evaluation_id);

create index tracked_url_active_idx
  on tracked_url (is_active, initial_priority);

create index tracked_path_evaluation_id_idx
  on tracked_path (evaluation_id);

create index tracked_path_active_idx
  on tracked_path (evaluation_id, is_active, last_seen_at desc);

create index page_snapshot_tracked_path_id_idx
  on page_snapshot (tracked_path_id, fetched_at desc);

create index page_snapshot_evaluation_id_idx
  on page_snapshot (evaluation_id, is_baseline);

create index monitored_change_status_idx
  on monitored_change (status, detected_at desc);

create index monitored_change_evaluation_id_idx
  on monitored_change (evaluation_id, status);

create index item_priority_evaluation_item_id_idx
  on item_priority (evaluation_item_id, priority desc);

create index evaluation_queue_priority_idx
  on evaluation_queue (priority desc, updated_at asc);

create index lease_expires_at_idx
  on lease (expires_at)
  where released_at is null;

create index extension_error_reported_at_idx
  on extension_error (reported_at desc);

create trigger evaluation_touch_updated_at
before update on evaluation
for each row
execute function touch_updated_at();

create trigger evaluation_item_touch_updated_at
before update on evaluation_item
for each row
execute function touch_updated_at();

create trigger tracked_url_touch_updated_at
before update on tracked_url
for each row
execute function touch_updated_at();

create trigger tracked_path_touch_updated_at
before update on tracked_path
for each row
execute function touch_updated_at();

create trigger monitored_change_touch_updated_at
before update on monitored_change
for each row
execute function touch_updated_at();

create trigger evaluation_queue_touch_updated_at
before update on evaluation_queue
for each row
execute function touch_updated_at();

--- migration:down
drop trigger if exists evaluation_queue_touch_updated_at on evaluation_queue;
drop trigger if exists monitored_change_touch_updated_at on monitored_change;
drop trigger if exists tracked_path_touch_updated_at on tracked_path;
drop trigger if exists tracked_url_touch_updated_at on tracked_url;
drop trigger if exists evaluation_item_touch_updated_at on evaluation_item;
drop trigger if exists evaluation_touch_updated_at on evaluation;

drop index if exists lease_expires_at_idx;
drop index if exists extension_error_reported_at_idx;
drop index if exists evaluation_queue_priority_idx;
drop index if exists item_priority_evaluation_item_id_idx;
drop index if exists monitored_change_evaluation_id_idx;
drop index if exists monitored_change_status_idx;
drop index if exists page_snapshot_evaluation_id_idx;
drop index if exists page_snapshot_tracked_path_id_idx;
drop index if exists tracked_path_active_idx;
drop index if exists tracked_path_evaluation_id_idx;
drop index if exists tracked_url_active_idx;
drop index if exists tracked_url_evaluation_id_idx;
drop index if exists evaluation_item_status_idx;
drop index if exists evaluation_item_evaluation_id_idx;
drop index if exists evaluation_active_idx;
drop index if exists lease_one_active_per_evaluation_idx;

drop table if exists extension_error;
drop table if exists lease;
drop table if exists evaluation_queue;
drop table if exists priority_explanation;
drop table if exists item_priority;
drop table if exists monitored_change;
drop table if exists page_snapshot;
drop table if exists tracked_path;
drop table if exists tracked_url;
drop table if exists evaluation_item;
drop table if exists evaluation;

drop function if exists touch_updated_at();

drop type if exists priority_mode;
drop type if exists monitored_change_status;
drop type if exists monitored_change_event;
drop type if exists priority_level;
drop type if exists evaluation_item_status;
drop type if exists evaluation_kind;
--- migration:end
