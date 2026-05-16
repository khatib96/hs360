-- Phase 1C: security_invoker safe views (SECURITY.md section 3.3).

create or replace view products_safe
with (security_invoker = true) as
  select
    id,
    tenant_id,
    sku,
    barcode,
    name_ar,
    name_en,
    description_ar,
    description_en,
    group_id,
    product_type,
    unit_primary,
    unit_secondary,
    conversion_factor,
    sale_price,
    rental_price_monthly,
    expected_lifespan_months,
    default_oil_ml_per_month,
    is_serialized,
    trackable_for_maintenance,
    reorder_point,
    is_active,
    image_url,
    created_at
  from products;

create or replace view contracts_safe
with (security_invoker = true) as
  select
    id,
    tenant_id,
    contract_number,
    type,
    status,
    customer_id,
    contact_person_name,
    contact_phone,
    contact_email,
    start_date,
    end_date,
    billing_day,
    refill_day,
    monthly_rental_value,
    total_contract_value,
    location_lat,
    location_lng,
    location_address,
    signed_by_customer_at,
    signature_url,
    created_by_agent_id,
    closed_at,
    closure_reason,
    notes,
    created_at,
    updated_at
  from contracts;

grant select on products_safe to authenticated;
grant select on contracts_safe to authenticated;
