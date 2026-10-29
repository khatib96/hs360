-- Rental collection cancel + rental arrears (migration 112).
\set ON_ERROR_STOP on

-- Fixture copied from phase_6_rental_collection_billing_engine.sql.
create or replace function pg_temp.rc_fixture(p_create_rental boolean default true)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_main_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_customer uuid;
  v_location uuid;
  v_asset_product uuid := gen_random_uuid();
  v_asset_unit uuid := gen_random_uuid();
  v_contract uuid;
  v_cash_account uuid;
begin
  v_customer := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل إلغاء التحصيل',
      'phone_primary', '+96550009101',
      'create_account', true
    )
  );

  v_location := public.create_customer_service_location(
    v_customer,
    jsonb_build_object(
      'name', 'موقع إلغاء التحصيل',
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550009101'
    )
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    can_be_sold, can_be_rented, unit_primary, conversion_factor, sale_price,
    avg_cost, is_serialized, tax_class, created_by
  )
  values (
    v_asset_product, v_tenant, 'RC-AST-' || left(v_asset_product::text, 8),
    'جهاز M5', 'M5 Asset', v_devices_group, 'asset_rental',
    true, true, 'piece', 1, 15.000,
    45.000, true, 'non_taxable', v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    v_asset_unit, v_tenant, v_asset_product, 'RC-SN-' || left(v_asset_unit::text, 8),
    'available_new', v_main_wh, 55.000, current_date
  );

  insert into public.inventory_balances (
    tenant_id, warehouse_id, product_id, qty_available
  )
  values (v_tenant, v_main_wh, v_asset_product, 1)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  if p_create_rental then
    v_contract := public.create_rental_contract(
      jsonb_build_object(
        'customer_id', v_customer,
        'service_location_id', v_location,
        'start_date', current_date - 60,
        'monthly_rental_value', 25.000,
        'asset_lines', jsonb_build_array(
          jsonb_build_object(
            'product_id', v_asset_product,
            'product_unit_id', v_asset_unit
          )
        )
      ),
      gen_random_uuid()
    );
  end if;

  select id into v_cash_account
  from public.chart_of_accounts
  where tenant_id = v_tenant
    and code = '1101'
  limit 1;

  if v_cash_account is null then
    raise exception 'fixture failed: cash account 1101 missing';
  end if;

  return jsonb_build_object(
    'tenant_id', v_tenant,
    'customer_id', v_customer,
    'service_location_id', v_location,
    'asset_product_id', v_asset_product,
    'asset_unit_id', v_asset_unit,
    'contract_id', v_contract,
    'cash_account_id', v_cash_account
  );
end;
$$;

create or replace function pg_temp.rc_arrears_for(p_contract uuid, p_as_of date)
returns jsonb
language sql
as $$
  select coalesce((
    select item
    from jsonb_array_elements(public.list_rental_arrears(p_as_of) -> 'items') item
    where (item ->> 'contract_id')::uuid = p_contract
  ), '{"months_count": 0, "amount": 0}'::jsonb);
$$;

-- ---------------------------------------------------------------------------
-- 1. Arrears, collection, full cancel, months released, re-collection.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.rc_fixture();
  v_contract uuid := (v_fixture ->> 'contract_id')::uuid;
  v_cash uuid := (v_fixture ->> 'cash_account_id')::uuid;
  v_month text := to_char(date_trunc('month', current_date), 'YYYY-MM-DD');
  v_as_of date := (date_trunc('month', current_date) + interval '1 month - 1 day')::date;
  v_start date;
  v_expected int;
  v_arrears jsonb;
  v_collect jsonb;
  v_cancel jsonb;
  v_invoice uuid;
  v_voucher uuid;
  v_invoice_je uuid;
  v_reversal_je uuid;
  v_net numeric;
  v_unbalanced int;
begin
  select start_date into v_start from public.contracts where id = v_contract;
  v_expected := (extract(year from age(date_trunc('month', current_date), date_trunc('month', v_start))) * 12
    + extract(month from age(date_trunc('month', current_date), date_trunc('month', v_start))))::int + 1;

  v_arrears := pg_temp.rc_arrears_for(v_contract, v_as_of);
  if (v_arrears ->> 'months_count')::int <> v_expected
     or (v_arrears ->> 'amount')::numeric <> 25.000 * v_expected then
    raise exception 'rc fail: initial arrears % (expected % months)', v_arrears, v_expected;
  end if;

  v_collect := public.collect_rental_payment(jsonb_build_object(
    'contract_id', v_contract, 'date', current_date, 'amount', 25.000,
    'payment_method', 'cash', 'cash_account_id', v_cash,
    'coverage_months', jsonb_build_array(v_month)
  ), gen_random_uuid());
  v_invoice := (v_collect ->> 'invoice_id')::uuid;
  v_voucher := (v_collect ->> 'voucher_id')::uuid;

  v_arrears := pg_temp.rc_arrears_for(v_contract, v_as_of);
  if (v_arrears ->> 'months_count')::int <> v_expected - 1
     or v_arrears -> 'months' ? v_month then
    raise exception 'rc fail: arrears after collection %', v_arrears;
  end if;

  v_cancel := public.cancel_rental_collection(v_invoice, 'Wrong contract', gen_random_uuid());
  if v_cancel -> 'released_months' <> jsonb_build_array(v_month) then
    raise exception 'rc fail: released %', v_cancel;
  end if;

  if (select status::text from public.invoices where id = v_invoice) <> 'cancelled'
     or (select status::text from public.vouchers where id = v_voucher) <> 'cancelled' then
    raise exception 'rc fail: invoice/voucher not cancelled';
  end if;

  select journal_entry_id, reversal_journal_entry_id into v_invoice_je, v_reversal_je
  from public.invoices where id = v_invoice;
  select coalesce(sum(debit - credit), 0) into v_net
  from (
    select jl.account_id, sum(jl.debit) as debit, sum(jl.credit) as credit
    from public.journal_lines jl
    where jl.journal_entry_id in (v_invoice_je, v_reversal_je)
    group by jl.account_id
    having sum(jl.debit) <> sum(jl.credit)
  ) nets;
  if v_reversal_je is null or exists (
    select 1 from public.journal_lines jl
    where jl.journal_entry_id in (v_invoice_je, v_reversal_je)
    group by jl.account_id
    having sum(jl.debit) <> sum(jl.credit)
  ) then
    raise exception 'rc fail: invoice journal not fully reversed';
  end if;

  select count(*) into v_unbalanced
  from (
    select je.id from public.journal_entries je
    join public.journal_lines jl on jl.journal_entry_id = je.id
    where je.tenant_id = '00000000-0000-0000-0000-000000000101'
    group by je.id having sum(jl.debit) <> sum(jl.credit)
  ) u;
  if v_unbalanced <> 0 then
    raise exception 'rc fail: % unbalanced journal entries', v_unbalanced;
  end if;

  if (pg_temp.rc_arrears_for(v_contract, v_as_of) ->> 'months_count')::int <> v_expected then
    raise exception 'rc fail: month not released into arrears';
  end if;

  perform set_config('rc.audit_invoice', v_invoice::text, true);

  if (
    select item ->> 'status'
    from jsonb_array_elements(public.list_contract_rental_collections(v_contract)) item
    where (item ->> 'invoice_id')::uuid = v_invoice
  ) is distinct from 'cancelled' then
    raise exception 'rc fail: collections list does not show the cancellation';
  end if;

  -- The released month can be collected again.
  v_collect := public.collect_rental_payment(jsonb_build_object(
    'contract_id', v_contract, 'date', current_date, 'amount', 25.000,
    'payment_method', 'cash', 'cash_account_id', v_cash,
    'coverage_months', jsonb_build_array(v_month)
  ), gen_random_uuid());
  if v_collect ->> 'invoice_id' is null then
    raise exception 'rc fail: re-collection failed';
  end if;
end $$;
-- audit_log is not directly readable by API users; check it as the owner role.
reset role;
do $$
begin
  if not exists (
    select 1 from public.audit_log
    where entity_id = current_setting('rc.audit_invoice')::uuid
      and action = 'rental_collection_cancel'
      and reason = 'Wrong contract'
      and actor_id = '00000000-0000-0000-0000-000000000201'
  ) then
    raise exception 'rc fail: cancellation not audited';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2. Idempotency, validation, permissions, locked books.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.rc_fixture();
  v_collect jsonb;
  v_invoice uuid;
  v_key uuid := gen_random_uuid();
begin
  v_collect := public.collect_rental_payment(jsonb_build_object(
    'contract_id', v_fixture ->> 'contract_id', 'date', current_date, 'amount', 25.000,
    'payment_method', 'cash', 'cash_account_id', v_fixture ->> 'cash_account_id',
    'coverage_months', jsonb_build_array(to_char(date_trunc('month', current_date), 'YYYY-MM-DD'))
  ), gen_random_uuid());
  v_invoice := (v_collect ->> 'invoice_id')::uuid;
  perform set_config('rc.invoice', v_invoice::text, true);

  begin
    perform public.cancel_rental_collection(v_invoice, '  ', gen_random_uuid());
    raise exception 'rc fail: blank reason accepted';
  exception when raise_exception then
    if sqlerrm <> 'validation_failed' then raise; end if;
  end;

  perform public.cancel_rental_collection(v_invoice, 'Duplicate entry', v_key);
  -- Same key, same reason: replay without error.
  perform public.cancel_rental_collection(v_invoice, 'Duplicate entry', v_key);

  begin
    perform public.cancel_rental_collection(v_invoice, 'Other reason', v_key);
    raise exception 'rc fail: key reuse with another reason accepted';
  exception when raise_exception then
    if sqlerrm <> 'idempotency_payload_mismatch' then raise; end if;
  end;

  begin
    perform public.cancel_rental_collection(v_invoice, 'Again', gen_random_uuid());
    raise exception 'rc fail: second cancellation accepted';
  exception when raise_exception then
    if sqlerrm <> 'validation_failed' then raise; end if;
  end;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  perform public.cancel_rental_collection(current_setting('rc.invoice')::uuid, 'x', gen_random_uuid());
  raise exception 'rc fail: user without cancel permissions cancelled';
exception when raise_exception then
  if sqlerrm <> 'permission_denied' then raise; end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
begin
  perform public.list_rental_arrears(null);
  raise exception 'rc fail: zero-permission user read arrears';
exception when raise_exception then
  if sqlerrm <> 'permission_denied' then raise; end if;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_fixture jsonb := pg_temp.rc_fixture();
  v_invoice uuid;
begin
  v_invoice := (public.collect_rental_payment(jsonb_build_object(
    'contract_id', v_fixture ->> 'contract_id', 'date', current_date, 'amount', 25.000,
    'payment_method', 'cash', 'cash_account_id', v_fixture ->> 'cash_account_id',
    'coverage_months', jsonb_build_array(to_char(date_trunc('month', current_date), 'YYYY-MM-DD'))
  ), gen_random_uuid()) ->> 'invoice_id')::uuid;
  perform set_config('rc.invoice', v_invoice::text, true);
end $$;
reset role;
update public.tenant_settings set books_locked_through = current_date
where tenant_id = '00000000-0000-0000-0000-000000000101';
set local role authenticated;
do $$
begin
  perform public.cancel_rental_collection(current_setting('rc.invoice')::uuid, 'Late fix', gen_random_uuid());
  raise exception 'rc fail: cancellation inside locked books';
exception when raise_exception then
  if sqlerrm <> 'books_locked' then raise; end if;
end $$;
rollback;

select 'rental_collection_cancel_and_arrears: ok' as result;
