\set ON_ERROR_STOP on

select set_config('p6m13.tag', :'tag', false);

set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_tag text := current_setting('p6m13.tag');
  v_customer_id uuid;
  v_location_id uuid;
begin
  v_customer_id := public.create_customer(
    jsonb_build_object(
      'name_ar', 'عميل P6M13 يدوي ' || v_tag,
      'name_en', 'P6M13 Manual ' || v_tag,
      'phone_primary', '+965500093' || lpad(
        (abs(hashtext(v_tag)) % 100)::text,
        2,
        '0'
      ),
      'create_account', true
    )
  );
  v_location_id := public.create_customer_service_location(
    v_customer_id,
    jsonb_build_object(
      'name', 'موقع P6M13 يدوي ' || v_tag,
      'location_type', 'branch',
      'governorate', 'Hawalli',
      'area', 'Salmiya',
      'contact_person_phone', '+96550009301'
    )
  );

  perform set_config('p6m13.manual.customer_id', v_customer_id::text, false);
  perform set_config('p6m13.manual.location_id', v_location_id::text, false);
  raise notice 'P6M13 fixture customer % location % (tag=%)',
    v_customer_id, v_location_id, v_tag;
end $$;

set role postgres;

do $$
declare
  v_tag text := current_setting('p6m13.tag');
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid := gen_random_uuid();
  v_unit_id uuid := gen_random_uuid();
  v_serial text := 'P6M13-' || v_tag || '-SN001';
  v_sku text := 'P6M13-' || v_tag || '-AST';
begin
  insert into public.products (
    id, tenant_id, sku, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, avg_cost, last_purchase_cost,
    expected_lifespan_months, is_serialized, created_by
  )
  values (
    v_product_id, v_tenant_a, v_sku,
    'جهاز P6M13 ' || v_tag, 'P6M13 Asset ' || v_tag, v_devices_group, 'asset_rental',
    'piece', 1, 12.500, 45.000, 45.000, 24, true, v_owner
  );

  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status,
    current_warehouse_id, purchase_cost, acquired_at
  )
  values (
    v_unit_id, v_tenant_a, v_product_id, v_serial,
    'available_new', v_main_warehouse, 60.000, current_date
  );

  insert into public.inventory_balances (
    tenant_id, warehouse_id, product_id, qty_available
  )
  values (v_tenant_a, v_main_warehouse, v_product_id, 1.000)
  on conflict (warehouse_id, product_id) do update
  set qty_available = excluded.qty_available;

  perform set_config('p6m13.manual.serial', v_serial, false);
  perform set_config('p6m13.manual.sku', v_sku, false);
  raise notice 'P6M13 fixture serial % sku %', v_serial, v_sku;
end $$;
