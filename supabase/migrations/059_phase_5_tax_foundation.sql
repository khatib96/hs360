-- Phase 5 M4: tax foundation, money math, and deterministic invoice calculations.

create extension if not exists btree_gist;

-- ---------------------------------------------------------------------------
-- Enum and schema
-- ---------------------------------------------------------------------------
create type public.product_tax_class as enum (
  'taxable',
  'zero_rated',
  'exempt',
  'non_taxable'
);

alter table public.tenant_settings
  add column if not exists tax_enabled boolean not null default false,
  add column if not exists tax_registration_number text,
  add column if not exists default_tax_rate_id uuid;

alter table public.products
  add column if not exists tax_class public.product_tax_class not null default 'non_taxable';

update public.products
set tax_class = 'non_taxable'
where tax_class is null;

create table public.tax_rates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  code text not null,
  name_ar text not null,
  name_en text not null,
  rate numeric(9, 6) not null,
  effective_from date not null,
  effective_to date,
  output_account_id uuid not null,
  input_account_id uuid not null,
  expense_account_id uuid,
  is_recoverable boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  constraint ux_tax_rates_tenant_id_id unique (tenant_id, id),
  constraint ux_tax_rates_tenant_code_effective unique (tenant_id, code, effective_from),
  constraint chk_tax_rates_rate_range check (rate >= 0 and rate <= 100),
  constraint chk_tax_rates_effective_range check (
    effective_to is null or effective_to >= effective_from
  )
);

alter table public.tax_rates
  add constraint fk_tax_rates_output_account_tenant
    foreign key (tenant_id, output_account_id)
    references public.chart_of_accounts (tenant_id, id),
  add constraint fk_tax_rates_input_account_tenant
    foreign key (tenant_id, input_account_id)
    references public.chart_of_accounts (tenant_id, id),
  add constraint fk_tax_rates_expense_account_tenant
    foreign key (tenant_id, expense_account_id)
    references public.chart_of_accounts (tenant_id, id);

alter table public.tax_rates
  add constraint excl_tax_rates_no_overlap
  exclude using gist (
    tenant_id with =,
    code with =,
    daterange(
      effective_from,
      coalesce(effective_to, 'infinity'::date),
      '[]'
    ) with &&
  );

create index idx_tax_rates_tenant on public.tax_rates (tenant_id);
create index idx_tax_rates_tenant_code on public.tax_rates (tenant_id, code);
create index idx_tax_rates_effective on public.tax_rates (tenant_id, code, effective_from);

alter table public.tenant_settings
  add constraint fk_tenant_settings_default_tax_rate
    foreign key (tenant_id, default_tax_rate_id)
    references public.tax_rates (tenant_id, id);

alter table public.invoice_lines
  add column if not exists tax_rate_id uuid,
  add column if not exists tax_rate numeric(9, 6) not null default 0,
  add column if not exists tax_class public.product_tax_class not null default 'non_taxable',
  add column if not exists taxable_amount numeric(15, 3) not null default 0,
  add column if not exists tax_amount numeric(15, 3) not null default 0;

update public.invoice_lines il
set
  tax_rate_id = null,
  tax_rate = 0,
  tax_class = 'non_taxable',
  taxable_amount = 0,
  tax_amount = 0;

update public.invoice_lines il
set gross_amount = round(
  il.qty * il.unit_price,
  coalesce(c.decimal_places, 3)
)
from public.tenants t
left join public.currencies c on c.id = t.default_currency_id
where il.tenant_id = t.id
  and il.gross_amount = 0
  and round(il.qty * il.unit_price, coalesce(c.decimal_places, 3)) > 0;

update public.invoice_lines il
set discount_amount = round(
  il.gross_amount * coalesce(il.discount_pct, 0) / 100,
  coalesce(c.decimal_places, 3)
)
from public.tenants t
left join public.currencies c on c.id = t.default_currency_id
where il.tenant_id = t.id
  and il.discount_amount = 0
  and il.gross_amount > 0
  and coalesce(il.discount_pct, 0) > 0;

update public.invoice_lines il
set
  before_tax_amount = case
    when il.line_total > 0 then il.line_total
    else il.gross_amount - il.discount_amount
  end
where il.before_tax_amount = 0
   or (il.line_total > 0 and il.before_tax_amount is distinct from il.line_total);

update public.invoice_lines il
set
  after_tax_amount = il.before_tax_amount,
  line_total = case
    when il.line_total > 0 then il.line_total
    else il.before_tax_amount
  end
where il.after_tax_amount = 0
   or il.after_tax_amount is distinct from il.before_tax_amount
   or (il.line_total = 0 and il.before_tax_amount > 0)
   or (il.line_total > 0 and il.line_total is distinct from il.before_tax_amount);

do $$
begin
  if exists (
    select 1
    from public.invoice_lines
    where gross_amount < 0
      or discount_amount < 0
      or before_tax_amount < 0
      or after_tax_amount < 0
      or line_total < 0
      or after_tax_amount <> before_tax_amount
      or line_total <> after_tax_amount
      or tax_rate <> 0
      or tax_amount <> 0
      or taxable_amount <> 0
      or tax_rate_id is not null
  ) then
    raise exception 'validation_failed';
  end if;
end $$;

alter table public.invoice_lines
  drop constraint if exists chk_invoice_lines_snapshot_amounts;

alter table public.invoice_lines
  add constraint chk_invoice_lines_snapshot_amounts check (
    gross_amount >= 0
    and discount_amount >= 0
    and before_tax_amount >= 0
    and after_tax_amount >= 0
    and line_total >= 0
    and taxable_amount >= 0
    and tax_amount >= 0
    and after_tax_amount = before_tax_amount + tax_amount
    and line_total = after_tax_amount
  );

alter table public.invoice_lines
  add constraint chk_invoice_lines_tax_snapshot_class check (
    (
      tax_class in ('exempt', 'non_taxable')
      and tax_rate_id is null
      and tax_rate = 0
      and taxable_amount = 0
      and tax_amount = 0
    )
    or (
      tax_class = 'zero_rated'
      and tax_rate_id is null
      and tax_rate = 0
      and tax_amount = 0
      and taxable_amount = before_tax_amount
    )
    or (
      tax_class = 'taxable'
      and tax_rate_id is not null
      and taxable_amount = before_tax_amount
    )
    or (
      tax_class = 'taxable'
      and tax_rate_id is null
      and tax_rate = 0
      and taxable_amount = 0
      and tax_amount = 0
    )
  );

alter table public.invoice_lines
  add constraint fk_invoice_lines_tax_rate_tenant
    foreign key (tenant_id, tax_rate_id)
    references public.tax_rates (tenant_id, id);

drop view if exists public.products_safe;

create view public.products_safe
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
    tax_class,
    created_at
  from public.products;

grant select on public.products_safe to authenticated;

-- ---------------------------------------------------------------------------
-- Internal session gates
-- ---------------------------------------------------------------------------
create or replace function public.allow_tax_settings_write()
returns void
language sql
security definer
set search_path = public
as $$
  select set_config('hs360.tax_settings_write', '1', true);
$$;

create or replace function public.allow_tax_account_provisioning()
returns void
language sql
security definer
set search_path = public
as $$
  select set_config('hs360.tax_account_provisioning', '1', true);
$$;

create or replace function public.enforce_tax_settings_direct_write_gate()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('postgres', 'supabase_admin') then
    return new;
  end if;

  if coalesce(current_setting('hs360.tax_settings_write', true), '') = '1' then
    return new;
  end if;

  if new.tax_enabled is distinct from old.tax_enabled
    or new.tax_registration_number is distinct from old.tax_registration_number
    or new.default_tax_rate_id is distinct from old.default_tax_rate_id then
    raise exception 'direct_write_forbidden';
  end if;

  return new;
end;
$$;

create trigger trg_enforce_tax_settings_direct_write_gate
  before update on public.tenant_settings
  for each row execute function public.enforce_tax_settings_direct_write_gate();

create or replace function public.is_reserved_tax_account_code(p_code text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_code in ('1151', '2151', '5151');
$$;

create or replace function public.enforce_tax_account_provisioning_gate()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('postgres', 'supabase_admin') then
    return coalesce(new, old);
  end if;

  if new.code in ('1151', '2151', '5151')
    and coalesce(current_setting('hs360.tax_account_provisioning', true), '') <> '1' then
    raise exception 'direct_write_forbidden';
  end if;

  return new;
end;
$$;

create trigger trg_enforce_tax_account_provisioning_gate
  before insert or update on public.chart_of_accounts
  for each row execute function public.enforce_tax_account_provisioning_gate();

create or replace function public.enforce_tax_account_leaf_protection()
returns trigger
language plpgsql
as $$
declare
  v_parent_code text;
begin
  if new.parent_id is null then
    return new;
  end if;

  select code into v_parent_code
  from public.chart_of_accounts
  where tenant_id = new.tenant_id
    and id = new.parent_id;

  if v_parent_code in ('1151', '2151', '5151') then
    raise exception 'account_protected';
  end if;

  return new;
end;
$$;

create trigger trg_enforce_tax_account_leaf_protection
  before insert or update on public.chart_of_accounts
  for each row execute function public.enforce_tax_account_leaf_protection();

create or replace function public.enforce_tax_rates_no_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'tax_rate_in_use';
end;
$$;

create trigger trg_enforce_tax_rates_no_delete
  before delete on public.tax_rates
  for each row execute function public.enforce_tax_rates_no_delete();

create or replace function public.enforce_tax_rates_immutability()
returns trigger
language plpgsql
as $$
begin
  if old.rate is distinct from new.rate
    or old.output_account_id is distinct from new.output_account_id
    or old.input_account_id is distinct from new.input_account_id
    or old.expense_account_id is distinct from new.expense_account_id
    or old.is_recoverable is distinct from new.is_recoverable
    or old.effective_from is distinct from new.effective_from
    or old.code is distinct from new.code
    or old.tenant_id is distinct from new.tenant_id then
    raise exception 'tax_rate_in_use';
  end if;

  return new;
end;
$$;

create trigger trg_enforce_tax_rates_immutability
  before update on public.tax_rates
  for each row execute function public.enforce_tax_rates_immutability();

-- ---------------------------------------------------------------------------
-- Permission helpers
-- ---------------------------------------------------------------------------
create or replace function public.assert_tax_settings_read()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.is_manager() then
    return;
  end if;
  if not (
    public.user_has_permission('settings.tax.view')
    or public.user_has_permission('settings.tax.edit')
  ) then
    raise exception 'permission_denied';
  end if;
end;
$$;

create or replace function public.assert_tax_settings_edit()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.is_manager() then
    return;
  end if;
  if not public.user_has_permission('settings.tax.edit') then
    raise exception 'permission_denied';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Account validation and provisioning
-- ---------------------------------------------------------------------------
create or replace function public.validate_tax_posting_account(
  p_tenant_id uuid,
  p_account_id uuid,
  p_expected_type public.account_type,
  p_required boolean default true
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.chart_of_accounts%rowtype;
  v_child_count bigint;
begin
  if p_account_id is null then
    if p_required then
      raise exception 'validation_failed';
    end if;
    return;
  end if;

  select * into v_row
  from public.chart_of_accounts
  where id = p_account_id;

  if not found or v_row.tenant_id <> p_tenant_id then
    raise exception 'cross_tenant_reference';
  end if;

  if v_row.type <> p_expected_type then
    raise exception 'account_type_mismatch';
  end if;

  if not v_row.is_active then
    raise exception 'validation_failed';
  end if;

  if v_row.related_entity_id is not null then
    raise exception 'validation_failed';
  end if;

  select count(*) into v_child_count
  from public.chart_of_accounts c
  where c.tenant_id = p_tenant_id
    and c.parent_id = p_account_id
    and c.is_active = true;

  if v_child_count > 0 then
    raise exception 'validation_failed';
  end if;
end;
$$;

create or replace function public.resolve_or_insert_tax_system_account(
  p_tenant_id uuid,
  p_code text,
  p_name_ar text,
  p_name_en text,
  p_type public.account_type,
  p_parent_code text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.chart_of_accounts%rowtype;
  v_parent_id uuid;
  v_id uuid;
  v_child_count bigint;
begin
  select * into v_existing
  from public.chart_of_accounts
  where tenant_id = p_tenant_id
    and code = p_code;

  if found then
    select id into v_parent_id
    from public.chart_of_accounts
    where tenant_id = p_tenant_id
      and code = p_parent_code;

    select count(*) into v_child_count
    from public.chart_of_accounts c
    where c.tenant_id = p_tenant_id
      and c.parent_id = v_existing.id
      and c.is_active = true;

    if v_existing.type <> p_type
      or v_existing.is_system is distinct from true
      or not v_existing.is_active
      or v_existing.related_entity_id is not null
      or v_existing.parent_id is distinct from v_parent_id
      or v_child_count > 0 then
      raise exception 'tax_account_code_conflict';
    end if;

    return v_existing.id;
  end if;

  select id into v_parent_id
  from public.chart_of_accounts
  where tenant_id = p_tenant_id
    and code = p_parent_code;

  if v_parent_id is null then
    raise exception 'validation_failed';
  end if;

  insert into public.chart_of_accounts (
    tenant_id, code, name_ar, name_en, type, parent_id, is_system, is_active
  )
  values (
    p_tenant_id, p_code, p_name_ar, p_name_en, p_type, v_parent_id, true, true
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.provision_tenant_tax_accounts(p_tenant_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_input_id uuid;
  v_output_id uuid;
  v_expense_id uuid;
begin
  perform public.allow_tax_account_provisioning();

  v_input_id := public.resolve_or_insert_tax_system_account(
    p_tenant_id,
    '1151',
    U&'\0636\0631\064A\0628\0629 \0645\062F\062E\0644\0627\062A \0642\0627\0628\0644\0629 \0644\0644\0627\0633\062A\0631\062F\0627\062F' UESCAPE '\',
    'Input Tax Recoverable',
    'asset',
    '1000'
  );

  v_output_id := public.resolve_or_insert_tax_system_account(
    p_tenant_id,
    '2151',
    U&'\0636\0631\064A\0628\0629 \0645\062E\0631\062C\0627\062A \0645\0633\062A\062D\0642\0629 \0627\0644\062F\0641\0639' UESCAPE '\',
    'Output Tax Payable',
    'liability',
    '2000'
  );

  v_expense_id := public.resolve_or_insert_tax_system_account(
    p_tenant_id,
    '5151',
    U&'\0645\0635\0631\0648\0641 \0636\0631\064A\0628\0629 \063A\064A\0631 \0642\0627\0628\0644 \0644\0644\0627\0633\062A\0631\062F\0627\062F' UESCAPE '\',
    'Non-recoverable Tax Expense',
    'expense',
    '5000'
  );

  return jsonb_build_object(
    'input_account_id', v_input_id,
    'output_account_id', v_output_id,
    'expense_account_id', v_expense_id
  );
end;
$$;

create or replace function public.advance_default_tax_rate_anchor(
  p_tenant_id uuid,
  p_code text,
  p_new_rate_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new public.tax_rates%rowtype;
  v_anchor_code text;
begin
  select * into v_new
  from public.tax_rates
  where id = p_new_rate_id
    and tenant_id = p_tenant_id;

  if not found or v_new.code <> p_code then
    raise exception 'validation_failed';
  end if;

  select tr.code into v_anchor_code
  from public.tenant_settings ts
  left join public.tax_rates tr on tr.id = ts.default_tax_rate_id
    and tr.tenant_id = ts.tenant_id
  where ts.tenant_id = p_tenant_id;

  if v_anchor_code is not null and v_anchor_code <> p_code then
    raise exception 'validation_failed';
  end if;

  perform public.allow_tax_settings_write();

  update public.tenant_settings
  set default_tax_rate_id = p_new_rate_id
  where tenant_id = p_tenant_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Money math helpers
-- ---------------------------------------------------------------------------
create or replace function public.resolve_tenant_money_precision(p_tenant_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_places integer;
begin
  select coalesce(c.decimal_places, 3) into v_places
  from public.tenants t
  left join public.currencies c on c.id = t.default_currency_id
  where t.id = p_tenant_id;

  if v_places is null then
    v_places := 3;
  end if;

  if v_places > 3 then
    raise exception 'validation_failed';
  end if;

  return v_places;
end;
$$;

create or replace function public.round_money(
  p_value numeric,
  p_decimal_places integer
)
returns numeric
language sql
immutable
set search_path = public
as $$
  select round(p_value, p_decimal_places);
$$;

create or replace function public.resolve_effective_tax_rate_version(
  p_tenant_id uuid,
  p_code text,
  p_invoice_date date,
  p_require_active boolean default false
)
returns public.tax_rates
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.tax_rates%rowtype;
begin
  select * into v_row
  from public.tax_rates tr
  where tr.tenant_id = p_tenant_id
    and tr.code = p_code
    and p_invoice_date >= tr.effective_from
    and (tr.effective_to is null or p_invoice_date <= tr.effective_to)
    and (not p_require_active or tr.is_active)
  order by tr.effective_from desc
  limit 1;

  if not found then
    raise exception 'tax_rate_not_found';
  end if;

  return v_row;
end;
$$;

create or replace function public.default_tax_series_code(p_tenant_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select tr.code
  from public.tenant_settings ts
  join public.tax_rates tr on tr.tenant_id = ts.tenant_id
    and tr.id = ts.default_tax_rate_id
  where ts.tenant_id = p_tenant_id;
$$;

create or replace function public.is_default_series_protected_version(
  p_tenant_id uuid,
  p_rate public.tax_rates
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_default_code text;
  v_today date := current_date;
begin
  if not exists (
    select 1 from public.tenant_settings
    where tenant_id = p_tenant_id and tax_enabled
  ) then
    return false;
  end if;

  v_default_code := public.default_tax_series_code(p_tenant_id);
  if v_default_code is null or v_default_code <> p_rate.code then
    return false;
  end if;

  if p_rate.effective_from > v_today then
    return true;
  end if;

  if p_rate.effective_to is null and p_rate.effective_from <= v_today then
    return true;
  end if;

  if p_rate.effective_from <= v_today
    and (p_rate.effective_to is null or p_rate.effective_to >= v_today) then
    return true;
  end if;

  return false;
end;
$$;

create or replace function public.calculate_invoice_line_snapshot(
  p_tenant_id uuid,
  p_product_id uuid,
  p_invoice_date date,
  p_qty numeric,
  p_unit_price numeric,
  p_discount_pct numeric,
  p_decimal_places integer,
  p_tax_enabled boolean,
  p_default_code text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_product public.products%rowtype;
  v_gross numeric;
  v_discount numeric;
  v_before_tax numeric;
  v_taxable numeric := 0;
  v_tax_amount numeric := 0;
  v_tax_rate numeric := 0;
  v_tax_rate_id uuid;
  v_rate_row public.tax_rates;
  v_after_tax numeric;
begin
  select * into v_product
  from public.products
  where id = p_product_id and tenant_id = p_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  v_gross := public.round_money(p_qty * p_unit_price, p_decimal_places);
  v_discount := public.round_money(v_gross * p_discount_pct / 100, p_decimal_places);
  v_before_tax := v_gross - v_discount;

  if p_tax_enabled and v_product.tax_class = 'taxable' and p_default_code is not null then
    v_rate_row := public.resolve_effective_tax_rate_version(
      p_tenant_id,
      p_default_code,
      p_invoice_date,
      p_invoice_date >= current_date
    );
    v_tax_rate_id := v_rate_row.id;
    v_tax_rate := v_rate_row.rate;
    v_taxable := v_before_tax;
    v_tax_amount := public.round_money(v_taxable * v_tax_rate / 100, p_decimal_places);
  elsif p_tax_enabled and v_product.tax_class = 'zero_rated' then
    v_taxable := v_before_tax;
    v_tax_rate := 0;
    v_tax_rate_id := null;
    v_tax_amount := 0;
  else
    v_tax_rate := 0;
    v_tax_rate_id := null;
    v_taxable := 0;
    v_tax_amount := 0;
  end if;

  v_after_tax := v_before_tax + v_tax_amount;

  return jsonb_build_object(
    'product_id', p_product_id,
    'tax_class', v_product.tax_class,
    'gross_amount', v_gross,
    'discount_amount', v_discount,
    'before_tax_amount', v_before_tax,
    'tax_rate_id', v_tax_rate_id,
    'tax_rate', v_tax_rate,
    'taxable_amount', v_taxable,
    'tax_amount', v_tax_amount,
    'after_tax_amount', v_after_tax,
    'line_total', v_after_tax
  );
end;
$$;

create or replace function public.calculate_invoice_totals_internal(
  p_tenant_id uuid,
  p_type text,
  p_date date,
  p_lines jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_decimal_places integer;
  v_tax_enabled boolean;
  v_default_code text;
  v_line jsonb;
  v_line_result jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_subtotal numeric := 0;
  v_discount_total numeric := 0;
  v_tax_total numeric := 0;
  v_total numeric := 0;
  v_qty numeric;
  v_unit_price numeric;
  v_discount_pct numeric;
  v_key text;
  v_forbidden text[] := array[
    'tax_rate', 'tax_rate_id', 'tax_amount', 'taxable_amount',
    'gross_amount', 'discount_amount', 'before_tax_amount', 'after_tax_amount',
    'line_total', 'subtotal', 'total', 'tax_total', 'discount_total'
  ];
begin
  if p_type not in ('sales', 'purchase') then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_lines) <> 'array' then
    raise exception 'validation_failed';
  end if;

  if jsonb_array_length(p_lines) > 500 then
    raise exception 'validation_failed';
  end if;

  v_decimal_places := public.resolve_tenant_money_precision(p_tenant_id);

  select ts.tax_enabled, tr.code
  into v_tax_enabled, v_default_code
  from public.tenant_settings ts
  left join public.tax_rates tr on tr.tenant_id = ts.tenant_id
    and tr.id = ts.default_tax_rate_id
  where ts.tenant_id = p_tenant_id;

  for v_line in select value from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(v_line) <> 'object' then
      raise exception 'validation_failed';
    end if;

    foreach v_key in array v_forbidden loop
      if v_line ? v_key then
        raise exception 'validation_failed';
      end if;
    end loop;

    if not (v_line ? 'product_id' and v_line ? 'qty' and v_line ? 'unit_price' and v_line ? 'discount_pct') then
      raise exception 'validation_failed';
    end if;

    v_qty := (v_line ->> 'qty')::numeric;
    v_unit_price := (v_line ->> 'unit_price')::numeric;
    v_discount_pct := coalesce((v_line ->> 'discount_pct')::numeric, 0);

    if v_qty <= 0 or v_unit_price < 0 or v_discount_pct < 0 or v_discount_pct > 100 then
      raise exception 'validation_failed';
    end if;

    v_line_result := public.calculate_invoice_line_snapshot(
      p_tenant_id,
      (v_line ->> 'product_id')::uuid,
      p_date,
      v_qty,
      v_unit_price,
      v_discount_pct,
      v_decimal_places,
      coalesce(v_tax_enabled, false),
      v_default_code
    );

    if v_line ? 'line_order' then
      v_line_result := v_line_result || jsonb_build_object('line_order', v_line -> 'line_order');
    end if;

    v_subtotal := v_subtotal + (v_line_result ->> 'gross_amount')::numeric;
    v_discount_total := v_discount_total + (v_line_result ->> 'discount_amount')::numeric;
    v_tax_total := v_tax_total + (v_line_result ->> 'tax_amount')::numeric;
    v_lines := v_lines || jsonb_build_array(v_line_result);
  end loop;

  v_total := v_subtotal - v_discount_total + v_tax_total;

  return jsonb_build_object(
    'lines', v_lines,
    'subtotal', v_subtotal,
    'discount_amount', v_discount_total,
    'tax_amount', v_tax_total,
    'total', v_total
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Public RPCs
-- ---------------------------------------------------------------------------
create or replace function public.list_tax_rates(
  p_active_only boolean default true,
  p_limit integer default 100,
  p_offset integer default 0
)
returns setof public.tax_rates
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_tax_settings_read();

  return query
  select tr.*
  from public.tax_rates tr
  where tr.tenant_id = v_tenant_id
    and (not p_active_only or tr.is_active)
  order by tr.code, tr.effective_from desc
  limit greatest(least(coalesce(p_limit, 100), 500), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.create_tax_rate(p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_code text;
  v_effective_from date;
  v_max_effective_from date;
  v_rate numeric(9, 6);
  v_name_ar text;
  v_name_en text;
  v_is_recoverable boolean;
  v_output_account_id uuid;
  v_input_account_id uuid;
  v_expense_account_id uuid;
  v_provisioned jsonb;
  v_new_id uuid;
  v_default_code text;
  v_open_id uuid;
  v_has_output boolean;
  v_has_input boolean;
  v_has_expense boolean;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_tax_settings_edit();

  v_code := btrim(p_data ->> 'code');
  v_name_ar := btrim(p_data ->> 'name_ar');
  v_name_en := btrim(p_data ->> 'name_en');
  v_effective_from := (p_data ->> 'effective_from')::date;
  v_rate := (p_data ->> 'rate')::numeric(9, 6);
  v_is_recoverable := coalesce((p_data ->> 'is_recoverable')::boolean, true);

  if v_code is null or v_code = ''
    or v_name_ar is null or v_name_ar = ''
    or v_name_en is null or v_name_en = ''
    or v_effective_from is null
    or v_rate is null then
    raise exception 'validation_failed';
  end if;

  if v_rate < 0 or v_rate > 100 then
    raise exception 'validation_failed';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_tenant_id::text || ':' || v_code, 0)
  );

  select max(effective_from) into v_max_effective_from
  from public.tax_rates
  where tenant_id = v_tenant_id
    and code = v_code;

  if v_max_effective_from is not null and v_effective_from <= v_max_effective_from then
    raise exception 'validation_failed';
  end if;

  v_has_output := p_data ? 'output_account_id';
  v_has_input := p_data ? 'input_account_id';
  v_has_expense := p_data ? 'expense_account_id';

  if (v_has_output or v_has_input or v_has_expense)
    and not (v_has_output and v_has_input and v_has_expense) then
    raise exception 'validation_failed';
  end if;

  if v_has_output then
    v_output_account_id := nullif(p_data ->> 'output_account_id', '')::uuid;
    v_input_account_id := nullif(p_data ->> 'input_account_id', '')::uuid;
    v_expense_account_id := nullif(p_data ->> 'expense_account_id', '')::uuid;
  end if;

  if not v_has_output then
    v_provisioned := public.provision_tenant_tax_accounts(v_tenant_id);
    v_output_account_id := (v_provisioned ->> 'output_account_id')::uuid;
    v_input_account_id := (v_provisioned ->> 'input_account_id')::uuid;
    v_expense_account_id := nullif(v_provisioned ->> 'expense_account_id', '')::uuid;
  end if;

  perform public.validate_tax_posting_account(
    v_tenant_id, v_output_account_id, 'liability', true
  );
  perform public.validate_tax_posting_account(
    v_tenant_id, v_input_account_id, 'asset', true
  );
  perform public.validate_tax_posting_account(
    v_tenant_id, v_expense_account_id, 'expense', false
  );

  perform 1
  from public.tax_rates
  where tenant_id = v_tenant_id
    and code = v_code
  for update;

  select id into v_open_id
  from public.tax_rates
  where tenant_id = v_tenant_id
    and code = v_code
    and effective_to is null
  order by effective_from desc
  limit 1;

  if v_open_id is not null and v_effective_from > (
    select effective_from from public.tax_rates where id = v_open_id
  ) then
    update public.tax_rates
    set effective_to = v_effective_from - interval '1 day',
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_open_id;
  end if;

  insert into public.tax_rates (
    tenant_id, code, name_ar, name_en, rate, effective_from,
    output_account_id, input_account_id, expense_account_id,
    is_recoverable, is_active, created_by, updated_by
  )
  values (
    v_tenant_id, v_code, v_name_ar, v_name_en, v_rate, v_effective_from,
    v_output_account_id, v_input_account_id, v_expense_account_id,
    v_is_recoverable, true, auth.uid(), auth.uid()
  )
  returning id into v_new_id;

  v_default_code := public.default_tax_series_code(v_tenant_id);
  if v_default_code is not null and v_default_code = v_code then
    perform public.advance_default_tax_rate_anchor(v_tenant_id, v_code, v_new_id);
  end if;

  return v_new_id;
exception
  when exclusion_violation then
    raise exception 'tax_rate_overlap';
end;
$$;

create or replace function public.update_tax_rate(
  p_id uuid,
  p_data jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_key text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_tax_settings_edit();

  for v_key in select jsonb_object_keys(p_data) loop
    if v_key not in ('name_ar', 'name_en') then
      raise exception 'validation_failed';
    end if;
  end loop;

  update public.tax_rates
  set
    name_ar = coalesce(nullif(btrim(p_data ->> 'name_ar'), ''), name_ar),
    name_en = coalesce(nullif(btrim(p_data ->> 'name_en'), ''), name_en),
    updated_at = now(),
    updated_by = auth.uid()
  where id = p_id
    and tenant_id = v_tenant_id;

  if not found then
    raise exception 'tax_rate_not_found';
  end if;
end;
$$;

create or replace function public.activate_tax_rate(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_tax_settings_edit();

  update public.tax_rates
  set is_active = true, updated_at = now(), updated_by = auth.uid()
  where id = p_id and tenant_id = v_tenant_id;

  if not found then
    raise exception 'tax_rate_not_found';
  end if;
end;
$$;

create or replace function public.deactivate_tax_rate(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_rate public.tax_rates%rowtype;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_tax_settings_edit();

  select * into v_rate
  from public.tax_rates
  where id = p_id and tenant_id = v_tenant_id;

  if not found then
    raise exception 'tax_rate_not_found';
  end if;

  if public.is_default_series_protected_version(v_tenant_id, v_rate) then
    raise exception 'validation_failed';
  end if;

  update public.tax_rates
  set is_active = false, updated_at = now(), updated_by = auth.uid()
  where id = p_id and tenant_id = v_tenant_id;
end;
$$;

create or replace function public.update_tax_settings(p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_current_tax_enabled boolean;
  v_current_default_rate_id uuid;
  v_target_enabled boolean;
  v_target_default_id uuid;
  v_default_rate public.tax_rates%rowtype;
  v_key text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_tax_settings_edit();

  for v_key in select jsonb_object_keys(p_data) loop
    if v_key not in ('tax_enabled', 'tax_registration_number', 'default_tax_rate_id') then
      raise exception 'validation_failed';
    end if;
  end loop;

  select ts.tax_enabled, ts.default_tax_rate_id
  into v_current_tax_enabled, v_current_default_rate_id
  from public.tenant_settings ts
  where ts.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'tenant_not_found';
  end if;

  v_target_enabled := case
    when p_data ? 'tax_enabled' then (p_data ->> 'tax_enabled')::boolean
    else coalesce(v_current_tax_enabled, false)
  end;

  v_target_default_id := case
    when p_data ? 'default_tax_rate_id' then nullif(p_data ->> 'default_tax_rate_id', '')::uuid
    else v_current_default_rate_id
  end;

  if v_target_enabled then
    if v_target_default_id is null then
      raise exception 'validation_failed';
    end if;

    select * into v_default_rate
    from public.tax_rates
    where id = v_target_default_id and tenant_id = v_tenant_id;

    if not found then
      raise exception 'cross_tenant_reference';
    end if;

    if not v_default_rate.is_active then
      raise exception 'validation_failed';
    end if;

    perform public.resolve_effective_tax_rate_version(
      v_tenant_id,
      v_default_rate.code,
      current_date,
      true
    );
  end if;

  perform public.allow_tax_settings_write();

  update public.tenant_settings
  set
    tax_enabled = v_target_enabled,
    tax_registration_number = case
      when p_data ? 'tax_registration_number'
        then nullif(btrim(p_data ->> 'tax_registration_number'), '')
      else tax_registration_number
    end,
    default_tax_rate_id = v_target_default_id
  where tenant_id = v_tenant_id;
end;
$$;

create or replace function public.get_effective_tax_rate(
  p_product_id uuid,
  p_invoice_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_product public.products%rowtype;
  v_default_code text;
  v_rate_row public.tax_rates;
  v_require_active boolean;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_tax_settings_read();

  select * into v_product
  from public.products
  where id = p_product_id and tenant_id = v_tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if not exists (
    select 1 from public.tenant_settings
    where tenant_id = v_tenant_id and tax_enabled
  ) then
    return jsonb_build_object(
      'product_id', p_product_id,
      'tax_class', v_product.tax_class,
      'tax_rate_id', null,
      'tax_rate', 0
    );
  end if;

  v_default_code := public.default_tax_series_code(v_tenant_id);
  if v_default_code is null
    or v_product.tax_class in ('exempt', 'non_taxable', 'zero_rated') then
    return jsonb_build_object(
      'product_id', p_product_id,
      'tax_class', v_product.tax_class,
      'tax_rate_id', null,
      'tax_rate', 0
    );
  end if;

  v_require_active := p_invoice_date >= current_date;
  v_rate_row := public.resolve_effective_tax_rate_version(
    v_tenant_id,
    v_default_code,
    p_invoice_date,
    v_require_active
  );

  return jsonb_build_object(
    'product_id', p_product_id,
    'tax_class', v_product.tax_class,
    'tax_rate_id', v_rate_row.id,
    'tax_rate', v_rate_row.rate,
    'code', v_rate_row.code,
    'effective_from', v_rate_row.effective_from,
    'effective_to', v_rate_row.effective_to
  );
exception
  when others then
    if sqlstate = 'P0001' and sqlerrm like '%tax_rate_not_found%' then
      raise exception 'tax_rate_not_found';
    end if;
    raise;
end;
$$;

create or replace function public.calculate_invoice_totals(
  p_type text,
  p_date date,
  p_lines jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_type = 'purchase' then
    if not (
      public.is_manager()
      or public.user_has_permission('invoices.create_purchase')
      or public.user_has_permission('invoices.view_purchase')
    ) then
      raise exception 'permission_denied';
    end if;
  elsif p_type = 'sales' then
    if not (
      public.is_manager()
      or public.user_has_permission('invoices.create_sales')
      or public.user_has_permission('invoices.view_sales')
      or public.user_has_permission('invoices.edit_draft')
    ) then
      raise exception 'permission_denied';
    end if;
  else
    raise exception 'validation_failed';
  end if;

  return public.calculate_invoice_totals_internal(
    v_tenant_id,
    p_type,
    p_date,
    p_lines
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS and ACL
-- ---------------------------------------------------------------------------
alter table public.tax_rates enable row level security;

create policy tax_rates_select on public.tax_rates
  for select using (
    tenant_id = public.current_tenant_id()
    and (
      public.is_manager()
      or public.user_has_permission('settings.tax.view')
      or public.user_has_permission('settings.tax.edit')
    )
  );

revoke all on public.tax_rates from public, anon, authenticated;
grant select on public.tax_rates to authenticated;

create trigger trg_audit_tax_rates_insert
  after insert on public.tax_rates
  for each row execute function public.audit_log_row();

create trigger trg_audit_tax_rates_update
  after update on public.tax_rates
  for each row execute function public.audit_log_row();

revoke all on function public.allow_tax_settings_write() from public, anon, authenticated;
revoke all on function public.allow_tax_account_provisioning() from public, anon, authenticated;
revoke all on function public.advance_default_tax_rate_anchor(uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.provision_tenant_tax_accounts(uuid) from public, anon, authenticated;
revoke all on function public.validate_tax_posting_account(uuid, uuid, public.account_type, boolean) from public, anon, authenticated;
revoke all on function public.resolve_or_insert_tax_system_account(uuid, text, text, text, public.account_type, text) from public, anon, authenticated;
revoke all on function public.resolve_tenant_money_precision(uuid) from public, anon, authenticated;
revoke all on function public.round_money(numeric, integer) from public, anon, authenticated;
revoke all on function public.resolve_effective_tax_rate_version(uuid, text, date, boolean) from public, anon, authenticated;
revoke all on function public.default_tax_series_code(uuid) from public, anon, authenticated;
revoke all on function public.is_default_series_protected_version(uuid, public.tax_rates) from public, anon, authenticated;
revoke all on function public.calculate_invoice_line_snapshot(uuid, uuid, date, numeric, numeric, numeric, integer, boolean, text) from public, anon, authenticated;
revoke all on function public.calculate_invoice_totals_internal(uuid, text, date, jsonb) from public, anon, authenticated;
revoke all on function public.assert_tax_settings_read() from public, anon, authenticated;
revoke all on function public.assert_tax_settings_edit() from public, anon, authenticated;
revoke all on function public.is_reserved_tax_account_code(text) from public, anon, authenticated;

grant execute on function public.list_tax_rates(boolean, integer, integer) to authenticated;
grant execute on function public.create_tax_rate(jsonb) to authenticated;
grant execute on function public.update_tax_rate(uuid, jsonb) to authenticated;
grant execute on function public.activate_tax_rate(uuid) to authenticated;
grant execute on function public.deactivate_tax_rate(uuid) to authenticated;
grant execute on function public.update_tax_settings(jsonb) to authenticated;
grant execute on function public.get_effective_tax_rate(uuid, date) to authenticated;
grant execute on function public.calculate_invoice_totals(text, date, jsonb) to authenticated;
