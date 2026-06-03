-- M7.5: Chart of accounts hierarchy (5 category roots) + Arabic name repair.
-- Transport-safe: all Arabic via U&'\....' UESCAPE '\' (survives PowerShell psql < piping).
--
-- Disabling only trg_enforce_chart_account_protection (not session_replication_role = replica)
-- so audit/FK/other triggers stay enforced; re-enabled before commit.
-- SECURITY DEFINER RPC does not bypass row triggers; targeted disable is required to reparent
-- is_system rows.

-- ---------------------------------------------------------------------------
-- Step 1: Fail-fast duplicate check; idempotently ensure unique (tenant_id, code).
-- ---------------------------------------------------------------------------
do $$
declare
  v_dupes text;
begin
  select string_agg(
    format('tenant=%s code=%s count=%s', tenant_id, code, cnt),
    '; '
  )
  into v_dupes
  from (
    select tenant_id, code, count(*) as cnt
    from chart_of_accounts
    group by tenant_id, code
    having count(*) > 1
  ) d;

  if v_dupes is not null then
    raise exception 'duplicate_chart_account_codes: %', v_dupes;
  end if;

  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on c.conrelid = t.oid
    join pg_namespace n on t.relnamespace = n.oid
    where n.nspname = 'public'
      and t.relname = 'chart_of_accounts'
      and c.contype = 'u'
      and pg_get_constraintdef(c.oid) ~ 'tenant_id.*code|code.*tenant_id'
  ) and not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'chart_of_accounts'
      and indexdef ~* 'unique.*\(tenant_id.*code|unique.*\(code.*tenant_id'
  ) then
    alter table chart_of_accounts
      add constraint uq_coa_tenant_code unique (tenant_id, code);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Step 2: Disable only the system-account protection trigger.
-- ---------------------------------------------------------------------------
alter table chart_of_accounts disable trigger trg_enforce_chart_account_protection;

-- ---------------------------------------------------------------------------
-- Step 3: Insert 5 protected category roots per tenant with seeded system accounts.
-- ---------------------------------------------------------------------------
do $$
declare
  v_tenant_id uuid;
begin
  for v_tenant_id in
    select distinct tenant_id
    from chart_of_accounts
    where code in (
      '1101', '1102', '1201', '1301', '2101', '4101', '5101', '6101'
    )
  loop
    insert into chart_of_accounts (
      id, tenant_id, code, name_ar, name_en, type, is_system
    )
    values
      (
        gen_random_uuid(), v_tenant_id, '1000',
        U&'\0627\0644\0623\0635\0648\0644' UESCAPE '\',
        'Assets', 'asset', true
      ),
      (
        gen_random_uuid(), v_tenant_id, '2000',
        U&'\0627\0644\062E\0635\0648\0645' UESCAPE '\',
        'Liabilities', 'liability', true
      ),
      (
        gen_random_uuid(), v_tenant_id, '3000',
        U&'\062D\0642\0648\0642 \0627\0644\0645\0644\0643\064A\0629' UESCAPE '\',
        'Equity', 'equity', true
      ),
      (
        gen_random_uuid(), v_tenant_id, '4000',
        U&'\0627\0644\0625\064A\0631\0627\062F\0627\062A' UESCAPE '\',
        'Revenue', 'income', true
      ),
      (
        gen_random_uuid(), v_tenant_id, '5000',
        U&'\0627\0644\0645\0635\0631\0648\0641\0627\062A' UESCAPE '\',
        'Expenses', 'expense', true
      )
    on conflict (tenant_id, code) do nothing;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Step 4: Reparent seeded system leaf accounts under the matching category root.
-- ---------------------------------------------------------------------------
update chart_of_accounts leaf
set parent_id = root.id
from chart_of_accounts root
where leaf.tenant_id = root.tenant_id
  and root.code = '1000'
  and leaf.code in ('1101', '1102', '1201', '1301')
  and leaf.is_system = true
  and leaf.related_entity_id is null
  and leaf.parent_id is distinct from root.id;

update chart_of_accounts leaf
set parent_id = root.id
from chart_of_accounts root
where leaf.tenant_id = root.tenant_id
  and root.code = '2000'
  and leaf.code = '2101'
  and leaf.is_system = true
  and leaf.related_entity_id is null
  and leaf.parent_id is distinct from root.id;

update chart_of_accounts leaf
set parent_id = root.id
from chart_of_accounts root
where leaf.tenant_id = root.tenant_id
  and root.code = '4000'
  and leaf.code = '4101'
  and leaf.is_system = true
  and leaf.related_entity_id is null
  and leaf.parent_id is distinct from root.id;

update chart_of_accounts leaf
set parent_id = root.id
from chart_of_accounts root
where leaf.tenant_id = root.tenant_id
  and root.code = '5000'
  and leaf.code in ('5101', '6101')
  and leaf.is_system = true
  and leaf.related_entity_id is null
  and leaf.parent_id is distinct from root.id;

-- ---------------------------------------------------------------------------
-- Step 5: Repair Arabic names (roots + system leaves) with transport-safe escapes.
-- ---------------------------------------------------------------------------
update chart_of_accounts
set name_ar = U&'\0627\0644\0623\0635\0648\0644' UESCAPE '\'
where code = '1000';

update chart_of_accounts
set name_ar = U&'\0627\0644\062E\0635\0648\0645' UESCAPE '\'
where code = '2000';

update chart_of_accounts
set name_ar = U&'\062D\0642\0648\0642 \0627\0644\0645\0644\0643\064A\0629' UESCAPE '\'
where code = '3000';

update chart_of_accounts
set name_ar = U&'\0627\0644\0625\064A\0631\0627\062F\0627\062A' UESCAPE '\'
where code = '4000';

update chart_of_accounts
set name_ar = U&'\0627\0644\0645\0635\0631\0648\0641\0627\062A' UESCAPE '\'
where code = '5000';

update chart_of_accounts
set name_ar = U&'\0627\0644\0635\0646\062F\0648\0642' UESCAPE '\'
where code = '1101';

update chart_of_accounts
set name_ar = U&'\0627\0644\0628\0646\0643 \0627\0644\0631\0626\064A\0633\064A' UESCAPE '\'
where code = '1102';

update chart_of_accounts
set name_ar = U&'\0630\0645\0645 \0627\0644\0639\0645\0644\0627\0621' UESCAPE '\'
where code = '1201';

update chart_of_accounts
set name_ar = U&'\0627\0644\0645\062E\0632\0648\0646' UESCAPE '\'
where code = '1301';

update chart_of_accounts
set name_ar = U&'\0630\0645\0645 \0627\0644\0645\0648\0631\062F\064A\0646' UESCAPE '\'
where code = '2101';

update chart_of_accounts
set name_ar = U&'\0625\064A\0631\0627\062F\0627\062A \0627\0644\0645\0628\064A\0639\0627\062A' UESCAPE '\'
where code = '4101';

update chart_of_accounts
set name_ar = U&'\062A\0643\0644\0641\0629 \0627\0644\0628\0636\0627\0639\0629' UESCAPE '\'
where code = '5101';

update chart_of_accounts
set name_ar = U&'\0645\0635\0631\0648\0641\0627\062A \0639\0627\0645\0629' UESCAPE '\'
where code = '6101';

-- ---------------------------------------------------------------------------
-- Step 6: Re-enable protection trigger.
-- ---------------------------------------------------------------------------
alter table chart_of_accounts enable trigger trg_enforce_chart_account_protection;
