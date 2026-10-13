-- 0001_core_schema.sql — PeopleGone Phase 2 gateway core schema (§7.2)
-- Tables only. RLS in 0002, credit RPCs in 0003, storage+sweep in 0004.
-- Metadata only: no image data, no image URLs are ever stored (§7.2, §7.4).

create table if not exists public.installs (
  id uuid primary key references auth.users (id) on delete cascade,
  platform text,
  app_version text,
  consent_version int,
  consent_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.credits_ledger (
  install_id uuid not null references public.installs (id) on delete cascade,
  period text not null, -- YYYY-MM, UTC
  free_saves_used int not null default 0,
  pro_status boolean not null default false,
  pro_source text,
  pro_until timestamptz,
  fair_use_saves_used int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (install_id, period)
);

create table if not exists public.ledger_entries (
  id bigint generated always as identity primary key,
  install_id uuid not null references public.installs (id) on delete cascade,
  period text not null, -- YYYY-MM, UTC, period in which the counter moved
  kind text not null check (kind in ('consume', 'refund')),
  counter_kind text check (counter_kind in ('free', 'fair_use')),
  idempotency_key text not null,
  job_id uuid,
  created_at timestamptz not null default now(),
  unique (install_id, idempotency_key, kind)
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  install_id uuid not null references public.installs (id) on delete cascade,
  client_job_id text not null,
  status text not null default 'created'
    check (status in ('created', 'awaiting_confirm', 'processing', 'done', 'failed', 'expired')),
  engine text not null default 'mat',
  keep_ids int[],
  persons jsonb,
  input_dimensions int[],
  people_count int,
  removed_count int,
  mask_area_ratio double precision,
  gpu_seconds double precision,
  cost_estimate_usd double precision,
  retry_count int not null default 0,
  ghost_check_fired boolean,
  processor text,
  error text,
  callback_token_hash text,
  upload_path text,
  result_path text,
  meta jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  unique (install_id, client_job_id)
);

create index if not exists jobs_install_created_idx
  on public.jobs (install_id, created_at desc);
create index if not exists jobs_expires_idx
  on public.jobs (expires_at) where status in ('created', 'awaiting_confirm', 'processing');

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs (id) on delete set null,
  install_id uuid references public.installs (id) on delete cascade,
  note text,
  has_user_attached_image boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.consent_records (
  install_id uuid not null references public.installs (id) on delete cascade,
  consent_version int not null,
  accepted_at timestamptz not null default now(),
  provider_name_shown text,
  primary key (install_id, consent_version)
);
