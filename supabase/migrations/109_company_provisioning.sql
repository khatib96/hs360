-- Company provisioning and inventory-gain account correction.
--
-- 1. Inventory gains move to their own account 4901. Migration 064 created
--    4102 as "Sales returns" and migration 066 then reused 4102 for
--    "Inventory Gain", so found-surplus stock postings landed in the sales
--    returns account. 4102 stays Sales returns; found_surplus now posts to
--    4901.
-- 2. Inventory system accounts and adjustment reasons get Arabic names
--    (they were created with English text in name_ar).
-- 3. provision_company() creates a complete, usable company from zero:
--    tenant, default currency, settings, base chart of accounts, tax and
--    inventory accounts, adjustment reasons, main warehouse, and the owner as
--    manager. Document sequences, templates, and calendar settings come from
--    the existing tenants insert triggers. Callable by service_role only.

-- ---------------------------------------------------------------------------
-- 1 + 2. Inventory accounts and reasons
-- ---------------------------------------------------------------------------
create or replace function public.provision_tenant_inventory_accounts(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '3101',
    U&'\062D\0642\0648\0642 \0645\0644\0643\064A\0629 \0627\0644\0623\0631\0635\062F\0629 \0627\0644\0627\0641\062A\062A\0627\062D\064A\0629' UESCAPE '\',
    'Opening Balance Equity', 'equity', '3000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '3102',
    U&'\0631\0623\0633 \0645\0627\0644 \0627\0644\0645\0627\0644\0643' UESCAPE '\',
    'Owner''s Capital', 'equity', '3000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '3201',
    U&'\0645\0633\062D\0648\0628\0627\062A \0627\0644\0645\0627\0644\0643' UESCAPE '\',
    'Owner''s Drawings', 'equity', '3000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '4901',
    U&'\0623\0631\0628\0627\062D \0641\0631\0648\0642\0627\062A \0627\0644\0645\062E\0632\0648\0646' UESCAPE '\',
    'Inventory Gain', 'income', '4000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '5152',
    U&'\062E\0633\0627\0626\0631 \0648\062A\0633\0648\064A\0627\062A \0627\0644\0645\062E\0632\0648\0646' UESCAPE '\',
    'Inventory Loss / Adjustment', 'expense', '5000'
  );
  perform public.resolve_or_insert_inventory_system_account(
    p_tenant_id, '5901',
    U&'\0645\0635\0631\0648\0641 \0627\0644\0627\0633\062A\0647\0644\0627\0643 \0627\0644\062F\0627\062E\0644\064A' UESCAPE '\',
    'Internal Consumption Expense', 'expense', '5000'
  );
end;
$$;

create or replace function public.seed_tenant_inventory_adjustment_reasons(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_capital uuid;
  v_gain uuid;
  v_loss uuid;
  v_drawings uuid;
  v_consumption uuid;
begin
  perform public.provision_tenant_inventory_accounts(p_tenant_id);

  select id into v_capital from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '3102';
  select id into v_gain from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '4901';
  select id into v_loss from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '5152';
  select id into v_drawings from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '3201';
  select id into v_consumption from public.chart_of_accounts
  where tenant_id = p_tenant_id and code = '5901';

  insert into public.inventory_adjustment_reasons (
    tenant_id, code, name_ar, name_en, direction, account_id,
    requires_cost, allows_wac_fallback, is_system, is_active, allowed_document_types
  )
  values
    (
      p_tenant_id, 'owner_contribution',
      U&'\0645\0633\0627\0647\0645\0629 \0627\0644\0645\0627\0644\0643' UESCAPE '\',
      'Owner contribution', 'stock_in', v_capital,
      true, false, true, true, array['stock_in']
    ),
    (
      p_tenant_id, 'found_surplus',
      U&'\0641\0627\0626\0636 \0645\0648\062C\0648\062F' UESCAPE '\',
      'Found surplus', 'stock_in', v_gain,
      false, true, true, true, array['stock_in', 'stock_count']
    ),
    (
      p_tenant_id, 'shrinkage',
      U&'\0639\062C\0632' UESCAPE '\',
      'Shrinkage', 'stock_out', v_loss,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'damage',
      U&'\062A\0644\0641' UESCAPE '\',
      'Damage', 'stock_out', v_loss,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'expiry',
      U&'\0627\0646\062A\0647\0627\0621 \0635\0644\0627\062D\064A\0629' UESCAPE '\',
      'Expiry', 'stock_out', v_loss,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'write_off',
      U&'\0634\0637\0628' UESCAPE '\',
      'Write-off', 'stock_out', v_loss,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'owner_withdrawal',
      U&'\0633\062D\0628 \0627\0644\0645\0627\0644\0643' UESCAPE '\',
      'Owner withdrawal', 'stock_out', v_drawings,
      false, false, true, true, array['stock_out', 'stock_count']
    ),
    (
      p_tenant_id, 'internal_consumption',
      U&'\0627\0633\062A\0647\0644\0627\0643 \062F\0627\062E\0644\064A' UESCAPE '\',
      'Internal consumption', 'stock_out', v_consumption,
      false, false, true, true, array['stock_out', 'stock_count']
    )
  on conflict (tenant_id, code) do nothing;
end;
$$;

revoke all on function public.provision_tenant_inventory_accounts(uuid) from public, anon, authenticated;
revoke all on function public.seed_tenant_inventory_adjustment_reasons(uuid) from public, anon, authenticated;

-- Backfill existing tenants: create 4901, repoint found_surplus, and replace
-- English text stored in name_ar for inventory accounts and reasons.
do $$
declare
  v_tenant_id uuid;
begin
  perform set_config('hs360.finance_write', '1', true);

  for v_tenant_id in
    select t.id
    from public.tenants t
    where exists (
      select 1 from public.chart_of_accounts c
      where c.tenant_id = t.id and c.code = '4000'
    )
  loop
    perform public.provision_tenant_inventory_accounts(v_tenant_id);

    update public.inventory_adjustment_reasons r
    set account_id = gain.id
    from public.chart_of_accounts gain
    where r.tenant_id = v_tenant_id
      and r.code = 'found_surplus'
      and gain.tenant_id = v_tenant_id
      and gain.code = '4901'
      and r.account_id is distinct from gain.id;
  end loop;

  update public.inventory_adjustment_reasons r
  set name_ar = v.name_ar
  from (
    values
      ('owner_contribution', U&'\0645\0633\0627\0647\0645\0629 \0627\0644\0645\0627\0644\0643' UESCAPE '\'),
      ('found_surplus', U&'\0641\0627\0626\0636 \0645\0648\062C\0648\062F' UESCAPE '\'),
      ('shrinkage', U&'\0639\062C\0632' UESCAPE '\'),
      ('damage', U&'\062A\0644\0641' UESCAPE '\'),
      ('expiry', U&'\0627\0646\062A\0647\0627\0621 \0635\0644\0627\062D\064A\0629' UESCAPE '\'),
      ('write_off', U&'\0634\0637\0628' UESCAPE '\'),
      ('owner_withdrawal', U&'\0633\062D\0628 \0627\0644\0645\0627\0644\0643' UESCAPE '\'),
      ('internal_consumption', U&'\0627\0633\062A\0647\0644\0627\0643 \062F\0627\062E\0644\064A' UESCAPE '\')
  ) as v(code, name_ar)
  where r.code = v.code
    and r.is_system
    and r.name_ar = r.name_en;

  perform set_config('hs360.finance_write', '', true);
end $$;

alter table public.chart_of_accounts disable trigger trg_enforce_chart_account_protection;

update public.chart_of_accounts c
set name_ar = v.name_ar
from (
  values
    ('3101', 'Opening Balance Equity', U&'\062D\0642\0648\0642 \0645\0644\0643\064A\0629 \0627\0644\0623\0631\0635\062F\0629 \0627\0644\0627\0641\062A\062A\0627\062D\064A\0629' UESCAPE '\'),
    ('3102', 'Owner Capital', U&'\0631\0623\0633 \0645\0627\0644 \0627\0644\0645\0627\0644\0643' UESCAPE '\'),
    ('3201', 'Owner Drawings', U&'\0645\0633\062D\0648\0628\0627\062A \0627\0644\0645\0627\0644\0643' UESCAPE '\'),
    ('5152', 'Inventory Loss', U&'\062E\0633\0627\0626\0631 \0648\062A\0633\0648\064A\0627\062A \0627\0644\0645\062E\0632\0648\0646' UESCAPE '\'),
    ('5901', 'Internal Consumption', U&'\0645\0635\0631\0648\0641 \0627\0644\0627\0633\062A\0647\0644\0627\0643 \0627\0644\062F\0627\062E\0644\064A' UESCAPE '\')
) as v(code, old_name_ar, name_ar)
where c.code = v.code
  and c.is_system
  and c.name_ar = v.old_name_ar;

alter table public.chart_of_accounts enable trigger trg_enforce_chart_account_protection;

-- ---------------------------------------------------------------------------
-- 3. provision_company
-- ---------------------------------------------------------------------------
create or replace function public.provision_company(p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name_ar text := nullif(btrim(p_data ->> 'name_ar'), '');
  v_name_en text := nullif(btrim(p_data ->> 'name_en'), '');
  v_slug text := nullif(btrim(p_data ->> 'slug'), '');
  v_country text := upper(coalesce(nullif(btrim(p_data ->> 'country_code'), ''), 'KW'));
  v_timezone text := coalesce(nullif(btrim(p_data ->> 'timezone'), ''), 'Asia/Kuwait');
  v_locale text := coalesce(nullif(btrim(p_data ->> 'default_locale'), ''), 'ar');
  v_owner_user_id uuid := nullif(p_data ->> 'owner_user_id', '')::uuid;
  v_owner_name text := nullif(btrim(p_data ->> 'owner_display_name'), '');
  v_currency jsonb := coalesce(p_data -> 'currency', '{}'::jsonb);
  v_iso text := upper(nullif(btrim(v_currency ->> 'iso_code'), ''));
  v_decimals int := coalesce((v_currency ->> 'decimal_places')::int, 2);
  v_tenant_id uuid;
  v_currency_id uuid;
  v_root_asset uuid;
  v_root_liability uuid;
  v_root_equity uuid;
  v_root_income uuid;
  v_root_expense uuid;
begin
  if v_name_ar is null or v_name_en is null or v_slug is null
     or v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
     or v_country !~ '^[A-Z]{2}$'
     or v_locale not in ('ar', 'en')
     or not exists (select 1 from pg_timezone_names where name = v_timezone)
     or v_iso is null or v_iso !~ '^[A-Z]{3}$'
     -- Money is stored as numeric(15,3): more than 3 decimals cannot be kept.
     or v_decimals not between 0 and 3
     or nullif(btrim(v_currency ->> 'major_name_ar'), '') is null
     or nullif(btrim(v_currency ->> 'major_name_en'), '') is null
     or nullif(btrim(v_currency ->> 'major_symbol_ar'), '') is null
     or nullif(btrim(v_currency ->> 'major_symbol_en'), '') is null
     or coalesce(v_currency ->> 'symbol_position', 'after') not in ('before', 'after')
  then
    raise exception 'validation_failed';
  end if;

  if exists (select 1 from public.tenants where slug = v_slug) then
    raise exception 'company_slug_taken';
  end if;

  if v_owner_user_id is null
     or not exists (select 1 from auth.users where id = v_owner_user_id) then
    raise exception 'owner_user_not_found';
  end if;

  -- Until company switching exists, one login belongs to one company: the
  -- tenant helpers pick a single tenant_users row per user.
  if exists (
    select 1 from public.tenant_users where user_id = v_owner_user_id
  ) then
    raise exception 'owner_already_member';
  end if;

  insert into public.tenants (name, slug, default_locale, country_code, timezone)
  values (v_name_en, v_slug, v_locale, v_country, v_timezone)
  returning id into v_tenant_id;

  insert into public.currencies (
    tenant_id, iso_code, major_name_ar, major_name_en, major_symbol_ar,
    major_symbol_en, minor_name_ar, minor_name_en, minor_symbol_ar,
    minor_symbol_en, decimal_places, minor_units_per_major, symbol_position,
    is_default, sort_order
  )
  values (
    v_tenant_id,
    v_iso,
    btrim(v_currency ->> 'major_name_ar'),
    btrim(v_currency ->> 'major_name_en'),
    btrim(v_currency ->> 'major_symbol_ar'),
    btrim(v_currency ->> 'major_symbol_en'),
    nullif(btrim(v_currency ->> 'minor_name_ar'), ''),
    nullif(btrim(v_currency ->> 'minor_name_en'), ''),
    nullif(btrim(v_currency ->> 'minor_symbol_ar'), ''),
    nullif(btrim(v_currency ->> 'minor_symbol_en'), ''),
    v_decimals,
    coalesce((v_currency ->> 'minor_units_per_major')::int, (10 ^ v_decimals)::int),
    coalesce(v_currency ->> 'symbol_position', 'after'),
    true,
    1
  )
  returning id into v_currency_id;

  update public.tenants
  set default_currency_id = v_currency_id
  where id = v_tenant_id;

  insert into public.tenant_settings (tenant_id, company_name_ar, company_name_en)
  values (v_tenant_id, v_name_ar, v_name_en);

  -- Base chart of accounts (same codes the posting engines resolve).
  insert into public.chart_of_accounts (tenant_id, code, name_ar, name_en, type, is_system)
  values (v_tenant_id, '1000', U&'\0627\0644\0623\0635\0648\0644' UESCAPE '\', 'Assets', 'asset', true)
  returning id into v_root_asset;
  insert into public.chart_of_accounts (tenant_id, code, name_ar, name_en, type, is_system)
  values (v_tenant_id, '2000', U&'\0627\0644\062E\0635\0648\0645' UESCAPE '\', 'Liabilities', 'liability', true)
  returning id into v_root_liability;
  insert into public.chart_of_accounts (tenant_id, code, name_ar, name_en, type, is_system)
  values (v_tenant_id, '3000', U&'\062D\0642\0648\0642 \0627\0644\0645\0644\0643\064A\0629' UESCAPE '\', 'Equity', 'equity', true)
  returning id into v_root_equity;
  insert into public.chart_of_accounts (tenant_id, code, name_ar, name_en, type, is_system)
  values (v_tenant_id, '4000', U&'\0627\0644\0625\064A\0631\0627\062F\0627\062A' UESCAPE '\', 'Revenue', 'income', true)
  returning id into v_root_income;
  insert into public.chart_of_accounts (tenant_id, code, name_ar, name_en, type, is_system)
  values (v_tenant_id, '5000', U&'\0627\0644\0645\0635\0631\0648\0641\0627\062A' UESCAPE '\', 'Expenses', 'expense', true)
  returning id into v_root_expense;

  insert into public.chart_of_accounts (
    tenant_id, code, name_ar, name_en, type, parent_id, is_system
  )
  values
    (v_tenant_id, '1101', U&'\0627\0644\0635\0646\062F\0648\0642' UESCAPE '\', 'Cash on hand', 'asset', v_root_asset, true),
    (v_tenant_id, '1102', U&'\0627\0644\0628\0646\0643 \0627\0644\0631\0626\064A\0633\064A' UESCAPE '\', 'Main bank', 'asset', v_root_asset, true),
    (v_tenant_id, '1160', U&'\0630\0645\0645 \0645\0631\062A\062C\0639\0627\062A \0627\0644\0645\0648\0631\062F\064A\0646' UESCAPE '\', 'Supplier credits receivable', 'asset', v_root_asset, true),
    (v_tenant_id, '1201', U&'\0630\0645\0645 \0627\0644\0639\0645\0644\0627\0621' UESCAPE '\', 'Accounts receivable', 'asset', v_root_asset, true),
    (v_tenant_id, '1301', U&'\0627\0644\0645\062E\0632\0648\0646' UESCAPE '\', 'Inventory', 'asset', v_root_asset, true),
    (v_tenant_id, '2101', U&'\0630\0645\0645 \0627\0644\0645\0648\0631\062F\064A\0646' UESCAPE '\', 'Accounts payable', 'liability', v_root_liability, true),
    (v_tenant_id, '2150', U&'\0627\0626\062A\0645\0627\0646\0627\062A \0627\0644\0639\0645\0644\0627\0621' UESCAPE '\', 'Customer credits', 'liability', v_root_liability, true),
    (v_tenant_id, '4101', U&'\0625\064A\0631\0627\062F\0627\062A \0627\0644\0645\0628\064A\0639\0627\062A' UESCAPE '\', 'Sales revenue', 'income', v_root_income, true),
    (v_tenant_id, '4102', U&'\0645\0631\062A\062C\0639\0627\062A \0627\0644\0645\0628\064A\0639\0627\062A' UESCAPE '\', 'Sales returns', 'income', v_root_income, true),
    (v_tenant_id, '5101', U&'\062A\0643\0644\0641\0629 \0627\0644\0628\0636\0627\0639\0629' UESCAPE '\', 'Cost of goods sold', 'expense', v_root_expense, true),
    (v_tenant_id, '6101', U&'\0645\0635\0631\0648\0641\0627\062A \0639\0627\0645\0629' UESCAPE '\', 'General expenses', 'expense', v_root_expense, true);

  perform public.provision_tenant_tax_accounts(v_tenant_id);

  perform set_config('hs360.finance_write', '1', true);
  perform public.seed_tenant_inventory_adjustment_reasons(v_tenant_id);
  perform set_config('hs360.finance_write', '', true);

  insert into public.warehouses (tenant_id, name_ar, name_en, type)
  values (
    v_tenant_id,
    U&'\0627\0644\0645\062E\0632\0646 \0627\0644\0631\0626\064A\0633\064A' UESCAPE '\',
    'Main warehouse',
    'main'
  );

  insert into public.tenant_users (
    tenant_id, user_id, account_type, display_name, preferred_locale, is_active
  )
  values (
    v_tenant_id, v_owner_user_id, 'manager', v_owner_name, v_locale, true
  );

  return v_tenant_id;
end;
$$;

comment on function public.provision_company(jsonb) is
  'Creates a complete company (tenant) from zero with its owner as manager. service_role only.';

revoke all on function public.provision_company(jsonb) from public, anon, authenticated;
grant execute on function public.provision_company(jsonb) to service_role;
