-- Phase 1B: customers (section 9.1).

create table customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  code text not null,
  customer_type customer_type default 'individual',

  name_ar text not null,
  name_en text,

  contact_person_name text,
  contact_person_title text,
  contact_person_phone text,

  phone_primary text not null,
  phone_secondary text,
  whatsapp text,
  email text,

  address_line text,
  area text,
  city text,
  country text default 'Kuwait',
  gps_lat numeric(10, 7),
  gps_lng numeric(10, 7),

  payment_terms_days int default 0,
  credit_limit numeric(15, 3) default 0,
  account_id uuid not null references chart_of_accounts (id),

  is_active boolean default true,
  is_vip boolean default false,
  notes text,

  acquired_by uuid references employees (id),
  acquired_at date,

  created_at timestamptz default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz,
  updated_by uuid references auth.users (id),

  unique (tenant_id, code)
);

create index idx_customers_tenant on customers (tenant_id);
create index idx_customers_phone on customers (tenant_id, phone_primary);

alter table product_units
  add constraint fk_product_units_current_customer
  foreign key (current_customer_id) references customers (id);
