-- Phase 5 M3: document templates verification (case matrix §3.4).
-- Run after `supabase db reset` via scripts/test/run_sql_suites.ps1 Phase B.
-- Manual: Get-Content -Raw -Encoding utf8 supabase/tests/phase_5_document_templates.sql | docker exec -i supabase_db_hs360 psql -U postgres -d postgres

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- ACL-1..8: document_templates (anon + authenticated × INSERT/UPDATE/DELETE/TRUNCATE)
-- ---------------------------------------------------------------------------
begin;
set local role anon;
do $$
begin
  insert into public.document_templates (
    tenant_id, template_key, document_type, name_ar, name_en,
    language_mode, paper_kind, schema_version, body_json, is_default, is_active
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'acl_anon_ins', 'sales_invoice',
    'x', 'x', 'bilingual', 'a4', 1, public.m3_default_template_body('sales_invoice_a4'),
    false, true
  );
  raise exception 'ACL-1 failed: anon insert succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role anon;
do $$
begin
  update public.document_templates set name_en = 'hack' where false;
  raise exception 'ACL-2 failed: anon update succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role anon;
do $$
begin
  delete from public.document_templates where false;
  raise exception 'ACL-3 failed: anon delete succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role anon;
do $$
begin
  execute 'truncate public.document_templates';
  raise exception 'ACL-4 failed: anon truncate succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  insert into public.document_templates (
    tenant_id, template_key, document_type, name_ar, name_en,
    language_mode, paper_kind, schema_version, body_json, is_default, is_active
  )
  values (
    '00000000-0000-0000-0000-000000000101', 'acl_auth_ins', 'sales_invoice',
    'x', 'x', 'bilingual', 'a4', 1, public.m3_default_template_body('sales_invoice_a4'),
    false, true
  );
  raise exception 'ACL-5 failed: authenticated insert succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  update public.document_templates
  set name_en = 'hack'
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  raise exception 'ACL-6 failed: authenticated update succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  delete from public.document_templates
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  raise exception 'ACL-7 failed: authenticated delete succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  execute 'truncate public.document_templates';
  raise exception 'ACL-8 failed: authenticated truncate succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- ACL-9..16: tenant_document_settings (anon + authenticated × 4 ops)
-- ---------------------------------------------------------------------------
begin;
set local role anon;
do $$
begin
  insert into public.tenant_document_settings (tenant_id)
  values ('00000000-0000-0000-0000-000000000101');
  raise exception 'ACL-9 failed: anon insert succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role anon;
do $$
begin
  update public.tenant_document_settings set primary_color = '#000000' where false;
  raise exception 'ACL-10 failed: anon update succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role anon;
do $$
begin
  delete from public.tenant_document_settings where false;
  raise exception 'ACL-11 failed: anon delete succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role anon;
do $$
begin
  execute 'truncate public.tenant_document_settings';
  raise exception 'ACL-12 failed: anon truncate succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  insert into public.tenant_document_settings (tenant_id)
  values ('00000000-0000-0000-0000-000000000102');
  raise exception 'ACL-13 failed: authenticated insert succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  update public.tenant_document_settings
  set primary_color = '#000000'
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  raise exception 'ACL-14 failed: authenticated update succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  delete from public.tenant_document_settings
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  raise exception 'ACL-15 failed: authenticated delete succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  execute 'truncate public.tenant_document_settings';
  raise exception 'ACL-16 failed: authenticated truncate succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- ACL-17: audit trigger function is not directly executable by clients
-- ---------------------------------------------------------------------------
do $$
declare
  v_acl aclitem[];
begin
  select proacl into v_acl
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'audit_log_row'
    and pg_get_function_identity_arguments(p.oid) = '';

  if has_function_privilege('anon', 'public.audit_log_row()', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.audit_log_row()', 'EXECUTE') then
    raise exception 'ACL-17 failed: audit_log_row execute leaked: %', v_acl;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- PERM-1: print_label only -> label RPC denied
-- PERM-2: product_units.view only -> label RPC success
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_tu uuid := '00000000-0000-0000-0000-000000000302';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_unit uuid := gen_random_uuid();
begin
  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status, current_warehouse_id, acquired_at
  )
  values (v_unit, v_tenant_a, v_product, 'M3-LBL-PERM-1', 'available_new', v_wh, current_date);

  delete from public.user_permissions
  where tenant_user_id = v_tu
    and permission_id in ('product_units.view', 'product_units.print_label', 'products.view');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_tu, 'product_units.print_label', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;

  perform set_config('test.m3.label_unit', v_unit::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_unit uuid := current_setting('test.m3.label_unit')::uuid;
begin
  begin
    perform public.get_product_unit_label_payload(v_unit);
    raise exception 'PERM-1 failed: print_label alone granted payload access';
  exception
    when others then
      if sqlerrm not like '%permission_denied%' then
        raise;
      end if;
  end;
end $$;
rollback;

begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_tu uuid := '00000000-0000-0000-0000-000000000302';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_unit uuid := gen_random_uuid();
begin
  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status, current_warehouse_id, acquired_at
  )
  values (v_unit, v_tenant_a, v_product, 'M3-LBL-PERM-2', 'available_new', v_wh, current_date);

  delete from public.user_permissions
  where tenant_user_id = v_tu
    and permission_id in ('product_units.view', 'product_units.print_label', 'products.view');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_tu, 'product_units.view', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;

  perform set_config('test.m3.label_unit', v_unit::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_unit uuid := current_setting('test.m3.label_unit')::uuid;
  v_payload jsonb;
begin
  select public.get_product_unit_label_payload(v_unit) into v_payload;
  if v_payload -> 'unit' ->> 'serial' is distinct from 'M3-LBL-PERM-2' then
    raise exception 'PERM-2 failed: payload missing serial';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- PERM-3: invoices.view only -> sales template RPC success
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_tu uuid := '00000000-0000-0000-0000-000000000302';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  delete from public.user_permissions
  where tenant_user_id = v_tu
    and permission_id in ('invoices.view_sales', 'invoices.view', 'settings.templates.view');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_tu, 'invoices.view', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_result jsonb;
begin
  select public.get_effective_document_template('sales_invoice', 'a4') into v_result;
  if v_result -> 'template' ->> 'template_key' is null then
    raise exception 'PERM-3 failed: legacy invoices.view could not load template';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- PREV-1: inactive tenant_user -> tenant_not_found
-- PREV-2: auth user without membership -> tenant_not_found
-- ---------------------------------------------------------------------------
begin;
do $$
begin
  update public.tenant_users
  set is_active = false
  where id = '00000000-0000-0000-0000-000000000302';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
begin
  begin
    perform public.get_effective_document_template('sales_invoice', 'a4');
    raise exception 'PREV-1 failed: inactive tenant_user accepted';
  exception
    when others then
      if sqlerrm not like '%tenant_not_found%' then
        raise;
      end if;
  end;
end $$;
rollback;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000009999';
do $$
begin
  begin
    perform public.get_effective_document_template('sales_invoice', 'a4');
    raise exception 'PREV-2 failed: non-member user accepted';
  exception
    when others then
      if sqlerrm not like '%tenant_not_found%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- TPL-1: delete default template row -> no_default_document_template
-- TPL-2: is_default=false on sole default -> no_default_document_template
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  delete from public.document_templates
  where tenant_id = v_tenant_a
    and document_type = 'sales_invoice'
    and paper_kind = 'a4'
    and is_default = true;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform public.get_effective_document_template('sales_invoice', 'a4');
    raise exception 'TPL-1 failed: missing default did not raise';
  exception
    when others then
      if sqlerrm not like '%no_default_document_template%' then
        raise;
      end if;
  end;
end $$;
rollback;

begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  update public.document_templates
  set is_default = false
  where tenant_id = v_tenant_a
    and document_type = 'sales_invoice'
    and paper_kind = 'a4';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform public.get_effective_document_template('sales_invoice', 'a4');
    raise exception 'TPL-2 failed: sole default cleared did not raise';
  exception
    when others then
      if sqlerrm not like '%no_default_document_template%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- STMT-1: date span >364 days -> statement_date_range_invalid
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer uuid;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_customer := create_customer(
    '{"name_ar":"عميل STMT-1","phone_primary":"+96550003001","create_account":true}'::jsonb
  );

  begin
    perform public.get_customer_statement_document_payload(
      v_customer,
      current_date - 400,
      current_date
    );
    raise exception 'STMT-1 failed: oversized date range accepted';
  exception
    when others then
      if sqlerrm not like '%statement_date_range_invalid%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- STMT-2 / STMT-3: dynamic v_limit row cap
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_account_id uuid;
  v_limit int;
  v_i int;
  v_entry_id uuid;
  v_stmt_date date := current_date;
begin
  v_limit := public.m3_statement_row_limit();
  perform set_config('test.m3.stmt_limit', v_limit::text, true);

  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_customer := create_customer(
    '{"name_ar":"عميل STMT-CAP","phone_primary":"+96550003002","create_account":true}'::jsonb
  );
  select account_id into v_account_id from public.customers where id = v_customer;
  if v_account_id is null then
    raise exception 'STMT-2/3: fixture missing customer account_id';
  end if;

  for v_i in 1..v_limit loop
    insert into public.journal_entries (tenant_id, entry_number, date, source, is_posted)
    values (
      v_tenant_a,
      'STMT-CAP-' || lpad(v_i::text, 6, '0'),
      v_stmt_date,
      'manual',
      false
    )
    returning id into v_entry_id;

    insert into public.journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
    )
    values
      (v_tenant_a, v_entry_id, v_account_id, 1, 0, 1, 'AR-' || v_i),
      (v_tenant_a, v_entry_id, v_cash, 0, 1, 2, 'Cash-' || v_i);

    update public.journal_entries
    set is_posted = true, posted_at = now(), posted_by = v_owner
    where id = v_entry_id;
  end loop;

  perform set_config('test.m3.stmt_customer', v_customer::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer uuid := current_setting('test.m3.stmt_customer')::uuid;
  v_limit int := current_setting('test.m3.stmt_limit')::int;
  v_stmt_date date := current_date;
  v_payload jsonb;
begin
  select public.get_customer_statement_document_payload(
    v_customer, v_stmt_date, v_stmt_date
  ) into v_payload;

  if (v_payload ->> 'row_count')::int <> v_limit then
    raise exception 'STMT-3 failed: expected % rows, got %',
      v_limit, v_payload ->> 'row_count';
  end if;
end $$;
reset role;
do $$
declare
  v_customer uuid := current_setting('test.m3.stmt_customer')::uuid;
  v_account_id uuid;
  v_stmt_date date := current_date;
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_entry_id uuid;
begin
  select account_id into v_account_id from public.customers where id = v_customer;
  if v_account_id is null then
    raise exception 'STMT-2: fixture missing customer account_id';
  end if;

  insert into public.journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'STMT-CAP-OVER', v_stmt_date, 'manual', false)
  returning id into v_entry_id;

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values
    (v_tenant_a, v_entry_id, v_account_id, 1, 0, 1, 'AR-over'),
    (v_tenant_a, v_entry_id, v_cash, 0, 1, 2, 'Cash-over');

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = v_owner
  where id = v_entry_id;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer uuid := current_setting('test.m3.stmt_customer')::uuid;
  v_stmt_date date := current_date;
begin
  begin
    perform public.get_customer_statement_document_payload(
      v_customer, v_stmt_date, v_stmt_date
    );
    raise exception 'STMT-2 failed: statement_range_too_large not raised';
  exception
    when others then
      if sqlerrm not like '%statement_range_too_large%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- STMT-4: customer without account_id -> zero-safe payload + notes null
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer uuid;
  v_payload jsonb;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_customer := create_customer(
    '{"name_ar":"عميل بلا حساب M3","phone_primary":"+96550003003"}'::jsonb
  );

  select public.get_customer_statement_document_payload(
    v_customer,
    current_date - 30,
    current_date
  ) into v_payload;

  if (v_payload ->> 'row_count')::int <> 0 then
    raise exception 'STMT-4 failed: expected row_count 0, got %', v_payload ->> 'row_count';
  end if;
  if jsonb_array_length(v_payload -> 'lines') <> 0 then
    raise exception 'STMT-4 failed: expected empty lines array';
  end if;
  if v_payload -> 'summary' ->> 'opening_balance' <> '0'
    or v_payload -> 'summary' ->> 'total_debit' <> '0'
    or v_payload -> 'summary' ->> 'total_credit' <> '0'
    or v_payload -> 'summary' ->> 'closing_balance' <> '0' then
    raise exception 'STMT-4 failed: summary not zero-safe';
  end if;
  if not (v_payload ? 'notes') then
    raise exception 'STMT-4 failed: notes key missing at payload root';
  end if;
  if (v_payload -> 'notes') is distinct from 'null'::jsonb then
    raise exception 'STMT-4 failed: notes must be null at payload root, got %', v_payload -> 'notes';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- STMT-5: summary opening + debit - credit = closing
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_account_id uuid;
  v_entry_id uuid;
  v_payload jsonb;
  v_opening numeric(15, 3);
  v_debit numeric(15, 3);
  v_credit numeric(15, 3);
  v_closing numeric(15, 3);
  v_from date := current_date - 30;
  v_to date := current_date;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_customer := create_customer(
    '{"name_ar":"عميل STMT-5","phone_primary":"+96550003004","create_account":true}'::jsonb
  );
  select account_id into v_account_id from public.customers where id = v_customer;
  if v_account_id is null then
    raise exception 'STMT-5: fixture missing customer account_id';
  end if;

  insert into public.journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'STMT-MATH-1', v_to, 'manual', false)
  returning id into v_entry_id;

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values
    (v_tenant_a, v_entry_id, v_account_id, 25, 0, 1, 'Debit line'),
    (v_tenant_a, v_entry_id, v_cash, 0, 25, 2, 'Credit line');

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = v_owner
  where id = v_entry_id;

  perform set_config('test.m3.stmt5_customer', v_customer::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer uuid := current_setting('test.m3.stmt5_customer')::uuid;
  v_payload jsonb;
  v_opening numeric(15, 3);
  v_debit numeric(15, 3);
  v_credit numeric(15, 3);
  v_closing numeric(15, 3);
  v_from date := current_date - 30;
  v_to date := current_date;
begin
  select public.get_customer_statement_document_payload(v_customer, v_from, v_to)
  into v_payload;

  v_opening := (v_payload -> 'summary' ->> 'opening_balance')::numeric;
  v_debit := (v_payload -> 'summary' ->> 'total_debit')::numeric;
  v_credit := (v_payload -> 'summary' ->> 'total_credit')::numeric;
  v_closing := (v_payload -> 'summary' ->> 'closing_balance')::numeric;

  if v_closing <> v_opening + v_debit - v_credit then
    raise exception 'STMT-5 failed: summary math mismatch % + % - % <> %',
      v_opening, v_debit, v_credit, v_closing;
  end if;

  if jsonb_typeof(v_payload -> 'summary' -> 'opening_balance') <> 'string'
    or jsonb_typeof(v_payload -> 'summary' -> 'total_debit') <> 'string'
    or jsonb_typeof(v_payload -> 'summary' -> 'total_credit') <> 'string'
    or jsonb_typeof(v_payload -> 'summary' -> 'closing_balance') <> 'string'
    or jsonb_typeof(v_payload -> 'lines' -> 0 -> 'debit') <> 'string'
    or jsonb_typeof(v_payload -> 'lines' -> 0 -> 'credit') <> 'string'
    or jsonb_typeof(v_payload -> 'lines' -> 0 -> 'running_balance') <> 'string' then
    raise exception 'STMT-5 failed: money values must be JSON strings';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- STMT-6: tie-break same date/entry_number by jl.id order
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_account_id uuid;
  v_entry_id uuid;
  v_line_first uuid;
  v_line_second uuid;
  v_stmt_date date := current_date;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_customer := create_customer(
    '{"name_ar":"عميل STMT-6","phone_primary":"+96550003005","create_account":true}'::jsonb
  );
  select account_id into v_account_id from public.customers where id = v_customer;
  if v_account_id is null then
    raise exception 'STMT-6: fixture missing customer account_id';
  end if;

  insert into public.journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'STMT-TIE-1', v_stmt_date, 'manual', false)
  returning id into v_entry_id;

  insert into public.journal_lines (
    id, tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (
    '00000000-0000-0000-0000-00000000a001',
    v_tenant_a, v_entry_id, v_account_id, 5, 0, 1, 'first-ar-line'
  )
  returning id into v_line_first;

  insert into public.journal_lines (
    id, tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (
    '00000000-0000-0000-0000-00000000a002',
    v_tenant_a, v_entry_id, v_account_id, 7, 0, 2, 'second-ar-line'
  )
  returning id into v_line_second;

  insert into public.journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order, description
  )
  values (v_tenant_a, v_entry_id, v_cash, 0, 12, 3, 'cash-balance');

  if v_line_first >= v_line_second then
    raise exception 'STMT-6: fixture missing ordered jl.id values';
  end if;

  update public.journal_entries
  set is_posted = true, posted_at = now(), posted_by = v_owner
  where id = v_entry_id;

  perform set_config('test.m3.stmt6_customer', v_customer::text, true);
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_customer uuid := current_setting('test.m3.stmt6_customer')::uuid;
  v_payload jsonb;
  v_lines jsonb;
  v_stmt_date date := current_date;
begin
  select public.get_customer_statement_document_payload(
    v_customer, v_stmt_date, v_stmt_date
  ) into v_payload;

  v_lines := v_payload -> 'lines';
  if jsonb_array_length(v_lines) <> 2 then
    raise exception 'STMT-6 failed: expected 2 AR lines, got %', jsonb_array_length(v_lines);
  end if;
  if v_lines -> 0 ->> 'description' <> 'first-ar-line'
    or v_lines -> 1 ->> 'description' <> 'second-ar-line' then
    raise exception 'STMT-6 failed: unstable jl.id order: %', v_lines;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- SEED-1: all six default bodies pass validator (4-arg)
-- SEED-2: thermal geometry 4+72+4=80
-- SEED-3: label geometry qr 14mm + usable 18x10 mm
-- ---------------------------------------------------------------------------
do $$
declare
  v_spec record;
  v_body jsonb;
  v_thermal jsonb;
  v_label jsonb;
  v_margin jsonb;
  v_left numeric;
  v_right numeric;
  v_top numeric;
  v_bottom numeric;
  v_usable_w numeric;
  v_usable_h numeric;
begin
  for v_spec in
    select *
    from (
      values
        ('sales_invoice_a4', 'sales_invoice', 'a4'),
        ('purchase_invoice_a4', 'purchase_invoice', 'a4'),
        ('receipt_voucher_a4', 'receipt_voucher', 'a4'),
        ('receipt_voucher_80mm', 'receipt_voucher', 'thermal_80mm'),
        ('customer_statement_a4', 'customer_statement', 'a4'),
        ('asset_tag_label', 'asset_tag_label', 'label_sheet')
    ) as t(template_key, document_type, paper_kind)
  loop
    v_body := public.m3_default_template_body(v_spec.template_key);
    perform public.validate_document_template_body(
      v_spec.document_type,
      v_body,
      v_spec.paper_kind,
      1
    );
  end loop;

  v_thermal := public.m3_thermal_settings();
  v_margin := v_thermal -> 'page_margin_mm';
  v_left := (v_margin ->> 'left')::numeric;
  v_right := (v_margin ->> 'right')::numeric;
  if v_left + (v_thermal ->> 'thermal_content_width_mm')::numeric + v_right <> 80 then
    raise exception 'SEED-2 failed: thermal geometry % + % + % <> 80',
      v_left, v_thermal ->> 'thermal_content_width_mm', v_right;
  end if;

  v_label := public.m3_label_settings();
  v_margin := v_label -> 'page_margin_mm';
  v_left := (v_margin ->> 'left')::numeric;
  v_right := (v_margin ->> 'right')::numeric;
  v_top := (v_margin ->> 'top')::numeric;
  v_bottom := (v_margin ->> 'bottom')::numeric;
  if (v_label ->> 'qr_size_mm')::numeric <> 14 then
    raise exception 'SEED-3 failed: expected qr_size_mm 14';
  end if;
  v_usable_w := (v_label ->> 'label_width_mm')::numeric
    - v_left - v_right - (v_label ->> 'qr_size_mm')::numeric - 1;
  v_usable_h := (v_label ->> 'label_height_mm')::numeric - v_top - v_bottom;
  if v_usable_w < 18 or v_usable_h < 10 then
    raise exception 'SEED-3 failed: usable area % x % below minimum', v_usable_w, v_usable_h;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- LABEL-VAL-1 / LABEL-VAL-2: SQL validator rejects insufficient usable area
-- ---------------------------------------------------------------------------
do $$
declare
  v_body jsonb;
  v_settings jsonb;
begin
  v_body := public.m3_default_template_body('asset_tag_label');
  v_settings := v_body -> 'settings';
  v_settings := jsonb_set(v_settings, '{label_width_mm}', '30'::jsonb);
  v_body := jsonb_set(v_body, '{settings}', v_settings);

  begin
    perform public.validate_document_template_body(
      'asset_tag_label', v_body, 'label_sheet', 1
    );
    raise exception 'LABEL-VAL-1 failed: usable width accepted';
  exception
    when others then
      if sqlerrm not like '%invalid_document_template%' then
        raise;
      end if;
  end;

  v_body := public.m3_default_template_body('asset_tag_label');
  v_settings := v_body -> 'settings';
  v_settings := jsonb_set(v_settings, '{label_height_mm}', '12'::jsonb);
  v_body := jsonb_set(v_body, '{settings}', v_settings);

  begin
    perform public.validate_document_template_body(
      'asset_tag_label', v_body, 'label_sheet', 1
    );
    raise exception 'LABEL-VAL-2 failed: usable height accepted';
  exception
    when others then
      if sqlerrm not like '%invalid_document_template%' then
        raise;
      end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- SCHEMA-1: body schema_version != table column
-- BLK-ALLOW-1 / BLK-ALLOW-2 / PARTY-1 / NOTES-1
-- ---------------------------------------------------------------------------
do $$
declare
  v_body jsonb;
begin
  v_body := public.m3_default_template_body('sales_invoice_a4');
  begin
    insert into public.document_templates (
      tenant_id, template_key, document_type, name_ar, name_en,
      language_mode, paper_kind, schema_version, body_json, is_default, is_active
    )
    values (
      '00000000-0000-0000-0000-000000000101', 'schema_mismatch', 'sales_invoice',
      'x', 'x', 'bilingual', 'a4', 2, v_body, false, true
    );
    raise exception 'SCHEMA-1 failed: schema_version mismatch accepted';
  exception
    when others then
      if sqlerrm not like '%invalid_document_template%' then
        raise;
      end if;
  end;
end $$;

do $$
declare
  v_body jsonb;
  v_blocks jsonb;
begin
  v_body := public.m3_default_template_body('sales_invoice_a4');
  v_blocks := (v_body -> 'blocks') || jsonb_build_array(
    jsonb_build_object(
      'type', 'payment_details', 'id', 'pay', 'fields',
      jsonb_build_array('payment.amount')
    )
  );
  v_body := jsonb_set(v_body, '{blocks}', v_blocks);
  begin
    perform public.validate_document_template_body(
      'sales_invoice', v_body, 'a4', 1
    );
    raise exception 'BLK-ALLOW-1 failed: payment_details on sales_invoice accepted';
  exception
    when others then
      if sqlerrm not like '%invalid_document_template%' then
        raise;
      end if;
  end;

  v_body := public.m3_default_template_body('receipt_voucher_80mm');
  v_blocks := (v_body -> 'blocks') || jsonb_build_array(
    jsonb_build_object(
      'type', 'line_table', 'id', 'lines',
      'columns', jsonb_build_array(
        jsonb_build_object(
          'field', 'line.description', 'label_key', 'col.description',
          'label_ar', 'x', 'label_en', 'x', 'width_pct', 100, 'align', 'start'
        )
      ),
      'fields', jsonb_build_array('line.description')
    )
  );
  v_body := jsonb_set(v_body, '{blocks}', v_blocks);
  begin
    perform public.validate_document_template_body(
      'receipt_voucher', v_body, 'thermal_80mm', 1
    );
    raise exception 'BLK-ALLOW-2 failed: line_table on thermal accepted';
  exception
    when others then
      if sqlerrm not like '%invalid_document_template%' then
        raise;
      end if;
  end;

  v_body := public.m3_default_template_body('purchase_invoice_a4');
  v_blocks := v_body -> 'blocks';
  v_blocks := (
    select jsonb_agg(
      case
        when elem ->> 'type' = 'party_details' then
          jsonb_set(elem, '{party_role}', '"customer"'::jsonb)
        else elem
      end
    )
    from jsonb_array_elements(v_blocks) elem
  );
  v_body := jsonb_set(v_body, '{blocks}', v_blocks);
  begin
    perform public.validate_document_template_body(
      'purchase_invoice', v_body, 'a4', 1
    );
    raise exception 'PARTY-1 failed: purchase party_role=customer accepted';
  exception
    when others then
      if sqlerrm not like '%invalid_document_template%' then
        raise;
      end if;
  end;

  v_body := public.m3_default_template_body('sales_invoice_a4');
  v_blocks := (v_body -> 'blocks') || jsonb_build_array(
    jsonb_build_object(
      'type', 'notes', 'id', 'nts', 'fields', jsonb_build_array('document.number')
    )
  );
  v_body := jsonb_set(v_body, '{blocks}', v_blocks);
  begin
    perform public.validate_document_template_body(
      'sales_invoice', v_body, 'a4', 1
    );
    raise exception 'NOTES-1 failed: notes field <> document.notes accepted';
  exception
    when others then
      if sqlerrm not like '%invalid_document_template%' then
        raise;
      end if;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- TENANT-1: optional_columns string value -> validation_failed
-- TENANT-2: header control char -> validation_failed
-- TENANT-3: null non-nullable setting -> validation_failed
-- TENANT-4: non-string logo_url -> validation_failed
-- SET-1: http logo URL -> validation_failed
-- SET-2: audit entity_id = tenant_id on settings patch
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_tu uuid := '00000000-0000-0000-0000-000000000302';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_tu, 'settings.templates.edit', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
begin
  begin
    perform public.upsert_tenant_document_settings(
      jsonb_build_object(
        'optional_columns_json', jsonb_build_object(
          'sales_invoice', jsonb_build_object('line.qty', 'yes')
        )
      )
    );
    raise exception 'TENANT-1 failed: string optional column accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  begin
    perform public.upsert_tenant_document_settings(
      jsonb_build_object(
        'header_json', jsonb_build_object('text_ar', 'bad' || chr(1))
      )
    );
    raise exception 'TENANT-2 failed: header control char accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  begin
    perform public.upsert_tenant_document_settings(
      jsonb_build_object('logo_url', 'http://insecure.example/logo.png')
    );
    raise exception 'SET-1 failed: http logo accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  begin
    perform public.upsert_tenant_document_settings(
      jsonb_build_object('default_language', null)
    );
    raise exception 'TENANT-3 failed: null default_language accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;

  begin
    perform public.upsert_tenant_document_settings(
      jsonb_build_object('logo_url', jsonb_build_object('url', 'https://example.com/logo.png'))
    );
    raise exception 'TENANT-4 failed: object logo_url accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_entity uuid;
begin
  perform public.upsert_tenant_document_settings(
    jsonb_build_object('primary_color', '#AABBCC')
  );

  select entity_id into v_entity
  from public.audit_log
  where tenant_id = v_tenant_a
    and entity_type = 'tenant_document_settings'
  order by at desc
  limit 1;

  if v_entity is distinct from v_tenant_a then
    raise exception 'SET-2 failed: audit entity_id % tenant %', v_entity, v_tenant_a;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- AUDIT-REG: product_units update audited (not tenant_settings)
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_unit_id uuid := gen_random_uuid();
  v_entity uuid;
begin
  insert into public.product_units (
    id, tenant_id, product_id, serial_number, status, current_warehouse_id, acquired_at
  )
  values (v_unit_id, v_tenant_a, v_product, 'AUDIT-REG-1', 'available_new', v_wh, current_date);

  update public.product_units
  set status = 'rented'
  where id = v_unit_id;

  select entity_id into v_entity
  from public.audit_log
  where tenant_id = v_tenant_a
    and entity_type = 'product_units'
    and entity_id = v_unit_id
    and action = 'update'
  order by at desc
  limit 1;

  if v_entity is distinct from v_unit_id then
    raise exception 'AUDIT-REG failed: entity_id % unit %', v_entity, v_unit_id;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- PV-1..4: payment_voucher rejected / no seed row
-- ---------------------------------------------------------------------------
do $$
begin
  begin
    perform public.validate_document_template_body(
      'payment_voucher',
      public.m3_default_template_body('receipt_voucher_a4'),
      'a4',
      1
    );
    raise exception 'PV-1 failed: payment_voucher validator accepted';
  exception
    when others then
      if sqlerrm not like '%unsupported_document_type%' then
        raise;
      end if;
  end;
end $$;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform public.get_effective_document_template('payment_voucher', 'a4');
    raise exception 'PV-2 failed: payment_voucher template RPC accepted';
  exception
    when others then
      if sqlerrm not like '%unsupported_document_type%' then
        raise;
      end if;
  end;
end $$;
rollback;

do $$
begin
  begin
    perform public.assert_document_preview_permission('payment_voucher');
    raise exception 'PV-3 failed: payment_voucher permission accepted';
  exception
    when others then
      if sqlerrm not like '%unsupported_document_type%' then
        raise;
      end if;
  end;
end $$;

do $$
declare
  v_count bigint;
begin
  select count(*) into v_count
  from public.document_templates
  where document_type = 'payment_voucher';

  if v_count <> 0 then
    raise exception 'PV-4 failed: unexpected payment_voucher seed rows %', v_count;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- XTN-1: cross-tenant SELECT tenant B -> 0 rows
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_count bigint;
begin
  select count(*) into v_count
  from public.document_templates
  where tenant_id = '00000000-0000-0000-0000-000000000102';

  if v_count <> 0 then
    raise exception 'XTN-1 failed: cross-tenant rows visible %', v_count;
  end if;
end $$;
rollback;

select 'phase_5_document_templates.sql: all cases passed' as result;
