-- M9 voucher usability: source accounts on receipt/payment vouchers are not
-- limited to cash/bank accounts. The UI still defaults to 1101 and keeps
-- invoice cash settlement narrow, but vouchers may post from/to any active
-- posting leaf account that is not entity-linked.

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
end;
$$;

comment on function public.validate_cash_bank_account(uuid, uuid) is
  'M9: Validates voucher source posting leaf account; invoices remain narrowed client-side.';

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
end;
$$;

comment on function public.validate_direct_payment_account(uuid, uuid, uuid) is
  'M9: Validates direct voucher counter-account; any active non-entity posting leaf is allowed except the same source account.';
