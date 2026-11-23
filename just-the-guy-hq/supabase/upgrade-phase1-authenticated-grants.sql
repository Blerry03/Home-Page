-- These application privileges are enforced by the existing row-level security policies.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'organizations', 'clients', 'contacts', 'properties', 'jobs', 'documents',
    'document_items', 'document_payments', 'billing_catalog', 'material_items',
    'time_entries', 'measurement_runs', 'job_accessories', 'supplier_prices',
    'employees', 'pay_periods'
  ] loop
    if not exists (
      select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = table_name and c.relrowsecurity
    ) then
      raise exception 'RLS disabled on %', table_name;
    end if;
    execute format('grant select, insert, update, delete on public.%I to authenticated', table_name);
  end loop;
end;
$$;
