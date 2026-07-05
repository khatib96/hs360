-- M10 hardening: keep the M9 voucher source-account generalization while
-- preventing direct vouchers from posting against protected system accounts.

create or replace function public.validate_cash_bank_account(
  p_tenant_id uuid,
  p_account_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_acct public.chart_of_accounts%rowtype;
begin
  if p_account_id is null then
    raise exception 'validation_failed';
  end if;

  select * into v_acct
  from public.chart_of_accounts
  where id = p_account_id;

  if not found or v_acct.tenant_id <> p_tenant_id then
    raise exception 'cross_tenant_reference';
  end if;

  if not v_acct.is_active or v_acct.related_entity_id is not null then
    raise exception 'validation_failed';
  end if;

  perform public.assert_account_is_posting_leaf(p_tenant_id, p_account_id);

  if public.is_reserved_tax_account_code(v_acct.code) then
    raise exception 'validation_failed';
  end if;

  if v_acct.code in ('1201', '2101', '1301') then
    raise exception 'validation_failed';
  end if;
end;
$$;

comment on function public.validate_cash_bank_account(uuid, uuid) is
  'M10: Validates voucher source posting leaf account; rejects protected control, inventory, and tax accounts.';

create or replace function public.validate_direct_payment_account(
  p_tenant_id uuid,
  p_account_id uuid,
  p_cash_account_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_acct public.chart_of_accounts%rowtype;
  v_inventory_id uuid;
begin
  if p_account_id is null or p_cash_account_id is null then
    raise exception 'validation_failed';
  end if;

  if p_account_id = p_cash_account_id then
    raise exception 'validation_failed';
  end if;

  select * into v_acct
  from public.chart_of_accounts
  where id = p_account_id;

  if not found or v_acct.tenant_id <> p_tenant_id then
    raise exception 'cross_tenant_reference';
  end if;

  if not v_acct.is_active or v_acct.related_entity_id is not null then
    raise exception 'validation_failed';
  end if;

  perform public.assert_account_is_posting_leaf(p_tenant_id, p_account_id);

  begin
    v_inventory_id := public.resolve_system_inventory_account(p_tenant_id);
    if p_account_id = v_inventory_id then
      raise exception 'validation_failed';
    end if;
  exception
    when undefined_function then
      null;
  end;

  if public.is_reserved_tax_account_code(v_acct.code) then
    raise exception 'validation_failed';
  end if;

  if v_acct.code in ('1101', '1102', '1201', '2101', '1301') then
    raise exception 'validation_failed';
  end if;
end;
$$;

comment on function public.validate_direct_payment_account(uuid, uuid, uuid) is
  'M10: Validates direct voucher counter-account; rejects source, cash/bank, AR/AP, inventory, tax, and entity-linked accounts.';
