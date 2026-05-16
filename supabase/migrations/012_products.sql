-- Phase 1B: products (section 7.2).

create table products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  sku text not null,
  barcode text,
  name_ar text not null,
  name_en text not null,
  description_ar text,
  description_en text,
  group_id uuid not null references product_groups (id),

  product_type product_type not null,
  unit_primary unit_of_measure not null,
  unit_secondary unit_of_measure,
  conversion_factor numeric(15, 4) not null default 1,

  sale_price numeric(15, 3) not null default 0,
  min_sale_price numeric(15, 3),

  rental_price_monthly numeric(15, 3),

  avg_cost numeric(15, 3) not null default 0,
  last_purchase_cost numeric(15, 3),

  expected_lifespan_months int default 24,
  default_oil_ml_per_month numeric(15, 3),

  is_serialized boolean default false,
  trackable_for_maintenance boolean default false,

  reorder_point numeric(15, 3),
  is_active boolean default true,
  image_url text,

  created_at timestamptz default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz,
  updated_by uuid references auth.users (id),

  unique (tenant_id, sku),
  constraint chk_product_units_conversion check (
    (unit_secondary is null and conversion_factor = 1)
    or (unit_secondary is not null and conversion_factor > 1)
  )
);

create index idx_products_tenant on products (tenant_id);
create index idx_products_barcode on products (tenant_id, barcode);
create index idx_products_group on products (group_id);
create index idx_products_type on products (product_type);
