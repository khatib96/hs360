-- Phase 1A: tenant currencies and default-currency FK on tenants.

create table currencies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  iso_code text not null,
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
  symbol_position text not null default 'after',
  thousand_separator text not null default ',',
  decimal_separator text not null default '.',
  is_default boolean default false,
  is_active boolean default true,
  sort_order int default 0,
  created_at timestamptz default now(),
  created_by uuid references auth.users (id),
  unique (tenant_id, iso_code),
  constraint chk_currency_decimals check (decimal_places between 0 and 8),
  constraint chk_minor_units check (minor_units_per_major >= 1),
  constraint chk_symbol_position check (symbol_position in ('before', 'after'))
);

create index idx_currencies_tenant on currencies (tenant_id);

create unique index idx_currencies_default
  on currencies (tenant_id)
  where is_default = true;

alter table tenants
  add constraint fk_tenants_default_currency
  foreign key (default_currency_id) references currencies (id);

create or replace function tenant_default_currency()
returns uuid
language sql
stable
set search_path = public
as $$
  select id
  from currencies
  where tenant_id = current_tenant_id()
    and is_default = true
    and is_active = true
  limit 1;
$$;
