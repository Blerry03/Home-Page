begin;
create or replace function public.hq_create_calendar_intake(org uuid, customer_name text, customer_phone text, street text, service_city text, service_zip text, appointment jsonb)
returns uuid
language plpgsql security invoker set search_path = ''
as $$
declare
  customer_id uuid;
  service_property_id uuid;
  job_id uuid;
  draft public.jobs;
begin
  draft := jsonb_populate_record(null::public.jobs, appointment);
  if nullif(btrim(street),'') is null or nullif(btrim(service_city),'') is null
    or nullif(btrim(draft.title),'') is null or draft.scheduled_date is null then
    raise exception 'Enter a service address, job name, and appointment date.';
  end if;
  if draft.scheduled_end is not null and
    (draft.scheduled_start is null or draft.scheduled_end <= draft.scheduled_start) then
    raise exception 'End time must follow start time.';
  end if;
  if draft.client_id is null then
    if nullif(btrim(customer_name),'') is null or nullif(btrim(customer_phone),'') is null then
      raise exception 'Enter the new customer name and phone.';
    end if;
    insert into public.clients (organization_id,name,phone)
      values (org,btrim(customer_name),btrim(customer_phone)) returning id into customer_id;
  else
    select id into customer_id from public.clients where id=draft.client_id and organization_id=org;
    if customer_id is null then raise exception 'Choose a customer in this workspace.'; end if;
  end if;
  insert into public.properties (organization_id,client_id,label,address_line1,city,state,postal_code)
    values (org,customer_id,'Service property',btrim(street),btrim(service_city),
      'MI',coalesce(btrim(service_zip),'')) returning id into service_property_id;
  insert into public.jobs (organization_id,client_id,property_id,title,status,scheduled_date,
    scheduled_start,scheduled_end,lead_source,contact_method,salesperson,subcontractor,subcontract_direction,notes)
    values (org,customer_id,service_property_id,btrim(draft.title),coalesce(draft.status,'scheduled'),
      draft.scheduled_date,draft.scheduled_start,draft.scheduled_end,draft.lead_source,draft.contact_method,
      draft.salesperson,draft.subcontractor,draft.subcontract_direction,draft.notes) returning id into job_id;
  return job_id;
end;
$$;
revoke all on function public.hq_create_calendar_intake(uuid,text,text,text,text,text,jsonb) from public, anon;
grant execute on function public.hq_create_calendar_intake(uuid,text,text,text,text,text,jsonb) to authenticated;
commit;
