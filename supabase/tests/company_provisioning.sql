-- Company provisioning (migration 109): a company created from zero can run
-- real finance, inventory, and rental workflows, isolated from other tenants.
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- 1. Only service_role may provision companies.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform public.provision_company('{}'::jsonb);
  raise exception 'provision fail: manager executed provision_company';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role anon;
do $$
begin
  perform public.provision_company('{}'::jsonb);
  raise exception 'provision fail: anon executed provision_company';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2. Input validation.
-- ---------------------------------------------------------------------------
create or replace function pg_temp.provision_payload(
  p_slug text,
  p_owner uuid,
  p_overrides jsonb default '{}'::jsonb
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'name_ar', 'شركة اختبار التجهيز',
    'name_en', 'Provisioning Test Co',
    'slug', p_slug,
    'country_code', 'KW',
    'timezone', 'Asia/Kuwait',
    'default_locale', 'ar',
    'owner_user_id', p_owner,
    'owner_display_name', 'Provision Owner',
    'currency', jsonb_build_object(
      'iso_code', 'KWD',
      'major_name_ar', 'دينار', 'major_name_en', 'Kuwaiti dinar',
      'major_symbol_ar', 'د.ك', 'major_symbol_en', 'KWD',
      'minor_name_ar', 'فلس', 'minor_name_en', 'fils',
      'decimal_places', 3, 'minor_units_per_major', 1000,
      'symbol_position', 'after'
    )
  ) || p_overrides;
$$;

begin;
insert into auth.users (id, aud, role, email, created_at, updated_at)
values ('00000000-0000-0000-0000-00000000c001', 'authenticated', 'authenticated',
        'provision-validation@test.local', now(), now());
set local role service_role;
do $$
declare
  v_owner uuid := '00000000-0000-0000-0000-00000000c001';
  v_case record;
begin
  for v_case in
    select *
    from (
      values
        ('bad slug', pg_temp.provision_payload('Bad Slug', v_owner), 'validation_failed'),
        ('bad timezone', pg_temp.provision_payload('tz-co', v_owner, '{"timezone":"Mars/Base"}'), 'validation_failed'),
        ('bad country', pg_temp.provision_payload('cc-co', v_owner, '{"country_code":"KWT"}'), 'validation_failed'),
        ('4 decimals', pg_temp.provision_payload('dp-co', v_owner,
          jsonb_build_object('currency', pg_temp.provision_payload('x', v_owner) -> 'currency' || '{"decimal_places":4}')),
          'validation_failed'),
        ('taken slug', pg_temp.provision_payload('hayat-secret', v_owner), 'company_slug_taken'),
        ('missing owner', pg_temp.provision_payload('no-owner-co', gen_random_uuid()), 'owner_user_not_found'),
        ('owner in another company', pg_temp.provision_payload(
          'dup-owner-co', '00000000-0000-0000-0000-000000000201'), 'owner_already_member')
    ) as t(label, payload, expected)
  loop
    begin
      perform public.provision_company(v_case.payload);
      raise exception 'provision fail: % succeeded', v_case.label;
    exception
      when raise_exception then
        if sqlerrm <> v_case.expected then
          raise exception 'provision fail: % raised % (expected %)', v_case.label, sqlerrm, v_case.expected;
        end if;
    end;
  end loop;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 3. Fresh company: configuration, real workflows, balanced books, isolation.
-- ---------------------------------------------------------------------------
begin;

insert into auth.users (id, aud, role, email, created_at, updated_at)
values ('00000000-0000-0000-0000-00000000c002', 'authenticated', 'authenticated',
        'provision-owner@test.local', now(), now());

set local role service_role;
select set_config(
  'provision_test.tenant_id',
  public.provision_company(pg_temp.provision_payload(
    'provision-test-co', '00000000-0000-0000-0000-00000000c002'
  ))::text,
  true
);
reset role;

-- 3a. Configuration created for the new company.
do $$
declare
  v_tenant uuid := current_setting('provision_test.tenant_id')::uuid;
  v_missing text;
  v_count int;
begin
  if not exists (
    select 1 from public.tenants t
    join public.currencies c on c.id = t.default_currency_id
    where t.id = v_tenant and c.iso_code = 'KWD' and c.decimal_places = 3 and c.is_default
  ) then
    raise exception 'provision fail: default currency missing';
  end if;

  if not exists (select 1 from public.tenant_settings where tenant_id = v_tenant) then
    raise exception 'provision fail: tenant_settings missing';
  end if;

  select string_agg(expected.code, ',') into v_missing
  from unnest(array[
    '1000', '1101', '1102', '1151', '1160', '1201', '1301', '2000', '2101',
    '2150', '2151', '3000', '3101', '3102', '3201', '4000', '4101', '4102',
    '4901', '5000', '5101', '5151', '5152', '5901', '6101'
  ]) as expected(code)
  where not exists (
    select 1 from public.chart_of_accounts c
    where c.tenant_id = v_tenant and c.code = expected.code and c.is_system and c.is_active
  );
  if v_missing is not null then
    raise exception 'provision fail: missing accounts %', v_missing;
  end if;

  if exists (
    select 1 from public.chart_of_accounts c
    where c.tenant_id = v_tenant and c.code not in ('1000', '2000', '3000', '4000', '5000')
      and c.parent_id is null
  ) then
    raise exception 'provision fail: leaf account without parent';
  end if;

  select count(*) into v_count from public.inventory_adjustment_reasons where tenant_id = v_tenant;
  if v_count <> 8 then raise exception 'provision fail: % reasons', v_count; end if;

  if not exists (
    select 1 from public.inventory_adjustment_reasons r
    join public.chart_of_accounts c on c.id = r.account_id
    where r.tenant_id = v_tenant and r.code = 'found_surplus' and c.code = '4901'
  ) then
    raise exception 'provision fail: found_surplus not on 4901';
  end if;

  select count(*) into v_count from public.warehouses where tenant_id = v_tenant and type = 'main';
  if v_count <> 1 then raise exception 'provision fail: % main warehouses', v_count; end if;

  select count(*) into v_count from public.document_sequences where tenant_id = v_tenant;
  if v_count = 0 then raise exception 'provision fail: no document sequences'; end if;
  select count(*) into v_count from public.document_templates where tenant_id = v_tenant;
  if v_count = 0 then raise exception 'provision fail: no document templates'; end if;
  if not exists (select 1 from public.tenant_calendar_settings where tenant_id = v_tenant) then
    raise exception 'provision fail: calendar settings missing';
  end if;

  if not exists (
    select 1 from public.tenant_users
    where tenant_id = v_tenant
      and user_id = '00000000-0000-0000-0000-00000000c002'
      and account_type = 'manager' and is_active
  ) then
    raise exception 'provision fail: owner is not manager';
  end if;
end $$;

-- 3b. The new owner works inside the new company through normal RPCs.
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000c002';

do $$
declare
  v_tenant uuid := current_setting('provision_test.tenant_id')::uuid;
  v_owner uuid := '00000000-0000-0000-0000-00000000c002';
  v_wh uuid;
  v_cash uuid;
  v_group uuid;
  v_customer uuid;
  v_location uuid;
  v_product uuid;
  v_doc uuid;
  v_invoice uuid;
  v_gain numeric;
  v_revenue numeric;
  v_status text;
begin
  if public.current_tenant_id() is distinct from v_tenant then
    raise exception 'provision fail: owner resolves tenant %', public.current_tenant_id();
  end if;
  if (public.get_my_permissions() ->> 'is_manager')::boolean is distinct from true then
    raise exception 'provision fail: owner is not manager in session';
  end if;

  select id into v_wh from public.warehouses where tenant_id = v_tenant and type = 'main';
  select id into v_cash from public.chart_of_accounts where tenant_id = v_tenant and code = '1101';

  v_customer := public.create_customer(jsonb_build_object(
    'name_ar', 'عميل التجهيز', 'phone_primary', '+96550001234', 'create_account', true
  ));
  v_location := public.create_customer_service_location(v_customer, jsonb_build_object(
    'name', 'الفرع الرئيسي', 'location_type', 'branch',
    'governorate', 'Hawalli', 'area', 'Salmiya', 'contact_person_phone', '+96550001234'
  ));

  insert into public.product_groups (tenant_id, name_ar, name_en, created_by)
  values (v_tenant, 'عطور', 'Perfumes', v_owner)
  returning id into v_group;

  insert into public.products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    can_be_sold, can_be_rented, unit_primary, sale_price, created_by
  )
  values (
    v_tenant, 'PRV-SALE-1', 'عطر تجربة', 'Test perfume', v_group, 'sale_only',
    true, false, 'piece', 5.000, v_owner
  )
  returning id into v_product;

  -- Opening stock: Dr 1301 / Cr 3101.
  perform public.record_opening_stock(jsonb_build_object(
    'warehouse_id', v_wh, 'date', current_date, 'import_key', 'PRV-OPEN-1',
    'notes', 'Provisioning opening stock',
    'lines', jsonb_build_array(jsonb_build_object(
      'product_id', v_product, 'qty', 10, 'unit_cost', 2.000, 'line_order', 1))
  ), gen_random_uuid());

  -- Found surplus posts to the inventory gain account, not sales returns.
  v_doc := public.record_inventory_document(jsonb_build_object(
    'document_type', 'stock_in', 'warehouse_id', v_wh, 'date', current_date,
    'reason_code', 'found_surplus', 'notes', 'Provisioning found surplus',
    'lines', jsonb_build_array(jsonb_build_object(
      'product_id', v_product, 'qty', 2, 'line_order', 1))
  ), gen_random_uuid());

  select coalesce(sum(jl.credit), 0) into v_gain
  from public.inventory_documents d
  join public.journal_lines jl on jl.journal_entry_id = d.journal_entry_id
  join public.chart_of_accounts c on c.id = jl.account_id
  where d.id = v_doc and c.code = '4901';
  if v_gain <> 4.000 then raise exception 'provision fail: gain credit %', v_gain; end if;

  v_invoice := public.record_sales_invoice(jsonb_build_object(
    'customer_id', v_customer, 'warehouse_id', v_wh, 'date', current_date,
    'lines', jsonb_build_array(jsonb_build_object(
      'product_id', v_product, 'qty', 3, 'unit_price', 5.000,
      'discount_pct', 0, 'line_order', 1))
  ), gen_random_uuid());

  select coalesce(sum(jl.credit), 0) into v_revenue
  from public.invoices i
  join public.journal_lines jl on jl.journal_entry_id = i.journal_entry_id
  join public.chart_of_accounts c on c.id = jl.account_id
  where i.id = v_invoice and c.code = '4101';
  if v_revenue <> 15.000 then raise exception 'provision fail: revenue %', v_revenue; end if;

  perform public.record_receipt_voucher(jsonb_build_object(
    'customer_id', v_customer, 'date', current_date, 'amount', 15,
    'payment_method', 'cash', 'cash_account_id', v_cash,
    'allocation_mode', 'manual',
    'allocations', jsonb_build_array(jsonb_build_object(
      'invoice_id', v_invoice, 'allocated_amount', 15))
  ), gen_random_uuid());

  select status::text into v_status from public.invoices where id = v_invoice;
  if v_status <> 'paid' then raise exception 'provision fail: invoice status %', v_status; end if;

  perform set_config('provision_test.customer_id', v_customer::text, true);
  perform set_config('provision_test.location_id', v_location::text, true);
  perform set_config('provision_test.group_id', v_group::text, true);
end $$;

-- Serialized rental asset stock is seeded directly, as in the Phase 6 fixtures.
reset role;
do $$
declare
  v_tenant uuid := current_setting('provision_test.tenant_id')::uuid;
  v_wh uuid;
begin
  select id into v_wh from public.warehouses where tenant_id = v_tenant and type = 'main';

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    can_be_sold, can_be_rented, unit_primary, conversion_factor, sale_price,
    avg_cost, is_serialized, tax_class, created_by
  )
  values (
    '00000000-0000-0000-0000-00000000c101', v_tenant, 'PRV-AST-1', 'جهاز تجربة', 'Test diffuser',
    current_setting('provision_test.group_id')::uuid, 'asset_rental',
    true, true, 'piece', 1, 15.000, 45.000, true, 'non_taxable',
    '00000000-0000-0000-0000-00000000c002'
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    '00000000-0000-0000-0000-00000000c102', v_tenant,
    '00000000-0000-0000-0000-00000000c101', 'PRV-SN-1',
    'available_new', v_wh, 55.000, current_date
  );

  insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty_available)
  values (v_tenant, v_wh, '00000000-0000-0000-0000-00000000c101', 1);
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000c002';

do $$
declare
  v_tenant uuid := current_setting('provision_test.tenant_id')::uuid;
  v_cash uuid;
  v_contract uuid;
  v_result jsonb;
  v_unbalanced int;
begin
  select id into v_cash from public.chart_of_accounts where tenant_id = v_tenant and code = '1101';

  v_contract := public.create_rental_contract(jsonb_build_object(
    'customer_id', current_setting('provision_test.customer_id')::uuid,
    'service_location_id', current_setting('provision_test.location_id')::uuid,
    'start_date', current_date - 60,
    'monthly_rental_value', 25.000,
    'asset_lines', jsonb_build_array(jsonb_build_object(
      'product_id', '00000000-0000-0000-0000-00000000c101',
      'product_unit_id', '00000000-0000-0000-0000-00000000c102'))
  ), gen_random_uuid());

  v_result := public.collect_rental_payment(jsonb_build_object(
    'contract_id', v_contract, 'date', current_date, 'amount', 25.000,
    'payment_method', 'cash', 'cash_account_id', v_cash,
    'coverage_months', jsonb_build_array(to_char(date_trunc('month', current_date), 'YYYY-MM-DD'))
  ), gen_random_uuid());

  if v_result ->> 'invoice_id' is null or v_result ->> 'voucher_id' is null then
    raise exception 'provision fail: rental collection result %', v_result;
  end if;

  select count(*) into v_unbalanced
  from (
    select je.id
    from public.journal_entries je
    join public.journal_lines jl on jl.journal_entry_id = je.id
    where je.tenant_id = v_tenant
    group by je.id
    having sum(jl.debit) <> sum(jl.credit)
  ) u;
  if v_unbalanced <> 0 then
    raise exception 'provision fail: % unbalanced journal entries', v_unbalanced;
  end if;

  if (select count(*) from public.journal_entries where tenant_id = v_tenant) < 5 then
    raise exception 'provision fail: expected journal entries for every workflow';
  end if;
end $$;

-- 3c. Another company's manager cannot see the new company's data.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant uuid := current_setting('provision_test.tenant_id')::uuid;
begin
  if exists (select 1 from public.customers where tenant_id = v_tenant)
     or exists (select 1 from public.products where tenant_id = v_tenant)
     or exists (select 1 from public.chart_of_accounts where tenant_id = v_tenant) then
    raise exception 'provision fail: tenant A manager sees the new company';
  end if;
end $$;

rollback;

select 'company_provisioning: ok' as result;
