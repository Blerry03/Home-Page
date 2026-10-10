-- Only use if organizations, clients, contacts, properties and jobs already exist.
ALTER TABLE public.jobs ADD CONSTRAINT jobs_id_organization_id_key UNIQUE (id, organization_id);

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
