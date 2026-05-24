# DATABASE_SCHEMA.md — Database Design

> PostgreSQL via Supabase. Multi-tenant from day one. Run migrations in the order listed at the end.
> Updated 2026-05-16 to resolve conflicts: Manager/User permissions, dynamic tenant currencies, field-safe views, and dual product units.

---

## 1. Conventions

- **PKs:** UUID (`gen_random_uuid()`)
- **Tenant isolation:** every business table has `tenant_id uuid not null`
- **Timestamps:** `timestamptz`
- **Money:** `numeric(15,3)` for storage examples. Display precision comes from the tenant's default currency (`currencies.decimal_places`). KWD with 3 decimals is the Hayat Secret default, not a hardcoded rule.
- **Quantities:** `numeric(15,3)` — supports fractional ml/grams
- **Soft delete:** `is_active boolean` where history matters
- **Audit columns:** `created_at`, `created_by`, `updated_at`, `updated_by`
- **Naming:** snake_case, plural table names

---

## 2. Tenancy Tables

### 2.1 `tenants`
```sql
create table tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  logo_url text,
  default_locale text default 'ar',
  default_currency_id uuid,                       -- FK added after currencies table exists
  country_code text default 'KW',
  timezone text default 'Asia/Kuwait',
  subscription_status text default 'active',
  subscription_plan text default 'standard',
  trial_ends_at timestamptz,
  created_at timestamptz default now()
);
```

### 2.2 `tenant_users`
```sql
create type user_account_type as enum ('manager', 'user');

create table tenant_users (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  account_type user_account_type not null default 'user',
  display_name text,
  preferred_locale text,
  is_active boolean default true,
  invited_by uuid references auth.users(id),
  joined_at timestamptz default now(),
  unique(tenant_id, user_id)
);

create index idx_tenant_users_user on tenant_users(user_id);
create index idx_tenant_users_tenant on tenant_users(tenant_id);
```

### 2.3 Helper Functions for RLS
```sql
create or replace function current_tenant_id() returns uuid as $$
  select tenant_id from tenant_users
  where user_id = auth.uid() and is_active = true
  limit 1;
$$ language sql stable security definer;

create or replace function current_account_type() returns user_account_type as $$
  select account_type from tenant_users
  where user_id = auth.uid() and is_active = true
  limit 1;
$$ language sql stable security definer;

create or replace function is_manager() returns boolean as $$
  select current_account_type() = 'manager';
$$ language sql stable security definer;

create table permissions (
  id text primary key,                       -- e.g. 'contracts.create'
  module text not null,
  action text not null,
  scope text not null default 'action',      -- 'action' | 'field'
  field_name text,
  label_ar text not null,
  label_en text not null,
  description_ar text,
  description_en text,
  is_sensitive boolean default false,
  category text not null,
  sort_order int default 0,
  constraint chk_permissions_scope check (scope in ('action', 'field')),
  constraint chk_permissions_field check (
    (scope = 'field' and field_name is not null)
    or (scope = 'action' and field_name is null)
  )
);

create table user_permissions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  tenant_user_id uuid not null references tenant_users(id) on delete cascade,
  permission_id text not null references permissions(id),
  granted_at timestamptz default now(),
  granted_by uuid references auth.users(id),
  unique(tenant_user_id, permission_id)
);

create index idx_userperms_tenant on user_permissions(tenant_id);
create index idx_userperms_user on user_permissions(tenant_user_id);
create index idx_userperms_perm on user_permissions(permission_id);

create or replace function user_has_permission(p_permission_id text)
returns boolean as $$
begin
  if is_manager() then
    return true;
  end if;

  return exists (
    select 1
    from user_permissions up
    join tenant_users tu on tu.id = up.tenant_user_id
    where tu.user_id = auth.uid()
      and tu.tenant_id = current_tenant_id()
      and tu.is_active = true
      and up.permission_id = p_permission_id
  );
end;
$$ language plpgsql stable security definer;
```

---

### 2.4 `currencies`

> v1 supports one default currency per tenant. Multi-currency invoices and exchange-rate accounting are Phase 2.

```sql
create table currencies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,

  iso_code text not null,                        -- KWD, SAR, AED, USD, etc.

  major_name_ar text not null,
  major_name_en text not null,
  major_symbol_ar text not null,
  major_symbol_en text not null,

  minor_name_ar text,
  minor_name_en text,
  minor_symbol_ar text,
  minor_symbol_en text,

  decimal_places int not null default 2,
  minor_units_per_major int not null default 100,

  symbol_position text not null default 'after', -- 'before' | 'after'
  thousand_separator text not null default ',',
  decimal_separator text not null default '.',

  is_default boolean default false,
  is_active boolean default true,
  sort_order int default 0,

  created_at timestamptz default now(),
  created_by uuid references auth.users(id),

  unique(tenant_id, iso_code),
  constraint chk_currency_decimals check (decimal_places between 0 and 8),
  constraint chk_minor_units check (minor_units_per_major >= 1),
  constraint chk_symbol_position check (symbol_position in ('before', 'after'))
);

create index idx_currencies_tenant on currencies(tenant_id);
create unique index idx_currencies_default
  on currencies(tenant_id) where is_default = true;

alter table tenants
  add constraint fk_tenants_default_currency
  foreign key (default_currency_id) references currencies(id);

create or replace function tenant_default_currency()
returns uuid as $$
  select id
  from currencies
  where tenant_id = current_tenant_id()
    and is_default = true
    and is_active = true
  limit 1;
$$ language sql stable;
```

---

## 3. Settings

### 3.1 `tenant_settings`
```sql
create table tenant_settings (
  tenant_id uuid primary key references tenants(id) on delete cascade,
  company_name_ar text not null,
  company_name_en text not null,
  logo_url text,

  fiscal_year_start_month int default 1,
  email_from_address text,
  email_from_name text,
  whatsapp_phone_id text,                       -- Meta Cloud API
  whatsapp_token_ref text,                       -- vault reference

  -- Contract rules
  min_monthly_profit numeric(15,3) not null default 5.000,
  default_device_lifespan_months int default 24,
  default_trial_days int default 30,
  min_profit_override_requires_admin boolean default true,

  -- Field ops
  gps_accuracy_threshold_m int default 200,
  require_signature_on_refill boolean default false,
  require_signature_on_new_contract boolean default true,

  -- Communication
  auto_send_receipt_email boolean default true,
  auto_send_receipt_whatsapp boolean default true,
  auto_send_invoice_pdf boolean default true,

  -- Receipt footer
  receipt_footer_ar text,
  receipt_footer_en text,

  updated_at timestamptz default now()
);
```

---

## 4. HR & Employees

### 4.1 `employees`
```sql
create type employee_job_type as enum (
  'office',
  'warehouse_ops',
  'field_sales',
  'field_refill',
  'hybrid_field',
  'other'
);

create table employees (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  user_id uuid unique references auth.users(id),
  code text not null,
  name_ar text not null,
  name_en text,
  job_type employee_job_type not null default 'other', -- descriptive only; access comes from user_permissions
  phone text,
  email text,
  base_salary numeric(15,3) not null default 0,
  hire_date date not null,
  termination_date date,
  is_active boolean default true,
  notes text,
  created_at timestamptz default now(),
  unique(tenant_id, code)
);

create index idx_employees_tenant on employees(tenant_id);
create index idx_employees_job_type on employees(job_type);
```

### 4.2 `commission_rules`, `salaries`, `advances`
```sql
create type commission_basis as enum (
  'percent_of_sale',
  'percent_of_contract_value',
  'fixed_per_new_contract',
  'fixed_per_refill'
);

create table commission_rules (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  name text not null,
  basis commission_basis not null,
  rate numeric(8,4),
  fixed_amount numeric(15,3),
  job_type employee_job_type,
  employee_id uuid references employees(id),
  is_active boolean default true,
  effective_from date not null,
  effective_to date,
  created_at timestamptz default now()
);

create table salaries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  employee_id uuid not null references employees(id),
  period_year int not null,
  period_month int not null check (period_month between 1 and 12),
  base_amount numeric(15,3) not null,
  commission_amount numeric(15,3) default 0,
  advance_deductions numeric(15,3) default 0,
  other_deductions numeric(15,3) default 0,
  net_amount numeric(15,3) not null,
  voucher_id uuid,
  status text default 'draft',
  notes text,
  created_at timestamptz default now(),
  unique(employee_id, period_year, period_month)
);

create table advances (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  employee_id uuid not null references employees(id),
  amount numeric(15,3) not null,
  date date not null,
  reason text,
  remaining_balance numeric(15,3) not null,
  voucher_id uuid,
  is_settled boolean default false,
  created_at timestamptz default now()
);
```

---

## 5. Warehouses

```sql
create type warehouse_type as enum ('main', 'branch', 'van');

create table warehouses (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  name_ar text not null,
  name_en text not null,
  type warehouse_type not null default 'main',
  agent_id uuid references employees(id),
  location_address text,
  is_active boolean default true,
  created_at timestamptz default now()
);

create index idx_warehouses_tenant on warehouses(tenant_id);
create unique index idx_warehouses_van_agent
  on warehouses(tenant_id, agent_id) where type = 'van';
```

---

## 6. Chart of Accounts

```sql
create type account_type as enum (
  'asset', 'liability', 'equity', 'income', 'expense'
);

create table chart_of_accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  code text not null,
  name_ar text not null,
  name_en text not null,
  type account_type not null,
  parent_id uuid references chart_of_accounts(id),
  is_subaccount boolean default false,
  related_entity_table text,
  related_entity_id uuid,
  is_active boolean default true,
  is_system boolean default false,
  created_at timestamptz default now(),
  unique(tenant_id, code)
);

create index idx_coa_tenant on chart_of_accounts(tenant_id);
create index idx_coa_parent on chart_of_accounts(parent_id);
```

---

## 7. Products

### 7.1 `product_groups`
```sql
create table product_groups (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  name_ar text not null,
  name_en text not null,
  parent_id uuid references product_groups(id),
  sort_order int default 0,
  is_active boolean default true,
  created_at timestamptz default now(),
  created_by uuid references auth.users(id)
);

create index idx_pgroups_tenant on product_groups(tenant_id);
```

### 7.2 `products`
```sql
create type product_type as enum ('sale_only', 'asset_rental', 'consumable_rental');
create type unit_of_measure as enum (
  'piece', 'liter', 'ml', 'gram', 'kg',
  'box', 'bottle', 'carton', 'meter', 'pack'
);

create table products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  sku text not null,
  barcode text,                                  -- product-level barcode shared by the product type
  name_ar text not null,
  name_en text not null,
  description_ar text,
  description_en text,
  group_id uuid not null references product_groups(id),

  product_type product_type not null,
  unit_primary unit_of_measure not null,
  unit_secondary unit_of_measure,
  conversion_factor numeric(15,4) not null default 1,

  -- Sale pricing
  sale_price numeric(15,3) not null default 0,
  min_sale_price numeric(15,3),

  -- Legacy/unused: product-level rental price is not used.
  -- Contract monthly value is entered on contracts.
  rental_price_monthly numeric(15,3),

  -- Cost (auto-computed)
  avg_cost numeric(15,3) not null default 0,
  last_purchase_cost numeric(15,3),

  -- Rental-specific
  expected_lifespan_months int default 24,       -- for depreciation
  default_oil_ml_per_month numeric(15,3),

  -- Tracking flags
  is_serialized boolean default false,
  trackable_for_maintenance boolean default false,

  reorder_point numeric(15,3),
  is_active boolean default true,
  image_url text,

  created_at timestamptz default now(),
  created_by uuid references auth.users(id),
  updated_at timestamptz,
  updated_by uuid references auth.users(id),

  unique(tenant_id, sku),
  constraint chk_product_units_conversion check (
    (unit_secondary is null and conversion_factor = 1)
    or (unit_secondary is not null and conversion_factor > 1)
  )
);

create index idx_products_tenant on products(tenant_id);
create index idx_products_barcode on products(tenant_id, barcode);
create index idx_products_group on products(group_id);
create index idx_products_type on products(product_type);
```

Barcode vs serial rule:
- `products.barcode` identifies the product type, such as one oil SKU or one diffuser model.
- `product_units.serial_number` identifies one physical serialized asset, such as one diffuser device.
- `product_units.barcode` is optional for unit-specific stickers and can differ from the product-level barcode.

### 7.3 `product_units` (serialized assets)
```sql
create type unit_status as enum (
  'available_new', 'available_used', 'rented', 'trial',
  'maintenance', 'sold', 'damaged', 'lost', 'retired'
);

create table product_units (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  product_id uuid not null references products(id),
  serial_number text not null,
  barcode text,
  status unit_status not null default 'available_new',

  current_contract_id uuid,                       -- FK after contracts
  current_customer_id uuid,                       -- FK after customers
  current_warehouse_id uuid references warehouses(id),

  purchase_cost numeric(15,3),
  purchase_invoice_id uuid,

  health_status text default 'good',
  total_maintenance_count int default 0,
  last_maintenance_at timestamptz,

  notes text,
  acquired_at date not null,
  retired_at date,

  created_at timestamptz default now(),
  updated_at timestamptz,
  unique(tenant_id, serial_number)
);

create index idx_units_tenant on product_units(tenant_id);
create index idx_units_product on product_units(product_id);
create index idx_units_status on product_units(status);
```

### 7.4 `maintenance_records`
```sql
create type maintenance_status as enum (
  'reported', 'in_progress', 'completed', 'unrepairable', 'cancelled'
);

create table maintenance_records (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  product_unit_id uuid not null references product_units(id),
  reported_at timestamptz default now(),
  reported_by uuid references auth.users(id),
  reported_via text,                              -- field_visit | inspection | customer_complaint
  contract_id uuid,                               -- if device was on contract

  status maintenance_status not null default 'reported',

  problem_description text not null,
  diagnosis text,
  resolution text,

  cost numeric(15,3) default 0,                   -- repair cost
  parts_cost numeric(15,3) default 0,
  labor_cost numeric(15,3) default 0,

  started_at timestamptz,
  completed_at timestamptz,
  technician_id uuid references employees(id),

  notes text,
  created_at timestamptz default now()
);

create index idx_maint_tenant on maintenance_records(tenant_id);
create index idx_maint_unit on maintenance_records(product_unit_id);
create index idx_maint_status on maintenance_records(status);
```

---

## 8. Inventory

### 8.1 `inventory_balances`
```sql
create table inventory_balances (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  warehouse_id uuid not null references warehouses(id),
  product_id uuid not null references products(id),
  qty_available numeric(15,3) not null default 0,
  qty_rented numeric(15,3) not null default 0,
  qty_trial numeric(15,3) not null default 0,
  qty_maintenance numeric(15,3) not null default 0,
  qty_damaged numeric(15,3) not null default 0,
  updated_at timestamptz default now(),
  unique(warehouse_id, product_id)
);

create index idx_balances_tenant on inventory_balances(tenant_id);
create index idx_balances_warehouse on inventory_balances(warehouse_id);
```

### 8.2 `inventory_movements`
```sql
create type movement_type as enum (
  'purchase', 'sale', 'rental_out', 'rental_return',
  'refill', 'transfer_out', 'transfer_in',
  'adjustment_in', 'adjustment_out',
  'sale_return', 'purchase_return',
  'maintenance_in', 'maintenance_out'
);

create table inventory_movements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  movement_type movement_type not null,
  warehouse_id uuid not null references warehouses(id),
  product_id uuid not null references products(id),
  product_unit_id uuid references product_units(id),
  qty numeric(15,3) not null,
  unit_cost numeric(15,3),
  reference_table text,
  reference_id uuid,
  notes text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz default now(),
  created_by uuid references auth.users(id)
);

create index idx_movements_tenant on inventory_movements(tenant_id);
create index idx_movements_occurred on inventory_movements(occurred_at desc);
create index idx_movements_ref on inventory_movements(reference_table, reference_id);
```

---

## 9. Customers & Suppliers

### 9.1 `customers`
```sql
create type customer_type as enum ('individual', 'company');

create table customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  code text not null,
  customer_type customer_type default 'individual',

  name_ar text not null,
  name_en text,

  -- For companies
  contact_person_name text,
  contact_person_title text,
  contact_person_phone text,

  phone_primary text not null,
  phone_secondary text,
  whatsapp text,
  email text,                                     -- OPTIONAL

  address_line text,
  area text,
  city text,
  country text default 'Kuwait',
  gps_lat numeric(10,7),
  gps_lng numeric(10,7),

  payment_terms_days int default 0,
  credit_limit numeric(15,3) default 0,
  account_id uuid not null references chart_of_accounts(id),

  is_active boolean default true,
  is_vip boolean default false,
  notes text,

  acquired_by uuid references employees(id),
  acquired_at date,

  created_at timestamptz default now(),
  created_by uuid references auth.users(id),
  updated_at timestamptz,
  updated_by uuid references auth.users(id),

  unique(tenant_id, code)
);

create index idx_customers_tenant on customers(tenant_id);
create index idx_customers_phone on customers(tenant_id, phone_primary);
```

### 9.2 `suppliers`
```sql
create table suppliers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  code text not null,
  name_ar text not null,
  name_en text,
  phone text,
  email text,
  address text,
  account_id uuid not null references chart_of_accounts(id),
  is_active boolean default true,
  created_at timestamptz default now(),
  unique(tenant_id, code)
);
```

---

## 10. Contracts — The Core

### 10.1 `contracts`

The agent enters only the **monthly rental value**. The system snapshots underlying costs and verifies minimum profit.

```sql
create type contract_type as enum ('trial', 'rental');
create type contract_status as enum (
  'draft', 'active', 'suspended',
  'completed', 'terminated_early', 'expired'
);

create table contracts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  contract_number text not null,

  type contract_type not null default 'rental',
  status contract_status not null default 'draft',

  customer_id uuid not null references customers(id),

  -- Contact snapshot at signing
  contact_person_name text,
  contact_phone text not null,                    -- REQUIRED
  contact_email text,                             -- OPTIONAL

  -- Term
  start_date date not null,
  end_date date,                                  -- null = open-ended
  trial_days int,
  trial_end_date date,                            -- computed for trial contracts
  trial_outcome text,

  -- Billing & refill cadence
  billing_day int check (billing_day between 1 and 28),
  refill_day int check (refill_day between 1 and 28),

  -- THE NUMBER — what customer pays per month
  monthly_rental_value numeric(15,3) not null,

  -- Total value (informational): monthly × duration if fixed-term
  total_contract_value numeric(15,3),

  -- CONTRACT BASIS SNAPSHOT (frozen at creation, used for profit reports forever)
  -- Product-level rental price does not exist; these are derived from sale
  -- price, lifespan, unit conversion, and selected refill quantities.
  snapshot_device_monthly_cost numeric(15,3) not null default 0,
  snapshot_oil_monthly_cost numeric(15,3) not null default 0,
  snapshot_total_monthly_cost numeric(15,3) not null default 0,
  snapshot_monthly_profit numeric(15,3) not null default 0,
  snapshot_min_profit_threshold numeric(15,3) not null default 0,

  -- Location
  location_lat numeric(10,7),
  location_lng numeric(10,7),
  location_address text,

  -- Signing
  signed_by_customer_at timestamptz,
  signature_url text,

  -- Origination
  created_by_agent_id uuid references employees(id),

  -- Min-profit override
  min_profit_overridden boolean default false,
  override_approved_by uuid references auth.users(id),
  override_approved_at timestamptz,
  override_reason text,

  -- Closure
  closed_at timestamptz,
  closed_by uuid references auth.users(id),
  closure_reason text,

  notes text,

  created_at timestamptz default now(),
  created_by uuid references auth.users(id),
  updated_at timestamptz,
  updated_by uuid references auth.users(id),

  unique(tenant_id, contract_number)
);

create index idx_contracts_tenant on contracts(tenant_id);
create index idx_contracts_customer on contracts(customer_id);
create index idx_contracts_status on contracts(status);
create index idx_contracts_refill_day on contracts(refill_day);
create index idx_contracts_trial_end on contracts(trial_end_date);
```

### 10.2 `contract_lines`

Lines describe **what's included** in the contract. No prices here — the contract's `monthly_rental_value` is the only price the customer sees.

```sql
create type contract_line_type as enum ('asset', 'consumable');

create table contract_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  contract_id uuid not null references contracts(id) on delete cascade,
  line_type contract_line_type not null,
  product_id uuid not null references products(id),
  product_unit_id uuid references product_units(id),     -- the specific device

  -- For asset lines: just one device, qty implied = 1
  -- For consumable lines: amount per refill
  qty_per_refill numeric(15,3),                          -- e.g. 500 (ml)
  refill_frequency_months int default 1,

  -- Basis snapshot (used for profit validation)
  snapshot_unit_cost numeric(15,3) not null,             -- from product.sale_price converted to primary unit
  snapshot_monthly_cost numeric(15,3) not null,          -- (device_sale_price/lifespan) OR (qty × sale_price_per_unit)

  line_order int not null,
  created_at timestamptz default now()
);

create index idx_clines_tenant on contract_lines(tenant_id);
create index idx_clines_contract on contract_lines(contract_id);
create index idx_clines_unit on contract_lines(product_unit_id);
```

### 10.3 `contract_oil_changes` — Track Oil-Type Switches Over Time

When a customer says "next month switch to Vanilla", a new row is inserted. The previous row gets `effective_to` set. The "current oil" is always the row with `effective_to IS NULL`.

```sql
create table contract_oil_changes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  contract_id uuid not null references contracts(id) on delete cascade,
  contract_line_id uuid not null references contract_lines(id),

  effective_from date not null,
  effective_to date,                              -- null = currently active

  oil_product_id uuid not null references products(id),
  qty_per_refill numeric(15,3) not null,
  snapshot_unit_cost numeric(15,3) not null,
  snapshot_refill_cost numeric(15,3) not null,    -- qty × unit_cost at change time

  changed_by_agent_id uuid references employees(id),
  reason text,

  created_at timestamptz default now()
);

create index idx_oilchg_tenant on contract_oil_changes(tenant_id);
create index idx_oilchg_contract on contract_oil_changes(contract_id);
create index idx_oilchg_active on contract_oil_changes(contract_line_id, effective_to);
```

---

## 11. Visits — Field Operations

```sql
create type visit_type as enum (
  'refill', 'new_contract', 'sales_pitch',
  'maintenance_pickup', 'maintenance_dropoff',
  'collection', 'asset_return', 'inspection'
);

create type visit_status as enum (
  'scheduled', 'in_progress', 'completed',
  'missed', 'cancelled', 'rescheduled'
);

create table visits (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  visit_number text not null,
  type visit_type not null,
  status visit_status not null default 'scheduled',

  contract_id uuid references contracts(id),
  customer_id uuid references customers(id),
  agent_id uuid not null references employees(id),

  scheduled_date date not null,
  scheduled_time time,
  started_at timestamptz,
  completed_at timestamptz,

  -- GPS verification
  check_in_lat numeric(10,7),
  check_in_lng numeric(10,7),
  check_in_accuracy_m numeric(8,2),
  check_out_lat numeric(10,7),
  check_out_lng numeric(10,7),
  location_match boolean,

  -- Proof
  photo_url text,
  photo_taken_at timestamptz,

  -- Refill specifics
  oil_product_id uuid references products(id),
  oil_qty_ml numeric(15,3),

  -- Collection at visit (separate from refill — payment may be 0)
  payment_collected boolean default false,
  payment_amount numeric(15,3),
  payment_method text,
  voucher_id uuid,                                -- FK to vouchers, added after

  notes text,
  customer_signature_url text,

  -- Offline sync
  client_id text,                                 -- mobile device UUID for idempotency
  created_at timestamptz default now(),
  created_by uuid references auth.users(id),
  synced_at timestamptz,

  unique(tenant_id, visit_number),
  unique(client_id) deferrable initially deferred
);

create index idx_visits_tenant on visits(tenant_id);
create index idx_visits_agent on visits(agent_id);
create index idx_visits_contract on visits(contract_id);
create index idx_visits_date on visits(scheduled_date);
create index idx_visits_status on visits(status);
```

---

## 12. Invoices

```sql
create type invoice_type as enum (
  'sales', 'purchase',
  'sales_return', 'purchase_return',
  'rental_monthly',
  'opening_balance_customer', 'opening_balance_supplier'
);

create type invoice_status as enum (
  'draft', 'confirmed', 'partially_paid', 'paid', 'cancelled'
);

create table invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  invoice_number text not null,
  type invoice_type not null,
  status invoice_status not null default 'draft',

  customer_id uuid references customers(id),
  supplier_id uuid references suppliers(id),
  contract_id uuid references contracts(id),
  visit_id uuid references visits(id),            -- if generated from a refill

  date date not null,
  due_date date,

  subtotal numeric(15,3) not null default 0,
  discount_amount numeric(15,3) not null default 0,
  tax_amount numeric(15,3) not null default 0,
  total numeric(15,3) not null default 0,
  paid_amount numeric(15,3) not null default 0,

  warehouse_id uuid references warehouses(id),
  notes text,

  journal_entry_id uuid,                          -- FK after journal_entries
  pdf_url text,
  sent_at timestamptz,
  sent_channels text[],                           -- {'email', 'whatsapp'}

  created_at timestamptz default now(),
  created_by uuid references auth.users(id),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id),

  unique(tenant_id, invoice_number),
  constraint chk_party check (
    (customer_id is not null and supplier_id is null)
    or (customer_id is null and supplier_id is not null)
  )
);

create index idx_invoices_tenant on invoices(tenant_id);
create index idx_invoices_customer on invoices(customer_id);
create index idx_invoices_contract on invoices(contract_id);
create index idx_invoices_status on invoices(status);
create index idx_invoices_date on invoices(date);

create table invoice_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  invoice_id uuid not null references invoices(id) on delete cascade,
  product_id uuid not null references products(id),
  product_unit_id uuid references product_units(id),
  description text,
  qty numeric(15,3) not null,
  unit_price numeric(15,3) not null,
  discount_pct numeric(5,2) default 0,
  cost_price numeric(15,3),                       -- snapshot
  line_total numeric(15,3) not null,
  line_order int not null
);

create index idx_invlines_invoice on invoice_lines(invoice_id);
```

---

## 13. Vouchers (Collections & Payments)

```sql
create type voucher_type as enum ('receipt', 'payment');
create type payment_method as enum (
  'cash', 'knet', 'bank_transfer', 'cheque', 'other'
);

create table vouchers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  voucher_number text not null,
  type voucher_type not null,
  date date not null,

  amount numeric(15,3) not null,
  payment_method payment_method not null,
  reference_no text,                              -- cheque #, txn id

  customer_id uuid references customers(id),
  supplier_id uuid references suppliers(id),
  employee_id uuid references employees(id),

  account_id uuid not null references chart_of_accounts(id),       -- contra
  cash_account_id uuid not null references chart_of_accounts(id),  -- cash/bank

  notes text,
  collected_by uuid references auth.users(id),
  visit_id uuid references visits(id),

  journal_entry_id uuid,
  pdf_url text,
  sent_at timestamptz,
  sent_channels text[],

  created_at timestamptz default now(),
  created_by uuid references auth.users(id),

  unique(tenant_id, voucher_number)
);

create index idx_vouchers_tenant on vouchers(tenant_id);
create index idx_vouchers_customer on vouchers(customer_id);
create index idx_vouchers_date on vouchers(date);

create table voucher_invoice_allocations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  voucher_id uuid not null references vouchers(id) on delete cascade,
  invoice_id uuid not null references invoices(id),
  allocated_amount numeric(15,3) not null
);

create index idx_vallocs_voucher on voucher_invoice_allocations(voucher_id);
create index idx_vallocs_invoice on voucher_invoice_allocations(invoice_id);
```

---

## 14. Journal (Double-Entry)

```sql
create type journal_source as enum (
  'manual', 'sales_invoice', 'purchase_invoice',
  'receipt_voucher', 'payment_voucher',
  'rental_invoice', 'contract_creation', 'contract_closure',
  'opening_balance', 'inventory_adjustment', 'salary_payment'
);

create table journal_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  entry_number text not null,
  date date not null,
  source journal_source not null,
  source_id uuid,
  description_ar text,
  description_en text,
  is_posted boolean default false,
  posted_at timestamptz,
  posted_by uuid references auth.users(id),
  created_at timestamptz default now(),
  created_by uuid references auth.users(id),
  unique(tenant_id, entry_number)
);

create table journal_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  journal_entry_id uuid not null references journal_entries(id) on delete cascade,
  account_id uuid not null references chart_of_accounts(id),
  debit numeric(15,3) not null default 0,
  credit numeric(15,3) not null default 0,
  description text,
  line_order int not null,
  constraint chk_dr_cr check (
    (debit > 0 and credit = 0) or (credit > 0 and debit = 0)
  )
);

create index idx_journal_tenant on journal_entries(tenant_id);
create index idx_journal_date on journal_entries(date);
create index idx_jlines_entry on journal_lines(journal_entry_id);
```

---

## 15. Quotations

```sql
create type quotation_status as enum (
  'draft', 'sent', 'accepted', 'rejected', 'expired', 'converted'
);

create table quotations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  quotation_number text not null,
  customer_id uuid not null references customers(id),
  date date not null,
  valid_until date,
  subtotal numeric(15,3) not null default 0,
  discount_amount numeric(15,3) default 0,
  total numeric(15,3) not null default 0,
  status quotation_status default 'draft',
  notes text,
  converted_to_invoice_id uuid references invoices(id),
  converted_to_contract_id uuid references contracts(id),
  pdf_url text,
  created_at timestamptz default now(),
  created_by uuid references auth.users(id),
  unique(tenant_id, quotation_number)
);

create table quotation_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  quotation_id uuid not null references quotations(id) on delete cascade,
  product_id uuid not null references products(id),
  description text,
  qty numeric(15,3) not null,
  unit_price numeric(15,3) not null,
  line_total numeric(15,3) not null,
  line_order int not null
);
```

---

## 16. Calendar & Reminders

A unified calendar view aggregating all date-bound events.

```sql
create type calendar_event_type as enum (
  'refill_due', 'contract_start', 'contract_end',
  'trial_ending', 'follow_up', 'maintenance_due',
  'payment_due', 'custom'
);

create type calendar_event_status as enum (
  'pending', 'done', 'missed', 'cancelled', 'rescheduled'
);

create table calendar_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  type calendar_event_type not null,
  status calendar_event_status default 'pending',

  -- When
  scheduled_date date not null,
  scheduled_time time,
  reminder_offsets_minutes int[] default '{1440, 60}',  -- 1 day + 1 hour before

  -- Who/what
  assigned_agent_id uuid references employees(id),
  contract_id uuid references contracts(id),
  customer_id uuid references customers(id),
  product_unit_id uuid references product_units(id),
  visit_id uuid references visits(id),

  title_ar text,
  title_en text,
  notes text,

  -- Completion
  completed_at timestamptz,
  completed_by uuid references auth.users(id),

  -- Recurrence (for monthly refills)
  is_recurring boolean default false,
  recurrence_rule text,                           -- iCal RRULE string
  parent_event_id uuid references calendar_events(id),

  created_at timestamptz default now(),
  created_by uuid references auth.users(id)
);

create index idx_calevents_tenant on calendar_events(tenant_id);
create index idx_calevents_agent on calendar_events(assigned_agent_id);
create index idx_calevents_date on calendar_events(scheduled_date);
create index idx_calevents_contract on calendar_events(contract_id);
create index idx_calevents_status on calendar_events(status);
```

---

## 17. Notifications

```sql
create type notification_channel as enum ('email', 'whatsapp', 'in_app', 'sms');
create type notification_status as enum ('pending', 'sent', 'failed', 'read');

create table notifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  channel notification_channel not null,
  recipient_type text not null,                   -- customer | employee | user
  recipient_id uuid not null,
  recipient_address text not null,
  subject text,
  body_ar text,
  body_en text,
  template_key text,
  status notification_status default 'pending',
  sent_at timestamptz,
  error_message text,
  related_entity_table text,
  related_entity_id uuid,
  created_at timestamptz default now()
);

create index idx_notifs_tenant on notifications(tenant_id);
create index idx_notifs_status on notifications(status);
```

---

## 18. Audit Log

```sql
create table audit_log (
  id bigint generated always as identity primary key,
  tenant_id uuid not null,
  at timestamptz default now(),
  actor_id uuid references auth.users(id),
  actor_account_type text,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_json jsonb,
  after_json jsonb,
  reason text,
  ip_address inet,
  user_agent text
);

create index idx_audit_tenant on audit_log(tenant_id);
create index idx_audit_at on audit_log(at desc);
create index idx_audit_entity on audit_log(entity_type, entity_id);
```

---

## 19. Key Stored Functions

Full implementations in `BUILD_PLAN.md`. Names and signatures:

| Function | Purpose |
|----------|---------|
| `current_tenant_id()` | Returns user's tenant from JWT |
| `current_account_type()` | Returns `manager` or `user` |
| `is_manager()` | Manager bypass for permission checks |
| `user_has_permission(permission_id)` | Explicit permission check for Users |
| `tenant_default_currency()` | Returns the tenant's active default currency |
| `create_rental_contract(...)` | Atomic: contract + lines + asset reservation + first invoice + journal |
| `record_purchase_invoice(...)` | Invoice + WAC recalc + inventory in |
| `record_sales_invoice(...)` | Invoice + stock out + journal |
| `record_refill_visit(...)` | Inventory out + invoice/charge + optional voucher |
| `close_contract(...)` | Return asset + final settlement |
| `recalculate_wac(product_id)` | Recompute weighted avg cost |
| `monthly_billing_job()` | Generate this month's rental invoices |
| `daily_calendar_seed_job()` | Generate next-day calendar entries from contracts |
| `customer_balance(customer_id)` | Live A/R balance |
| `aged_receivables(tenant_id)` | Debt aging breakdown |
| `contract_profitability(contract_id)` | Per-contract P&L using snapshots |

---

## 20. Reporting Views

| View | Purpose |
|------|---------|
| `v_customer_balances` | Each customer's outstanding A/R |
| `v_active_contracts` | All active rentals with monthly value & profit |
| `v_rented_assets` | Where every rented device is right now |
| `v_inventory_with_value` | Stock × WAC per product |
| `v_agent_daily_performance` | Visits, collections, contracts per agent per day |
| `v_overdue_invoices` | Past-due invoices with aging buckets |
| `v_trial_contracts_expiring` | Trials within 7 days of expiry |
| `v_today_refills` | Refills due today (calendar derived) |

---

## 21. Migration Order

```
001_extensions.sql                 -- uuid-ossp, pgcrypto
002_tenants.sql                    -- tenants + tenant_users + helper fns
003_enums.sql                      -- all enum types
004_permissions.sql                -- permissions catalog + user_permissions + user_has_permission
005_currencies.sql                 -- currencies + default currency FK
006_tenant_settings.sql
007_employees.sql
008_commissions_salaries_advances.sql
009_warehouses.sql
010_chart_of_accounts.sql
011_product_groups.sql
012_products.sql
013_product_units.sql
014_maintenance.sql
015_inventory.sql                  -- balances + movements
016_customers.sql
017_suppliers.sql
018_journal.sql                    -- entries + lines
019_invoices.sql
020_vouchers.sql                   -- + voucher_invoice_allocations
021_contracts.sql                  -- + contract_lines + oil_changes
022_visits.sql
023_quotations.sql
024_calendar.sql
025_notifications.sql
026_audit_log.sql
027_functions.sql                  -- all stored functions
028_views.sql                      -- reporting views and security_invoker safe views
029_triggers.sql                   -- audit log + WAC + balance updates
030_rls_policies.sql               -- see SECURITY.md
031_seed.sql                       -- default CoA, permissions catalog, currencies, system settings
```

Add FKs that were forward-references (e.g. `product_units.current_contract_id → contracts.id`) at the end of each table's migration once both exist, or batched in a final `032_late_fks.sql`.
