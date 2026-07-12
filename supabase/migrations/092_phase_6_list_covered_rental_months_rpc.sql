-- Phase 6 M13: read-only covered rental months for collection UI.
-- SECURITY DEFINER bridge for collect/preview users blocked by rental_invoice_coverages RLS.

create or replace function public.list_covered_rental_months(p_contract_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_contract public.contracts%rowtype;
  v_keys jsonb;
begin
  if p_contract_id is null then
    raise exception 'validation_failed';
  end if;

  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not (
    public.is_manager()
    or public.user_has_permission('vouchers.create_receipt')
    or public.user_has_permission('invoices.create_sales')
    or public.user_has_permission('invoices.view_sales')
  ) then
    raise exception 'permission_denied';
  end if;

  select * into v_contract
  from public.contracts c
  where c.id = p_contract_id
    and c.tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_contract.type <> 'rental'::public.contract_type then
    raise exception 'validation_failed';
  end if;

  select coalesce(
    jsonb_agg(to_jsonb(ric.coverage_month_key::text) order by ric.coverage_month_key),
    '[]'::jsonb
  )
  into v_keys
  from public.rental_invoice_coverages ric
  where ric.tenant_id = v_tenant_id
    and ric.contract_id = p_contract_id;

  return jsonb_build_object(
    'contract_id', p_contract_id,
    'coverage_month_keys', v_keys
  );
end;
$$;

comment on function public.list_covered_rental_months(uuid) is
  'M13: Returns covered rental month keys for a contract. Month keys only; no financial fields.';

revoke all on function public.list_covered_rental_months(uuid) from public, anon;
grant execute on function public.list_covered_rental_months(uuid) to authenticated;
