begin;

create table public.hq_admin_memberships (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (organization_id, user_id),
  unique (user_id)
);
alter table public.hq_admin_memberships enable row level security;
revoke all on public.hq_admin_memberships from public, anon, authenticated;

create function public.hq_is_admin(target_organization uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.hq_admin_memberships
    where organization_id = target_organization and user_id = (select auth.uid())
  );
$$;
revoke all on function public.hq_is_admin(uuid) from public, anon;
grant execute on function public.hq_is_admin(uuid) to authenticated;

create policy hq_admin_read on public.organizations for select to authenticated
  using (public.hq_is_admin(id));

create table public.hq_activity (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  actor_id uuid,
  record_table text not null,
  record_id uuid not null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  occurred_at timestamptz not null default clock_timestamp()
);
create index hq_activity_org_time on public.hq_activity (organization_id, occurred_at desc);
alter table public.hq_activity enable row level security;
revoke all on public.hq_activity from public, anon, authenticated;
grant select on public.hq_activity to authenticated;
create policy hq_activity_read on public.hq_activity for select to authenticated
  using (exists (select 1 from public.organizations where id = organization_id));

create function public.hq_log_activity()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  row_data jsonb;
begin
  if tg_op = 'DELETE' then
    row_data := to_jsonb(old);
  else
    row_data := to_jsonb(new);
  end if;
  if tg_op = 'UPDATE' and old.organization_id is distinct from new.organization_id then
    raise exception 'HQ records cannot move between organizations';
  end if;
  insert into public.hq_activity (organization_id, actor_id, record_table, record_id, action)
  select id, auth.uid(), tg_table_name, (row_data->>'id')::uuid, tg_op
  from public.organizations where id = (row_data->>'organization_id')::uuid;
  return null;
end;
$$;
revoke all on function public.hq_log_activity() from public, anon, authenticated;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'clients', 'contacts', 'properties', 'jobs', 'documents',
    'document_items', 'document_payments', 'billing_catalog', 'material_items',
    'time_entries', 'measurement_runs', 'job_accessories', 'supplier_prices',
    'employees', 'pay_periods'
  ] loop
    execute format(
      'create policy hq_admin_access on public.%I for all to authenticated
       using (public.hq_is_admin(organization_id)) with check (public.hq_is_admin(organization_id))',
      table_name
    );
    execute format(
      'create trigger hq_log_activity after insert or update or delete on public.%I
       for each row execute function public.hq_log_activity()',
      table_name
    );
  end loop;
end;
$$;

commit;
