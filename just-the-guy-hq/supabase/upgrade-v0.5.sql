-- Just The Guy HQ v0.5: apply once AFTER schema.sql; existing tables/data remain intact.
-- These modules are owner-only for now. Do not give workers the owner's login.
create table if not exists public.material_items (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 job_id uuid,
 item_name text not null check(length(trim(item_name))>0),
 quantity numeric(10,2) not null default 1 check(quantity>0),
 unit text not null default 'each',
 state text not null default 'needed' check(state in ('needed','ordered','received')),
 notes text,
 created_at timestamptz not null default now(),
 foreign key (job_id,organization_id) references public.jobs(id,organization_id) on delete set null (job_id)
);
create index if not exists material_items_org_state on public.material_items(organization_id,state);
create index if not exists material_items_job on public.material_items(job_id);
create table if not exists public.time_entries (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 job_id uuid,
 employee_name text not null check(length(trim(employee_name))>0),
 work_date date not null,
 hours numeric(6,2) not null check(hours>0 and hours<=24),
 notes text,
 created_at timestamptz not null default now(),
 foreign key (job_id,organization_id) references public.jobs(id,organization_id) on delete set null (job_id)
);
create index if not exists time_entries_org_date on public.time_entries(organization_id,work_date desc);
create index if not exists time_entries_job on public.time_entries(job_id);
alter table public.material_items enable row level security;
alter table public.time_entries enable row level security;
drop policy if exists material_owner on public.material_items;
create policy material_owner on public.material_items for all to authenticated
 using (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))
 with check (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())));
drop policy if exists time_owner on public.time_entries;
create policy time_owner on public.time_entries for all to authenticated
 using (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))
 with check (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())));
