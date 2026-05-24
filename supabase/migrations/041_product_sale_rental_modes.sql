-- Phase 3 M6.5: split product sale/rental capability from rental kind.

alter table products
  add column if not exists can_be_sold boolean,
  add column if not exists can_be_rented boolean;

update products
set
  can_be_sold = coalesce(can_be_sold, product_type = 'sale_only'),
  can_be_rented = coalesce(can_be_rented, product_type <> 'sale_only');

alter table products
  alter column can_be_sold drop default,
  alter column can_be_rented drop default,
  alter column can_be_sold set not null,
  alter column can_be_rented set not null;

create or replace function normalize_product_sale_rental_modes()
returns trigger
language plpgsql
as $$
begin
  if new.can_be_sold is null then
    new.can_be_sold := new.product_type = 'sale_only';
  end if;

  if new.can_be_rented is null then
    new.can_be_rented := new.product_type <> 'sale_only';
  end if;

  if not new.can_be_rented then
    new.product_type := 'sale_only';
  elsif new.product_type = 'sale_only' then
    new.product_type := 'asset_rental';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_normalize_product_sale_rental_modes on products;
create trigger trg_normalize_product_sale_rental_modes
  before insert or update on products
  for each row
  execute function normalize_product_sale_rental_modes();

alter table products
  drop constraint if exists chk_products_sale_or_rental,
  add constraint chk_products_sale_or_rental check (
    can_be_sold or can_be_rented
  );

alter table products
  drop constraint if exists chk_products_rental_kind,
  add constraint chk_products_rental_kind check (
    (not can_be_rented and product_type = 'sale_only')
    or (can_be_rented and product_type in ('asset_rental', 'consumable_rental'))
  );

create index if not exists idx_products_sale_rental
  on products (tenant_id, can_be_sold, can_be_rented);

drop view if exists products_safe;

create view products_safe
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
    can_be_sold,
    can_be_rented,
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

grant select on products_safe to authenticated;
