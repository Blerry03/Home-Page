begin;
create function public.hq_create_billing_draft(org uuid, header jsonb, lines jsonb)
returns uuid language plpgsql security invoker set search_path = ''
as $$
declare
  draft public.documents;
  line public.document_items;
  new_id uuid;
  subtotal numeric;
  discount numeric;
  taxable numeric;
  total numeric := 0;
begin
  draft := jsonb_populate_record(null::public.documents, header);
  if jsonb_typeof(lines) is distinct from 'array' then
    raise exception 'Add at least one line item.';
  end if;
  if jsonb_array_length(lines) = 0 then raise exception 'Add at least one line item.'; end if;
  insert into public.documents (organization_id,client_id,property_id,job_id,kind,number,title,amount,status,
    recipient_contact_id,recipient_email,issue_date,due_date,purchase_order,contract_terms,notes)
  values (org,draft.client_id,draft.property_id,draft.job_id,draft.kind,draft.number,draft.title,0,'draft',
    draft.recipient_contact_id,draft.recipient_email,draft.issue_date,draft.due_date,draft.purchase_order,draft.contract_terms,draft.notes)
  returning id into new_id;
  for line in select * from jsonb_populate_recordset(null::public.document_items, lines)
  loop
    subtotal := round(line.quantity * line.unit_price,2);
    if line.discount_type = 'percent' and line.discount_value > 100 then
      raise exception 'Percentage discount cannot exceed 100.';
    end if;
    discount := case when line.discount_type = 'percent'
      then round(subtotal * line.discount_value / 100,2) else line.discount_value end;
    if discount > subtotal then raise exception 'Discount cannot exceed the line subtotal.'; end if;
    taxable := subtotal - discount;
    total := total + taxable + round(taxable * line.tax_rate / 100,2);
    insert into public.document_items (organization_id,document_id,item_name,description,quantity,unit,
      unit_price,tax_rate,discount_type,discount_value)
    values (org,new_id,line.item_name,line.description,line.quantity,line.unit,
      line.unit_price,line.tax_rate,line.discount_type,line.discount_value);
  end loop;
  update public.documents set amount=total where id=new_id and organization_id=org;
  return new_id;
end;
$$;
revoke all on function public.hq_create_billing_draft(uuid,jsonb,jsonb) from public, anon;
grant execute on function public.hq_create_billing_draft(uuid,jsonb,jsonb) to authenticated;
commit;
