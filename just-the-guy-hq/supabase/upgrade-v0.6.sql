-- Just The Guy HQ v0.6. Run ONCE after schema.sql and upgrade-v0.5.sql.
-- Additive migration: keeps your existing records.
alter table public.jobs add column if not exists scheduled_start time;
alter table public.jobs add column if not exists scheduled_end time;
alter table public.jobs add column if not exists lead_source text;
alter table public.jobs add column if not exists contact_method text;
alter table public.jobs add column if not exists salesperson text;
alter table public.jobs add column if not exists subcontractor text;
alter table public.jobs add column if not exists subcontract_direction text check (subcontract_direction is null or subcontract_direction in ('outbound','inbound'));
create table if not exists public.measurement_runs (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 job_id uuid not null, location text not null default '', length_inches numeric(12,3) not null check(length_inches>=0),
 gutter_size text not null default '5-inch', gutter_color text not null default 'White', endcaps text not null default 'none',
 notes text, created_at timestamptz not null default now(),
 foreign key (job_id,organization_id) references public.jobs(id,organization_id) on delete cascade
);
create index if not exists measurement_runs_job on public.measurement_runs(job_id);
create table if not exists public.job_accessories (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 job_id uuid not null, one_story_downspouts integer not null default 0 check(one_story_downspouts>=0),
 two_story_downspouts integer not null default 0 check(two_story_downspouts>=0),
 miters integer not null default 0 check(miters>=0), a_elbows integer not null default 0 check(a_elbows>=0),
 b_elbows integer not null default 0 check(b_elbows>=0), guards_feet numeric(10,2) not null default 0 check(guards_feet>=0),
 adapters integer not null default 0 check(adapters>=0), notes text,
 unique(job_id,organization_id),
 foreign key (job_id,organization_id) references public.jobs(id,organization_id) on delete cascade
);
create table if not exists public.supplier_prices (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 supplier text not null, item_name text not null, color text not null default '', unit text not null default 'each',
 unit_price numeric(12,2) not null check(unit_price>=0), updated_at timestamptz not null default now()
);
create table if not exists public.employees (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null, hourly_rate numeric(10,2) not null default 0 check(hourly_rate>=0), active boolean not null default true,
 created_at timestamptz not null default now(), unique(id,organization_id)
);
alter table public.time_entries add column if not exists employee_id uuid references public.employees(id) on delete set null;
alter table public.time_entries add constraint time_entries_employee_tenant_fk foreign key(employee_id,organization_id) references public.employees(id,organization_id);
alter table public.time_entries add column if not exists rate_snapshot numeric(10,2) check(rate_snapshot>=0);
create table if not exists public.pay_periods (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 period_start date not null, period_end date not null, employee_id uuid not null,
 total_hours numeric(9,2) not null check(total_hours>=0), gross_base_pay numeric(12,2) not null check(gross_base_pay>=0),
 paid_at date, notes text, created_at timestamptz not null default now(), unique(organization_id,period_start,period_end,employee_id),
 foreign key(employee_id,organization_id) references public.employees(id,organization_id) on delete cascade
);
-- All new tables owner-only, as in v0.5; staff permissions are a separate project.
do $$ declare tab text; begin
 foreach tab in array array['measurement_runs','job_accessories','supplier_prices','employees','pay_periods'] loop
  execute format('alter table public.%I enable row level security',tab);
  execute format('drop policy if exists owner_access on public.%I',tab);
  execute format('create policy owner_access on public.%I for all to authenticated using (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid()))) with check (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))',tab);
 end loop;
end $$;
-- Internal billing line items and payment ledger (NOT integrated payment processing).
alter table public.documents add column if not exists issue_date date not null default current_date;
alter table public.documents add column if not exists contract_terms text;
create table if not exists public.document_items (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 document_id uuid not null references public.documents(id) on delete cascade,
 description text not null, quantity numeric(12,3) not null check(quantity>0),
 unit text not null default 'each', unit_price numeric(12,2) not null check(unit_price>=0),
 tax_rate numeric(5,2) not null default 0 check(tax_rate>=0 and tax_rate<=100),
 created_at timestamptz not null default now()
);
create table if not exists public.document_payments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 document_id uuid not null references public.documents(id) on delete cascade,
 amount numeric(12,2) not null check(amount>0), method text not null check(method in ('cash','check','card','other')),
 payment_date date not null default current_date, reference text, notes text, created_at timestamptz not null default now()
);
create index if not exists doc_items_parent on public.document_items(document_id);
create index if not exists doc_payments_parent on public.document_payments(document_id);
-- Ensure document and organization are consistent for tenant isolation.
alter table public.documents add constraint documents_id_organization_unique unique(id,organization_id);
alter table public.document_items add constraint document_items_tenant_fk foreign key(document_id,organization_id) references public.documents(id,organization_id) on delete cascade;
alter table public.document_payments add constraint document_payments_tenant_fk foreign key(document_id,organization_id) references public.documents(id,organization_id) on delete cascade;
do $$ declare tab text; begin
 foreach tab in array array['document_items','document_payments'] loop
  execute format('alter table public.%I enable row level security',tab);
  execute format('drop policy if exists owner_access on public.%I',tab);
  execute format('create policy owner_access on public.%I for all to authenticated using (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid()))) with check (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))',tab);
 end loop;
end $$;
