-- Run in Supabase SQL Editor. This is an owner-only MVP; add staff membership and granular permissions later.
create extension if not exists pgcrypto;
create table public.organizations (
 id uuid primary key default gen_random_uuid(), name text not null,
 owner_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 unique(owner_id)
);
create table public.clients (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null, type text not null default 'residential' check(type in ('residential','hoa','commercial','contractor')),
 phone text, notes text, created_at timestamptz not null default now(),
 unique(id,organization_id)
);
create table public.contacts (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 client_id uuid not null, name text not null, email text, phone text,
 role text not null default 'other' check(role in ('primary','estimates','billing','property','other')),
 created_at timestamptz not null default now(),
 foreign key (client_id,organization_id) references public.clients(id,organization_id) on delete cascade
);
create table public.properties (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 client_id uuid not null, label text not null default 'Property',address_line1 text not null, city text not null,
 state text not null default 'MI', postal_code text not null default '', notes text, created_at timestamptz not null default now(),
 unique(id,organization_id),
 foreign key (client_id,organization_id) references public.clients(id,organization_id) on delete cascade
);
create table public.jobs (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 client_id uuid not null, property_id uuid, title text not null,
 status text not null default 'lead' check(status in ('lead','estimate','approved','scheduled','in_progress','complete','invoiced','closed')),
 scheduled_date date, notes text, created_at timestamptz not null default now(),
 foreign key (client_id,organization_id) references public.clients(id,organization_id) on delete cascade,
 foreign key (property_id,organization_id) references public.properties(id,organization_id) on delete set null (property_id)
);
create index on public.clients(organization_id,name);
create index on public.contacts(client_id);
create index on public.properties(client_id);
create index on public.jobs(client_id);
create index on public.jobs(organization_id,status,scheduled_date);
-- Verify a job's property belongs to the same customer, not merely the same organization.
create function public.job_property_client_guard() returns trigger language plpgsql set search_path = '' as $$
begin
 if new.property_id is not null and not exists (
   select 1 from public.properties p where p.id=new.property_id and p.organization_id=new.organization_id and p.client_id=new.client_id
 ) then raise exception 'Job property must belong to the job customer'; end if;
 return new;
end $$;
create trigger job_property_client_guard before insert or update on public.jobs for each row execute function public.job_property_client_guard();
-- Never expose other organizations' records to an authenticated account.
alter table public.organizations enable row level security;
alter table public.clients enable row level security;
alter table public.contacts enable row level security;
alter table public.properties enable row level security;
alter table public.jobs enable row level security;
create policy org_owner on public.organizations for all to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy client_owner on public.clients for all to authenticated
 using(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))
 with check(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())));
create policy contact_owner on public.contacts for all to authenticated
 using(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))
 with check(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())));
create policy property_owner on public.properties for all to authenticated
 using(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))
 with check(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())));
create policy job_owner on public.jobs for all to authenticated
 using(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))
 with check(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())));

-- Documents: estimate/invoice records belong to a customer and optionally a property/job.
create table public.documents (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 client_id uuid not null,
 property_id uuid,
 job_id uuid,
 kind text not null check(kind in ('estimate','invoice')),
 number text not null,
 title text not null,
 amount numeric(12,2) not null default 0 check(amount >= 0),
 status text not null default 'draft' check(status in ('draft','sent','approved','declined','paid','void')),
 recipient_contact_id uuid references public.contacts(id) on delete set null,
 recipient_email text not null,
 notes text,
 created_at timestamptz not null default now(),
 foreign key(client_id,organization_id) references public.clients(id,organization_id) on delete cascade,
 foreign key(property_id,organization_id) references public.properties(id,organization_id) on delete set null (property_id),
 foreign key(job_id,organization_id) references public.jobs(id,organization_id) on delete set null (job_id),
 unique (organization_id,kind,number)
);
create index on public.documents(organization_id,kind,status);
create index on public.documents(client_id,property_id);
create function public.document_relation_guard() returns trigger language plpgsql set search_path = '' as $$
begin
 if new.property_id is not null and not exists (select 1 from public.properties p where p.id=new.property_id and p.client_id=new.client_id and p.organization_id=new.organization_id) then
  raise exception 'Document property must belong to document customer';
 end if;
 if new.job_id is not null and not exists (select 1 from public.jobs j where j.id=new.job_id and j.client_id=new.client_id and j.organization_id=new.organization_id and (new.property_id is null or j.property_id=new.property_id)) then
  raise exception 'Document job must belong to document customer and selected property';
 end if;
 if new.recipient_contact_id is not null and not exists (select 1 from public.contacts c where c.id=new.recipient_contact_id and c.client_id=new.client_id and c.organization_id=new.organization_id) then
  raise exception 'Document recipient contact must belong to document customer';
 end if;
 return new;
end $$;
create trigger document_relation_guard before insert or update on public.documents for each row execute function public.document_relation_guard();
alter table public.documents enable row level security;
create policy document_owner on public.documents for all to authenticated
 using(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())))
 with check(exists(select 1 from public.organizations o where o.id=organization_id and o.owner_id=(select auth.uid())));
