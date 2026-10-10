-- Run once AFTER upgrade-v0.6.sql (and v0.7 for employee hours).
-- Additive; does not delete existing documents or line items.
alter table public.documents add column if not exists due_date date;
alter table public.documents add column if not exists purchase_order text;
alter table public.document_items add column if not exists item_name text;
alter table public.document_items add column if not exists discount_type text not null default 'amount' check (discount_type in ('amount','percent'));
alter table public.document_items add column if not exists discount_value numeric(12,2) not null default 0 check (discount_value >= 0);
create table if not exists public.billing_catalog (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null, description text, unit text not null default 'each',
 unit_price numeric(12,2) not null default 0 check(unit_price >= 0),
 tax_rate numeric(5,2) not null default 0 check(tax_rate between 0 and 100),
 created_at timestamptz not null default now()
);
create index if not exists billing_catalog_org_name on public.billing_catalog(organization_id,name);
alter table public.billing_catalog enable row level security;
drop policy if exists billing_catalog_owner on public.billing_catalog;
create policy billing_catalog_owner on public.billing_catalog for all to authenticated
 using (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))
 with check (exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())));
