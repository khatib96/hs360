-- Phase 1D RLS verification.
-- Run after `supabase db reset`:
-- docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_1d_rls.sql

\set ON_ERROR_STOP on

-- Anonymous users must see no tenant data.
begin;
set local role anon;
do $$
declare
  v_count int;
begin
  select count(*) into v_count from products;
  if v_count <> 0 then
    raise exception 'anon products visibility failed: expected 0, got %', v_count;
  end if;
end $$;
rollback;

-- A zero-permission tenant user must see no products.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_count int;
begin
  select count(*) into v_count from products;
  if v_count <> 0 then
    raise exception 'zero-permission user products visibility failed: expected 0, got %', v_count;
  end if;
end $$;
rollback;

-- A user with products.view sees only their own tenant's product.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_count int;
  v_cross_tenant_count int;
begin
  select count(*) into v_count from products;
  select count(*) into v_cross_tenant_count
  from products
  where tenant_id = '00000000-0000-0000-0000-000000000102';

  if v_count <> 1 then
    raise exception 'products.view user visibility failed: expected 1 own product, got %', v_count;
  end if;

  if v_cross_tenant_count <> 0 then
    raise exception 'tenant isolation failed: products.view user saw % tenant B products', v_cross_tenant_count;
  end if;
end $$;
rollback;

-- The same user has products.create and can insert inside their tenant.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_group_id uuid := '00000000-0000-0000-0000-000000000802';
  v_inserted_id uuid;
begin
  insert into products (
    tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, is_serialized
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'RLS-' || left(gen_random_uuid()::text, 8),
    'اختبار RLS',
    'RLS Test Product',
    v_group_id,
    'consumable_rental',
    'ml',
    1,
    1.000,
    0.500,
    false
  )
  returning id into v_inserted_id;

  if v_inserted_id is null then
    raise exception 'products.create verification failed: insert returned null id';
  end if;
end $$;
rollback;

-- A field user must be blocked from direct journal entry inserts.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $$
begin
  insert into journal_entries (
    tenant_id, entry_number, date, source, description_en
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'RLS-JE-001',
    current_date,
    'manual',
    'Should be blocked'
  );

  raise exception 'journal insert verification failed: insert unexpectedly succeeded';
exception
  when insufficient_privilege or check_violation or with_check_option_violation then
    null;
end $$;
rollback;

-- A manager bypasses explicit grants through user_has_permission().
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_count int;
  v_can_view_audit boolean;
begin
  select count(*) into v_count from products;
  select user_has_permission('audit_log.view') into v_can_view_audit;

  if v_count < 1 then
    raise exception 'manager visibility failed: expected at least 1 product, got %', v_count;
  end if;

  if not v_can_view_audit then
    raise exception 'manager permission bypass failed for audit_log.view';
  end if;
end $$;
rollback;

select 'phase_1d_rls_verification_passed' as result;
