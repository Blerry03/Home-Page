begin;

-- Billing foundation v1: catalog snapshots, reliable document numbering,
-- financial totals, and an atomic draft creation RPC.

alter table public.billing_catalog
  add column if not exists category text not null default 'Custom services',
  add column if not exists material_cost numeric(12,2) check (material_cost is null or material_cost >= 0),
  add column if not exists labor_cost numeric(12,2) check (labor_cost is null or labor_cost >= 0),
  add column if not exists markup_percent numeric(7,3) check (markup_percent is null or markup_percent >= 0),
  add column if not exists internal_notes text,
  add column if not exists active boolean not null default true;

alter table public.billing_catalog
  add constraint billing_catalog_id_organization_unique unique (id, organization_id);

alter table public.documents
  add column if not exists subtotal_amount numeric(12,2) not null default 0 check (subtotal_amount >= 0),
  add column if not exists discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  add column if not exists tax_amount numeric(12,2) not null default 0 check (tax_amount >= 0),
  add column if not exists deposit_required numeric(12,2) not null default 0 check (deposit_required >= 0),
  add column if not exists expiration_date date,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists assigned_to uuid references auth.users(id) on delete set null,
  add column if not exists archived_at timestamptz,
  add column if not exists revision_number integer not null default 1 check (revision_number > 0);

update public.documents
set subtotal_amount = amount,
    updated_at = coalesce(updated_at, created_at)
where subtotal_amount = 0 and amount > 0;

alter table public.document_items
  add column if not exists sort_order integer not null default 0,
  add column if not exists catalog_item_id uuid,
  add column if not exists cost_snapshot numeric(12,2) check (cost_snapshot is null or cost_snapshot >= 0),
  add column if not exists measurement_snapshot jsonb;

alter table public.document_items
  add constraint document_items_catalog_tenant_fk
  foreign key (catalog_item_id, organization_id)
  references public.billing_catalog(id, organization_id);

create table if not exists public.billing_settings (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  estimate_prefix text not null default 'EST' check (length(trim(estimate_prefix)) between 1 and 12),
  invoice_prefix text not null default 'INV' check (length(trim(invoice_prefix)) between 1 and 12),
  include_year boolean not null default true,
  number_padding smallint not null default 4 check (number_padding between 1 and 9),
  estimate_expiration_days integer not null default 30 check (estimate_expiration_days between 0 and 3650),
  default_payment_terms text not null default 'Payment due upon completion.',
  default_estimate_terms text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.billing_number_counters (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  kind text not null check (kind in ('estimate','invoice')),
  document_year integer not null check (document_year between 2000 and 9999),
  next_value bigint not null check (next_value > 0),
  primary key (organization_id, kind, document_year)
);

alter table public.billing_settings enable row level security;
alter table public.billing_number_counters enable row level security;

drop policy if exists billing_settings_admin on public.billing_settings;
create policy billing_settings_admin on public.billing_settings
  for all to authenticated
  using (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_id = (select auth.uid()))
    or public.hq_is_admin(organization_id)
  )
  with check (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_id = (select auth.uid()))
    or public.hq_is_admin(organization_id)
  );

drop policy if exists billing_number_counters_admin on public.billing_number_counters;
create policy billing_number_counters_admin on public.billing_number_counters
  for all to authenticated
  using (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_id = (select auth.uid()))
    or public.hq_is_admin(organization_id)
  )
  with check (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_id = (select auth.uid()))
    or public.hq_is_admin(organization_id)
  );

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.hq_next_document_number(org uuid, kind text, issue_date date default current_date)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_year integer := extract(year from coalesce(issue_date, current_date))::integer;
  v_counter_year integer;
  v_next bigint;
  v_prefix text;
  v_include_year boolean;
  v_padding smallint;
  v_number text;
  v_last bigint := 0;
begin
  if kind not in ('estimate','invoice') then raise exception 'Unsupported billing document type.'; end if;
  if (select auth.uid()) is null or not exists (select 1 from public.organizations o where o.id=org and (o.owner_id=(select auth.uid()) or public.hq_is_admin(org))) then raise exception 'Not authorized for this workspace.'; end if;
  insert into public.billing_settings (organization_id) values (org) on conflict (organization_id) do nothing;
  select case when kind = 'estimate' then estimate_prefix else invoice_prefix end,
         include_year, number_padding
    into v_prefix, v_include_year, v_padding
    from public.billing_settings where organization_id = org;
  if not found then raise exception 'Billing settings are not available for this workspace.'; end if;
  v_counter_year := case when v_include_year then v_year else 2000 end;
  select coalesce(max(case when d.number ~ '-[0-9]+$' then regexp_replace(d.number, '^.*-', '')::bigint else 0 end),0) into v_last
    from public.documents d
    where d.organization_id=org and d.kind=$2
      and d.number like trim(v_prefix)||'-'||case when v_include_year then v_year::text||'-%' else '%' end;
  insert into public.billing_number_counters (organization_id, kind, document_year, next_value)
    values (org, $2, v_counter_year, v_last+2)
  on conflict on constraint billing_number_counters_pkey
    do update set next_value = greatest(public.billing_number_counters.next_value,excluded.next_value-1) + 1
  returning next_value - 1 into v_next;
  v_number := trim(v_prefix) || case when v_include_year then '-' || v_year::text else '' end ||
    '-' || lpad(v_next::text, v_padding, '0');
  return v_number;
end;
$$;

revoke all on function private.hq_next_document_number(uuid,text,date) from public, anon;
grant execute on function private.hq_next_document_number(uuid,text,date) to authenticated;
revoke all on public.billing_number_counters from public, anon, authenticated;
revoke all on public.billing_settings from public, anon, authenticated;

create or replace function public.hq_create_billing_draft(org uuid, header jsonb, lines jsonb)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  draft public.documents;
  line public.document_items;
  new_id uuid;
  v_number text;
  v_index integer := 0;
  v_subtotal numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_tax numeric(12,2) := 0;
  v_line_base numeric(12,2);
  v_line_discount numeric(12,2);
  v_line_tax numeric(12,2);
  v_total numeric(12,2) := 0;
begin
  draft := jsonb_populate_record(null::public.documents, header);
  if draft.kind not in ('estimate','invoice') then raise exception 'Choose an estimate or invoice.'; end if;
  if jsonb_typeof(lines) is distinct from 'array' or jsonb_array_length(lines) = 0 then
    raise exception 'Add at least one line item.';
  end if;
  if draft.client_id is null then
    if nullif(btrim(header->>'new_customer_name'),'') is null then raise exception 'Enter a customer name.'; end if;
    insert into public.clients (organization_id,name,phone)
      values (org,btrim(header->>'new_customer_name'),nullif(btrim(header->>'new_customer_phone'),''))
      returning id into draft.client_id;
    insert into public.contacts (organization_id,client_id,name,email,phone,role)
      values (org,draft.client_id,btrim(header->>'new_customer_name'),draft.recipient_email,
        nullif(btrim(header->>'new_customer_phone'),''),case when draft.kind='estimate' then 'estimates' else 'billing' end)
      returning id into draft.recipient_contact_id;
  end if;
  if nullif(btrim(header->>'new_property_street'),'') is not null then
    if nullif(btrim(header->>'new_property_city'),'') is null then raise exception 'Enter the service city.'; end if;
    insert into public.properties (organization_id,client_id,label,address_line1,city,state,postal_code)
      values (org,draft.client_id,'Service property',btrim(header->>'new_property_street'),
        btrim(header->>'new_property_city'),'MI',coalesce(btrim(header->>'new_property_zip'),''))
      returning id into draft.property_id;
  end if;
  if draft.property_id is not null and not exists (
    select 1 from public.properties p where p.id=draft.property_id and p.organization_id=org and p.client_id=draft.client_id
  ) then raise exception 'Choose a service property that belongs to this customer.'; end if;
  if draft.job_id is not null and not exists (
    select 1 from public.jobs j where j.id=draft.job_id and j.organization_id=org and j.client_id=draft.client_id
      and (draft.property_id is null or j.property_id=draft.property_id)
  ) then raise exception 'Choose a job that belongs to this customer and property.'; end if;
  if draft.recipient_contact_id is not null and not exists (
    select 1 from public.contacts c where c.id=draft.recipient_contact_id and c.organization_id=org and c.client_id=draft.client_id
  ) then raise exception 'Choose a recipient contact that belongs to this customer.'; end if;
  v_number := coalesce(nullif(btrim(header->>'number'),''), private.hq_next_document_number(org,draft.kind,draft.issue_date));
  insert into public.documents (
    organization_id,client_id,property_id,job_id,kind,number,title,amount,status,
    recipient_contact_id,recipient_email,issue_date,due_date,expiration_date,purchase_order,
    contract_terms,notes,created_by,updated_at
  ) values (
    org,draft.client_id,draft.property_id,draft.job_id,draft.kind,v_number,
    coalesce(nullif(btrim(draft.title),''), 'Untitled ' || draft.kind),0,'draft',
    draft.recipient_contact_id,coalesce(draft.recipient_email,''),coalesce(draft.issue_date,current_date),
    case when draft.kind='invoice' then draft.due_date else null end,
    case when draft.kind='estimate' then coalesce(draft.expiration_date,draft.due_date) else null end,
    draft.purchase_order,draft.contract_terms,draft.notes,(select auth.uid()),now()
  ) returning id into new_id;
  for line in select * from jsonb_populate_recordset(null::public.document_items, lines)
  loop
    v_index := v_index + 1;
    if line.quantity is null or line.quantity <= 0 or line.unit_price is null or line.unit_price < 0 then
      raise exception 'Each line item needs a positive quantity and a nonnegative price.';
    end if;
    if line.tax_rate is null or line.tax_rate < 0 or line.tax_rate > 100 then raise exception 'Tax rate must be between 0 and 100.'; end if;
    if line.discount_value is null or line.discount_value < 0 or (line.discount_type='percent' and line.discount_value > 100) then
      raise exception 'Check the line item discount.';
    end if;
    v_line_base := round(line.quantity * line.unit_price,2);
    v_line_discount := case when line.discount_type='percent' then round(v_line_base * line.discount_value / 100,2) else line.discount_value end;
    if v_line_discount > v_line_base then raise exception 'Discount cannot exceed the line subtotal.'; end if;
    v_line_tax := round((v_line_base-v_line_discount) * line.tax_rate / 100,2);
    v_subtotal := v_subtotal + v_line_base;
    v_discount := v_discount + v_line_discount;
    v_tax := v_tax + v_line_tax;
    insert into public.document_items (
      organization_id,document_id,item_name,description,quantity,unit,unit_price,tax_rate,
      discount_type,discount_value,sort_order,catalog_item_id,cost_snapshot,measurement_snapshot
    ) values (
      org,new_id,coalesce(nullif(btrim(line.item_name),''),btrim(line.description)),coalesce(line.description,''),
      line.quantity,coalesce(nullif(btrim(line.unit),''),'each'),line.unit_price,line.tax_rate,
      coalesce(line.discount_type,'amount'),line.discount_value,v_index-1,line.catalog_item_id,
      line.cost_snapshot,line.measurement_snapshot
    );
  end loop;
  v_total := v_subtotal - v_discount + v_tax;
  update public.documents set amount=v_total, subtotal_amount=v_subtotal, discount_amount=v_discount,
    tax_amount=v_tax, updated_at=now() where id=new_id and organization_id=org;
  return new_id;
end;
$$;

revoke all on function public.hq_create_billing_draft(uuid,jsonb,jsonb) from public, anon;
grant execute on function public.hq_create_billing_draft(uuid,jsonb,jsonb) to authenticated;
drop function if exists public.hq_next_document_number(uuid,text,date);


-- Keep all document totals in sync with item edits, including edits made in a later draft session.
create or replace function public.hq_recalculate_billing_document()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  target_org uuid;
  target_doc uuid;
  v_subtotal numeric(12,2);
  v_discount numeric(12,2);
  v_tax numeric(12,2);
begin
  target_org := coalesce(new.organization_id, old.organization_id);
  target_doc := coalesce(new.document_id, old.document_id);
  select coalesce(sum(x.base),0), coalesce(sum(x.discount),0), coalesce(sum(x.tax),0)
    into v_subtotal,v_discount,v_tax
    from (
      select round(i.quantity*i.unit_price,2) as base,
        case when i.discount_type='percent' then round(round(i.quantity*i.unit_price,2)*i.discount_value/100,2) else i.discount_value end as discount,
        round((round(i.quantity*i.unit_price,2)-case when i.discount_type='percent' then round(round(i.quantity*i.unit_price,2)*i.discount_value/100,2) else i.discount_value end)*i.tax_rate/100,2) as tax
      from public.document_items i where i.organization_id=target_org and i.document_id=target_doc
    ) x;
  update public.documents set subtotal_amount=v_subtotal,discount_amount=v_discount,tax_amount=v_tax,
    amount=v_subtotal-v_discount+v_tax,updated_at=now()
    where organization_id=target_org and id=target_doc and status='draft';
  if tg_op='DELETE' then return old; else return new; end if;
end; $$;
revoke all on function public.hq_recalculate_billing_document() from public, anon, authenticated;

drop trigger if exists hq_recalculate_billing_document on public.document_items;
create trigger hq_recalculate_billing_document after insert or update or delete on public.document_items
for each row execute function public.hq_recalculate_billing_document();

create or replace function public.hq_guard_billing_integrity()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  doc_status text;
begin
  if tg_table_name='documents' then
    if tg_op='INSERT' then
      if new.status <> 'draft' then raise exception 'New billing documents must begin as drafts.'; end if;
      new.updated_at := now();
      return new;
    end if;
    if tg_op='DELETE' then
      if old.status <> 'draft' then raise exception 'Issued documents cannot be deleted; void or archive them instead.'; end if;
      return old;
    end if;
    if old.status <> 'draft' and new.status='draft' then raise exception 'Issued documents cannot be reopened as drafts.'; end if;
    if old.status <> 'draft' and (to_jsonb(new)-array['status','updated_at','archived_at']) is distinct from (to_jsonb(old)-array['status','updated_at','archived_at']) then
      raise exception 'Issued document details are locked. Create a revised document or change order.';
    end if;
    new.updated_at := now();
    return new;
  end if;
  if tg_op='DELETE' or tg_op='UPDATE' then
    select status into doc_status from public.documents where id=old.document_id and organization_id=old.organization_id;
    if doc_status is distinct from 'draft' then raise exception 'Line items can only be changed while the document is a draft.'; end if;
  end if;
  if tg_op='INSERT' or tg_op='UPDATE' then
    select status into doc_status from public.documents where id=new.document_id and organization_id=new.organization_id;
    if doc_status is distinct from 'draft' then raise exception 'Line items can only be changed while the document is a draft.'; end if;
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end; $$;
revoke all on function public.hq_guard_billing_integrity() from public, anon, authenticated;
drop trigger if exists hq_guard_billing_integrity on public.documents;
create trigger hq_guard_billing_integrity before insert or update or delete on public.documents
for each row execute function public.hq_guard_billing_integrity();
drop trigger if exists hq_guard_billing_item_integrity on public.document_items;
create trigger hq_guard_billing_item_integrity before insert or update or delete on public.document_items
for each row execute function public.hq_guard_billing_integrity();

commit;
