-- Phase 6 M1: contract settings, permissions, and schema hardening verification.
-- Run after `supabase db reset`:
-- docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_6_contract_settings_permissions.sql

\set ON_ERROR_STOP on

-- 1. tenant_settings contract columns exist with defaults on seed tenant A.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_row public.tenant_settings%rowtype;
begin
  select * into v_row
  from public.tenant_settings
  where tenant_id = v_tenant_a;

  if v_row.rental_asset_cost_basis is distinct from 'unit_purchase_cost'::public.rental_asset_cost_basis then
    raise exception 'case1 failed: rental_asset_cost_basis default';
  end if;

  if v_row.rental_consumable_cost_basis is distinct from 'product_sale_price'::public.rental_consumable_cost_basis then
    raise exception 'case1 failed: rental_consumable_cost_basis default';
  end if;

  if v_row.default_contract_term_months <> 12 then
    raise exception 'case1 failed: default_contract_term_months default';
  end if;

  if v_row.first_rental_invoice_policy is distinct from 'first_billing_day'::public.first_rental_invoice_policy then
    raise exception 'case1 failed: first_rental_invoice_policy default';
  end if;

  if v_row.record_trial_usage_facts is distinct from true then
    raise exception 'case1 failed: record_trial_usage_facts default';
  end if;

  if v_row.track_rental_depreciation is distinct from false then
    raise exception 'case1 failed: track_rental_depreciation default';
  end if;

  if v_row.allow_multi_asset_contracts is distinct from true then
    raise exception 'case1 failed: allow_multi_asset_contracts default';
  end if;

  if v_row.allow_multi_consumable_contracts is distinct from true then
    raise exception 'case1 failed: allow_multi_consumable_contracts default';
  end if;
end $$;
rollback;

-- 2. Valid tenant_settings updates succeed without disabling triggers.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  update public.tenant_settings
  set
    rental_asset_cost_basis = 'product_avg_cost',
    rental_consumable_cost_basis = 'product_avg_cost',
    default_contract_term_months = 24,
    first_rental_invoice_policy = 'manual',
    record_trial_usage_facts = false
  where tenant_id = v_tenant_a;

  if not found then
    raise exception 'case2 failed: tenant_settings row missing';
  end if;
end $$;
rollback;

-- 3. Invalid setting values fail.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  begin
    update public.tenant_settings
    set default_contract_term_months = 0
    where tenant_id = v_tenant_a;
    raise exception 'case3a failed: zero default_contract_term_months accepted';
  exception
    when check_violation then null;
  end;

  begin
    update public.tenant_settings
    set default_contract_term_months = 121
    where tenant_id = v_tenant_a;
    raise exception 'case3b failed: oversized default_contract_term_months accepted';
  exception
    when check_violation then null;
  end;

  begin
    perform 'invalid_basis'::public.rental_asset_cost_basis;
    raise exception 'case3c failed: invalid rental_asset_cost_basis cast accepted';
  exception
    when invalid_text_representation then null;
  end;
end $$;
rollback;

-- 3d. snapshot_asset_lifespan_months check on contracts.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer_id uuid;
  v_contract_id uuid := gen_random_uuid();
begin
  v_customer_id := create_customer(
    '{"name_ar":"عميل عمر العقد","phone_primary":"+96550006601"}'::jsonb
  );

  insert into public.contracts (
    id, tenant_id, contract_number, type, status, customer_id, contact_phone,
    start_date, monthly_rental_value
  )
  values (
    v_contract_id, v_tenant_a, 'P6M1-LIFE-001', 'rental', 'draft', v_customer_id,
    '+96550006601', current_date, 0
  );

  begin
    update public.contracts
    set snapshot_asset_lifespan_months = 0
    where id = v_contract_id;
    raise exception 'case3d failed: zero snapshot_asset_lifespan_months accepted';
  exception
    when check_violation then null;
  end;

  begin
    update public.contracts
    set snapshot_asset_lifespan_months = 601
    where id = v_contract_id;
    raise exception 'case3e failed: oversized snapshot_asset_lifespan_months accepted';
  exception
    when check_violation then null;
  end;
end $$;
rollback;

-- 4. Seven new contract permissions exist.
begin;
do $$
declare
  v_missing text[];
begin
  select array_agg(p.id)
  into v_missing
  from (
    values
      ('contracts.close'),
      ('contracts.approve_override'),
      ('contracts.convert_trial'),
      ('contracts.extend_trial'),
      ('contracts.return_trial'),
      ('contracts.print'),
      ('contracts.field.snapshot_total_cost')
  ) as p(id)
  where not exists (
    select 1 from public.permissions x where x.id = p.id
  );

  if v_missing is not null then
    raise exception 'case4 failed: missing permissions %', v_missing;
  end if;
end $$;
rollback;

-- 5. Manager bypasses explicit grant for contracts.close.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_can_close boolean;
begin
  select public.user_has_permission('contracts.close') into v_can_close;
  if not v_can_close then
    raise exception 'case5 failed: manager lacks contracts.close';
  end if;
end $$;
rollback;

-- 6. Lifecycle and pricing snapshot columns exist on contracts.
begin;
do $$
declare
  v_count int;
  v_comment text;
begin
  select count(*)::int into v_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'contracts'
    and column_name in (
      'converted_from_contract_id',
      'converted_to_contract_id',
      'renewed_from_contract_id',
      'renewed_to_contract_id',
      'extension_reason',
      'returned_at',
      'returned_by',
      'return_condition',
      'return_reason',
      'snapshot_asset_cost_basis',
      'snapshot_consumable_cost_basis',
      'snapshot_asset_lifespan_months'
    );

  if v_count <> 12 then
    raise exception 'case6 failed: expected 12 contract columns, got %', v_count;
  end if;

  select col_description(
    'public.contracts'::regclass,
    attnum
  )
  into v_comment
  from pg_attribute
  where attrelid = 'public.contracts'::regclass
    and attname = 'return_condition'
    and not attisdropped;

  if v_comment is null or position('summary' in lower(v_comment)) = 0 then
    raise exception 'case6 failed: return_condition summary comment missing';
  end if;
end $$;
rollback;

-- 7. contract_lines.snapshot_cost_basis with line-type enforcement.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer_id uuid;
  v_contract_id uuid := gen_random_uuid();
  v_asset_product uuid := '00000000-0000-0000-0000-000000000901';
  v_consumable_product uuid := gen_random_uuid();
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_asset_line uuid := gen_random_uuid();
  v_consumable_line uuid := gen_random_uuid();
begin
  v_customer_id := create_customer(
    '{"name_ar":"عميل بنود العقد","phone_primary":"+96550006602"}'::jsonb
  );

  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, is_serialized
  )
  values (
    v_consumable_product, v_tenant_a, 'P6M1-OIL-001', 'زيت تجريبي', 'Trial Oil',
    v_oils_group, 'consumable_rental', 'ml', 1, 5, 2, false
  );

  insert into public.contracts (
    id, tenant_id, contract_number, type, status, customer_id, contact_phone,
    start_date, monthly_rental_value
  )
  values (
    v_contract_id, v_tenant_a, 'P6M1-LINE-001', 'rental', 'draft', v_customer_id,
    '+96550006602', current_date, 0
  );

  insert into public.contract_lines (
    id, tenant_id, contract_id, line_type, product_id, snapshot_unit_cost,
    snapshot_monthly_cost, line_order
  )
  values
    (
      v_asset_line, v_tenant_a, v_contract_id, 'asset', v_asset_product,
      1, 1, 1
    ),
    (
      v_consumable_line, v_tenant_a, v_contract_id, 'consumable', v_consumable_product,
      1, 1, 2
    );

  begin
    update public.contract_lines
    set snapshot_cost_basis = 'product_last_purchase_cost'
    where id = v_asset_line;
    raise exception 'case7a failed: consumable basis accepted on asset line';
  exception
    when check_violation then null;
  end;

  begin
    update public.contract_lines
    set snapshot_cost_basis = 'unit_purchase_cost'
    where id = v_consumable_line;
    raise exception 'case7b failed: asset basis accepted on consumable line';
  exception
    when check_violation then null;
  end;

  update public.contract_lines
  set snapshot_cost_basis = 'unit_purchase_cost'
  where id = v_asset_line;

  update public.contract_lines
  set snapshot_cost_basis = 'product_sale_price'
  where id = v_consumable_line;
end $$;
rollback;

-- 8. Rental invoice billing period columns and duplicate prevention.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer_id uuid;
  v_contract_id uuid := gen_random_uuid();
begin
  v_customer_id := create_customer(
    '{"name_ar":"عميل فواتير الإيجار","phone_primary":"+96550006603"}'::jsonb
  );

  insert into public.contracts (
    id, tenant_id, contract_number, type, status, customer_id, contact_phone,
    start_date, monthly_rental_value
  )
  values (
    v_contract_id, v_tenant_a, 'P6M1-INV-001', 'rental', 'active', v_customer_id,
    '+96550006603', current_date, 25
  );
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer_id uuid;
  v_contract_id uuid;
  v_period_start date := date '2026-07-01';
  v_period_end date := date '2026-07-31';
  v_col_count int;
  v_index_exists boolean;
begin
  select count(*)::int into v_col_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'invoices'
    and column_name in ('billing_period_start', 'billing_period_end');

  if v_col_count <> 2 then
    raise exception 'case8 failed: billing period columns missing';
  end if;

  select exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'ux_invoices_rental_contract_period'
  ) into v_index_exists;

  if not v_index_exists then
    raise exception 'case8 failed: ux_invoices_rental_contract_period missing';
  end if;

  select c.id, c.customer_id
  into v_contract_id, v_customer_id
  from public.contracts c
  where c.tenant_id = v_tenant_a
    and c.contract_number = 'P6M1-INV-001';

  if v_contract_id is null then
    raise exception 'case8 failed: setup contract missing';
  end if;

  insert into public.invoices (
    tenant_id, invoice_number, type, status, customer_id, contract_id, date,
    subtotal, total, billing_period_start, billing_period_end,
    confirmed_at, confirmed_by
  )
  values (
    v_tenant_a, 'RM-P6M1-001', 'rental_monthly', 'confirmed', v_customer_id,
    v_contract_id, current_date, 25, 25, v_period_start, v_period_end,
    now(), '00000000-0000-0000-0000-000000000201'
  );

  begin
    insert into public.invoices (
      tenant_id, invoice_number, type, status, customer_id, contract_id, date,
      subtotal, total, billing_period_start, billing_period_end,
      confirmed_at, confirmed_by
    )
    values (
      v_tenant_a, 'RM-P6M1-002', 'rental_monthly', 'confirmed', v_customer_id,
      v_contract_id, current_date, 25, 25, v_period_start, v_period_end,
      now(), '00000000-0000-0000-0000-000000000201'
    );
    raise exception 'case8 failed: duplicate rental period insert succeeded';
  exception
    when unique_violation then null;
  end;

  insert into public.invoices (
    tenant_id, invoice_number, type, status, customer_id, contract_id, date,
    subtotal, total, billing_period_start, billing_period_end,
    cancelled_at, cancelled_by, cancellation_reason
  )
  values (
    v_tenant_a, 'RM-P6M1-003', 'rental_monthly', 'cancelled', v_customer_id,
    v_contract_id, current_date, 25, 25, v_period_start, v_period_end,
    now(), '00000000-0000-0000-0000-000000000201', 'test duplicate allowance'
  );
end $$;
rollback;

-- 9. track_rental_depreciation reserved; no contract depreciation posting in M1.
begin;
do $$
declare
  v_deprec_fn_count int;
begin
  if exists (
    select 1
    from public.tenant_settings
    where tenant_id = '00000000-0000-0000-0000-000000000101'
      and track_rental_depreciation is distinct from false
  ) then
    raise exception 'case9 failed: track_rental_depreciation default not false';
  end if;

  select count(*)::int into v_deprec_fn_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prokind = 'f'
    and (
      p.proname ilike '%contract%deprec%'
      or p.proname ilike '%deprec%contract%'
      or p.proname ilike '%rental%deprec%'
    );

  if v_deprec_fn_count > 0 then
    raise exception 'case9 failed: unexpected contract depreciation functions (count=%)', v_deprec_fn_count;
  end if;
end $$;
rollback;

-- 10. Cross-tenant converted_from_contract_id rejected by composite FK.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';
  v_customer_b uuid;
  v_source_contract uuid := gen_random_uuid();
begin
  v_customer_b := create_customer(
    '{"name_ar":"عميل ب","phone_primary":"+96550006605"}'::jsonb
  );

  insert into public.contracts (
    id, tenant_id, contract_number, type, status, customer_id, contact_phone,
    start_date, monthly_rental_value
  )
  values (
    v_source_contract, v_tenant_b, 'P6M1-XSRC-001', 'trial', 'active',
    v_customer_b, '+96550006605', current_date, 0
  );
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer_a uuid;
  v_target_contract uuid := gen_random_uuid();
begin
  v_customer_a := create_customer(
    '{"name_ar":"عميل أ","phone_primary":"+96550006604"}'::jsonb
  );

  insert into public.contracts (
    id, tenant_id, contract_number, type, status, customer_id, contact_phone,
    start_date, monthly_rental_value
  )
  values (
    v_target_contract, v_tenant_a, 'P6M1-XDST-001', 'rental', 'draft',
    v_customer_a, '+96550006604', current_date, 25
  );
end $$;
reset role;
do $$
declare
  v_source_contract uuid;
  v_target_contract uuid;
begin
  select id into v_source_contract
  from public.contracts
  where tenant_id = '00000000-0000-0000-0000-000000000102'
    and contract_number = 'P6M1-XSRC-001';

  select id into v_target_contract
  from public.contracts
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and contract_number = 'P6M1-XDST-001';

  if v_source_contract is null or v_target_contract is null then
    raise exception 'case10 failed: setup contracts missing';
  end if;

  begin
    update public.contracts
    set converted_from_contract_id = v_source_contract
    where id = v_target_contract;
    raise exception 'case10 failed: cross-tenant converted_from_contract_id accepted';
  exception
    when foreign_key_violation then null;
  end;
end $$;
rollback;

select 'phase_6_contract_settings_permissions_verification_passed' as result;
