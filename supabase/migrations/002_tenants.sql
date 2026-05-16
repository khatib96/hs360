-- Phase 1A: tenancy foundation (user_account_type lives here for tenant_users dependency).

create type user_account_type as enum ('manager', 'user');

create table tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  logo_url text,
  default_locale text default 'ar',
  default_currency_id uuid,
  country_code text default 'KW',
  timezone text default 'Asia/Kuwait',
  subscription_status text default 'active',
  subscription_plan text default 'standard',
  trial_ends_at timestamptz,
  created_at timestamptz default now()
);

create table tenant_users (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  account_type user_account_type not null default 'user',
  display_name text,
  preferred_locale text,
  is_active boolean default true,
  invited_by uuid references auth.users (id),
  joined_at timestamptz default now(),
  unique (tenant_id, user_id)
);

create index idx_tenant_users_user on tenant_users (user_id);
create index idx_tenant_users_tenant on tenant_users (tenant_id);

create or replace function current_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select tenant_id
  from tenant_users
  where user_id = auth.uid()
    and is_active = true
  limit 1;
$$;

create or replace function current_account_type()
returns user_account_type
language sql
stable
security definer
set search_path = public
as $$
  select account_type
  from tenant_users
  where user_id = auth.uid()
    and is_active = true
  limit 1;
$$;

create or replace function is_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select current_account_type() = 'manager';
$$;
