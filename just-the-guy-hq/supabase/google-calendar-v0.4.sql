-- Run once in Supabase SQL Editor AFTER schema.sql. Stores encrypted server-side Google refresh tokens.
create table if not exists public.google_calendar_connections (
 user_id uuid primary key references auth.users(id) on delete cascade,
 organization_id uuid not null references public.organizations(id) on delete cascade,
 refresh_token_ciphertext text not null,
 updated_at timestamptz not null default now()
);
create table if not exists public.google_calendar_events (
 organization_id uuid not null references public.organizations(id) on delete cascade,
 job_id uuid not null references public.jobs(id) on delete cascade,
 google_event_id text not null,
 updated_at timestamptz not null default now(),
 primary key (organization_id,job_id)
);
-- No client policies: only server-side service-role can access token and sync mapping tables.
alter table public.google_calendar_connections enable row level security;
alter table public.google_calendar_events enable row level security;
