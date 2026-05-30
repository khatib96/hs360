-- Phase 4 M2: customers, suppliers & chart-of-accounts RPC verification.
-- Run after `supabase db reset` (or after applying migration 045):
-- docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_4_customers_suppliers_coa.sql

\set ON_ERROR_STOP on

-- 1-4. Manager create_customer: id, CUST-NNNN code, A/R subaccount under 1201, account_id link.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_id uuid;
  v_code text;
  v_account_id uuid;
  v_ar_parent uuid;
  v_sub record;
begin
  v_id := create_customer('{"name_ar":"عميل اختبار","name_en":"Test Customer","phone_primary":"+96550000111"}'::jsonb);
  if v_id is null then
    raise exception 'case1 failed: create_customer returned null';
  end if;

  select code, account_id into v_code, v_account_id from customers where id = v_id;

  if v_code !~ '^CUST-[0-9]{4}$' then
    raise exception 'case2 failed: customer code % not CUST-NNNN', v_code;
  end if;

  select id into v_ar_parent from chart_of_accounts where tenant_id = v_tenant_a and code = '1201';

  select * into v_sub from chart_of_accounts where id = v_account_id;
  if v_sub.parent_id <> v_ar_parent then
    raise exception 'case3 failed: subaccount parent % <> 1201 %', v_sub.parent_id, v_ar_parent;
  end if;
  if v_sub.related_entity_table <> 'customers' or v_sub.related_entity_id <> v_id then
    raise exception 'case3 failed: subaccount link mismatch';
  end if;
  if v_sub.is_system or not v_sub.is_subaccount or v_sub.type <> 'asset' then
    raise exception 'case3 failed: subaccount flags/type wrong';
  end if;
  if v_sub.code !~ '^1201\.[0-9]{4}$' then
    raise exception 'case3 failed: subaccount code % not 1201.NNNN', v_sub.code;
  end if;

  if v_account_id is null then
    raise exception 'case4 failed: customer account_id is null';
  end if;
end $$;
rollback;

-- 5-8. Manager create_supplier: id, SUP-NNNN code, A/P subaccount under 2101, account_id link.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_id uuid;
  v_code text;
  v_account_id uuid;
  v_ap_parent uuid;
  v_sub record;
begin
  v_id := create_supplier('{"name_ar":"مورد اختبار","phone":"+96550000222"}'::jsonb);
  if v_id is null then
    raise exception 'case5 failed: create_supplier returned null';
  end if;

  select code, account_id into v_code, v_account_id from suppliers where id = v_id;

  if v_code !~ '^SUP-[0-9]{4}$' then
    raise exception 'case6 failed: supplier code % not SUP-NNNN', v_code;
  end if;

  select id into v_ap_parent from chart_of_accounts where tenant_id = v_tenant_a and code = '2101';

  select * into v_sub from chart_of_accounts where id = v_account_id;
  if v_sub.parent_id <> v_ap_parent then
    raise exception 'case7 failed: subaccount parent % <> 2101 %', v_sub.parent_id, v_ap_parent;
  end if;
  if v_sub.related_entity_table <> 'suppliers' or v_sub.related_entity_id <> v_id then
    raise exception 'case7 failed: subaccount link mismatch';
  end if;
  if v_sub.is_system or v_sub.type <> 'liability' then
    raise exception 'case7 failed: subaccount flags/type wrong';
  end if;

  if v_account_id is null then
    raise exception 'case8 failed: supplier account_id is null';
  end if;
end $$;
rollback;

-- 9. Direct insert into customers blocked (RPC-only writes).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_ar uuid;
begin
  select id into v_ar from chart_of_accounts where tenant_id = v_tenant_a and code = '1201';
  begin
    insert into customers (tenant_id, code, name_ar, phone_primary, account_id)
    values (v_tenant_a, 'CUST-DIRECT', 'مباشر', '+96550000000', v_ar);
    raise exception 'case9 failed: direct customer insert succeeded';
  exception
    when insufficient_privilege or with_check_option_violation then
      null;
  end;
end $$;
rollback;

-- 10. Direct insert into suppliers blocked.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_ap uuid;
begin
  select id into v_ap from chart_of_accounts where tenant_id = v_tenant_a and code = '2101';
  begin
    insert into suppliers (tenant_id, code, name_ar, account_id)
    values (v_tenant_a, 'SUP-DIRECT', 'مباشر', v_ap);
    raise exception 'case10 failed: direct supplier insert succeeded';
  exception
    when insufficient_privilege or with_check_option_violation then
      null;
  end;
end $$;
rollback;

-- 11. Zero-permission user cannot create or view customers.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_count int;
begin
  begin
    perform create_customer('{"name_ar":"x","phone_primary":"1"}'::jsonb);
    raise exception 'case11 failed: zero user created customer';
  exception
    when others then
      if sqlerrm <> 'permission_denied' then
        raise exception 'case11 failed: expected permission_denied, got %', sqlerrm;
      end if;
  end;

  select count(*) into v_count from customers;
  if v_count <> 0 then
    raise exception 'case11 failed: zero user saw % customers', v_count;
  end if;
end $$;
rollback;

-- 12. customers.create-only user can create via RPC.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'customers.create', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_id uuid;
begin
  v_id := create_customer('{"name_ar":"عميل المندوب","phone_primary":"+96550000333"}'::jsonb);
  if v_id is null then
    raise exception 'case12 failed: create-only user could not create';
  end if;
end $$;
rollback;

-- 13. User without customers.view_ledger cannot call statement RPC.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.phase4.cust', create_customer('{"name_ar":"عميل دفتر","phone_primary":"+96550000444"}'::jsonb)::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_id uuid := current_setting('test.phase4.cust')::uuid;
begin
  begin
    perform * from get_customer_statement(v_id);
    raise exception 'case13 failed: ledger-denied user read statement';
  exception
    when others then
      if sqlerrm <> 'permission_denied' then
        raise exception 'case13 failed: expected permission_denied, got %', sqlerrm;
      end if;
  end;
end $$;
rollback;

-- 14. User with customers.view_ledger (no journal.view) gets empty, error-free statement/summary.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'customers.view_ledger', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.phase4.cust', create_customer('{"name_ar":"عميل فارغ","phone_primary":"+96550000555"}'::jsonb)::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_id uuid := current_setting('test.phase4.cust')::uuid;
  v_rows int;
  v_balance numeric(15, 3);
begin
  select count(*) into v_rows from get_customer_statement(v_id);
  if v_rows <> 0 then
    raise exception 'case14 failed: expected empty statement, got % rows', v_rows;
  end if;

  select balance into v_balance from get_customer_balance_summary(v_id);
  if v_balance <> 0 then
    raise exception 'case14 failed: expected balance 0, got %', v_balance;
  end if;
end $$;
rollback;

-- 15. Negative credit_limit / payment_terms_days rejected (create and update).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_id uuid;
begin
  begin
    perform create_customer('{"name_ar":"x","phone_primary":"1","credit_limit":-5}'::jsonb);
    raise exception 'case15 failed: negative credit_limit accepted on create';
  exception
    when others then
      if sqlerrm <> 'validation_failed' then
        raise exception 'case15 failed: expected validation_failed, got %', sqlerrm;
      end if;
  end;

  begin
    perform create_customer('{"name_ar":"x","phone_primary":"1","payment_terms_days":-1}'::jsonb);
    raise exception 'case15 failed: negative payment_terms accepted on create';
  exception
    when others then
      if sqlerrm <> 'validation_failed' then
        raise exception 'case15 failed: expected validation_failed, got %', sqlerrm;
      end if;
  end;

  v_id := create_customer('{"name_ar":"عميل تحديث","phone_primary":"+96550000666"}'::jsonb);
  begin
    perform update_customer(v_id, '{"credit_limit":-3}'::jsonb);
    raise exception 'case15 failed: negative credit_limit accepted on update';
  exception
    when others then
      if sqlerrm <> 'validation_failed' then
        raise exception 'case15 failed: expected validation_failed on update, got %', sqlerrm;
      end if;
  end;
end $$;
rollback;

-- 16. RPC-only writes: direct UPDATE cannot modify rows (RLS filters to 0 rows).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cust uuid;
  v_sup uuid;
  v_cnt int;
begin
  v_cust := create_customer('{"name_ar":"عميل تحديث مباشر","phone_primary":"+96550000777"}'::jsonb);
  v_sup := create_supplier('{"name_ar":"مورد تحديث مباشر"}'::jsonb);

  update customers set name_ar = 'hack' where id = v_cust;
  get diagnostics v_cnt = row_count;
  if v_cnt <> 0 then
    raise exception 'case16 failed: direct customer update affected % rows', v_cnt;
  end if;

  update suppliers set name_ar = 'hack' where id = v_sup;
  get diagnostics v_cnt = row_count;
  if v_cnt <> 0 then
    raise exception 'case16 failed: direct supplier update affected % rows', v_cnt;
  end if;

  update chart_of_accounts set name_ar = 'hack' where tenant_id = v_tenant_a and code = '1101';
  get diagnostics v_cnt = row_count;
  if v_cnt <> 0 then
    raise exception 'case16 failed: direct chart_of_accounts update affected % rows', v_cnt;
  end if;
end $$;
rollback;

-- 17. Immutability guard triggers (owner-level, bypassing RLS).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.phase4.cust', create_customer('{"name_ar":"عميل ثابت","phone_primary":"+96550000888"}'::jsonb)::text, true);
  perform set_config('test.phase4.sup', create_supplier('{"name_ar":"مورد ثابت"}'::jsonb)::text, true);
end $$;
reset role;
do $$
declare
  v_cust uuid := current_setting('test.phase4.cust')::uuid;
  v_sup uuid := current_setting('test.phase4.sup')::uuid;
begin
  begin
    update customers set account_id = gen_random_uuid() where id = v_cust;
    raise exception 'case17 failed: customer account_id mutated';
  exception when others then
    if sqlerrm <> 'immutable_column' then raise exception 'case17 failed: expected immutable_column, got %', sqlerrm; end if;
  end;

  begin
    update customers set code = 'CUST-9999' where id = v_cust;
    raise exception 'case17 failed: customer code mutated';
  exception when others then
    if sqlerrm <> 'immutable_column' then raise exception 'case17 failed: expected immutable_column, got %', sqlerrm; end if;
  end;

  begin
    update suppliers set account_id = gen_random_uuid() where id = v_sup;
    raise exception 'case17 failed: supplier account_id mutated';
  exception when others then
    if sqlerrm <> 'immutable_column' then raise exception 'case17 failed: expected immutable_column, got %', sqlerrm; end if;
  end;

  begin
    update chart_of_accounts set related_entity_table = 'x' where related_entity_id = v_cust;
    raise exception 'case17 failed: chart related_entity_table mutated';
  exception when others then
    if sqlerrm <> 'immutable_column' then raise exception 'case17 failed: expected immutable_column, got %', sqlerrm; end if;
  end;
end $$;
rollback;

-- 18. Direct DELETE cannot remove rows (no delete policy -> RLS filters to 0 rows).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cust uuid;
  v_sup uuid;
  v_cust_acct uuid;
  v_manual uuid;
  v_cnt int;
begin
  v_cust := create_customer('{"name_ar":"عميل حذف","phone_primary":"+96550000999"}'::jsonb);
  v_sup := create_supplier('{"name_ar":"مورد حذف"}'::jsonb);
  select account_id into v_cust_acct from customers where id = v_cust;
  v_manual := create_chart_account('{"code":"9001","name_ar":"يدوي","name_en":"Manual","type":"expense"}'::jsonb);

  delete from customers where id = v_cust;
  get diagnostics v_cnt = row_count;
  if v_cnt <> 0 then raise exception 'case18a failed: customer delete removed % rows', v_cnt; end if;

  delete from suppliers where id = v_sup;
  get diagnostics v_cnt = row_count;
  if v_cnt <> 0 then raise exception 'case18b failed: supplier delete removed % rows', v_cnt; end if;

  delete from chart_of_accounts where tenant_id = v_tenant_a and code = '1101';
  get diagnostics v_cnt = row_count;
  if v_cnt <> 0 then raise exception 'case18c failed: system CoA delete removed % rows', v_cnt; end if;

  delete from chart_of_accounts where id = v_cust_acct;
  get diagnostics v_cnt = row_count;
  if v_cnt <> 0 then raise exception 'case18d failed: linked CoA delete removed % rows', v_cnt; end if;

  delete from chart_of_accounts where id = v_manual;
  get diagnostics v_cnt = row_count;
  if v_cnt <> 0 then raise exception 'case18e failed: manual CoA delete removed % rows', v_cnt; end if;
end $$;
rollback;

-- 19. System CoA protected (RPC + owner-level trigger).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_sys uuid;
begin
  select id into v_sys from chart_of_accounts where tenant_id = v_tenant_a and code = '1101';

  begin
    perform update_chart_account(v_sys, '{"name_ar":"تعديل"}'::jsonb);
    raise exception 'case19 failed: update_chart_account on system succeeded';
  exception when others then
    if sqlerrm <> 'account_protected' then raise exception 'case19 failed: expected account_protected, got %', sqlerrm; end if;
  end;

  begin
    perform deactivate_chart_account(v_sys);
    raise exception 'case19 failed: deactivate_chart_account on system succeeded';
  exception when others then
    if sqlerrm <> 'account_protected' then raise exception 'case19 failed: expected account_protected, got %', sqlerrm; end if;
  end;
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_sys uuid;
begin
  select id into v_sys from chart_of_accounts where tenant_id = v_tenant_a and code = '1101';
  begin
    update chart_of_accounts set name_ar = 'hack' where id = v_sys;
    raise exception 'case19 failed: owner update on system succeeded';
  exception when others then
    if sqlerrm <> 'account_protected' then raise exception 'case19 failed: owner expected account_protected, got %', sqlerrm; end if;
  end;
end $$;
rollback;

-- 20. Linked CoA protected (RPC + owner-level trigger).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cust uuid;
  v_acct uuid;
begin
  v_cust := create_customer('{"name_ar":"عميل مرتبط","phone_primary":"+96550001000"}'::jsonb);
  select account_id into v_acct from customers where id = v_cust;
  perform set_config('test.phase4.acct', v_acct::text, true);

  begin
    perform deactivate_chart_account(v_acct);
    raise exception 'case20 failed: deactivate linked CoA succeeded';
  exception when others then
    if sqlerrm <> 'account_protected' then raise exception 'case20 failed: expected account_protected, got %', sqlerrm; end if;
  end;
end $$;
reset role;
do $$
declare
  v_acct uuid := current_setting('test.phase4.acct')::uuid;
begin
  begin
    update chart_of_accounts set is_active = false where id = v_acct;
    raise exception 'case20 failed: owner deactivated linked CoA';
  exception when others then
    if sqlerrm <> 'account_protected' then raise exception 'case20 failed: owner expected account_protected, got %', sqlerrm; end if;
  end;

  begin
    update chart_of_accounts set code = '1201.9999' where id = v_acct;
    raise exception 'case20 failed: owner changed linked CoA code';
  exception when others then
    if sqlerrm <> 'immutable_column' then raise exception 'case20 failed: owner expected immutable_column, got %', sqlerrm; end if;
  end;
end $$;
rollback;

-- 21. CoA insert bypass attempts blocked by RLS.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  begin
    insert into chart_of_accounts (tenant_id, code, name_ar, name_en, type, is_system)
    values (v_tenant_a, '9100', 'مزيف', 'Fake System', 'asset', true);
    raise exception 'case21 failed: direct system CoA insert succeeded';
  exception when insufficient_privilege or with_check_option_violation then null; end;

  begin
    insert into chart_of_accounts (tenant_id, code, name_ar, name_en, type, related_entity_table, related_entity_id)
    values (v_tenant_a, '9101', 'مزيف', 'Fake Linked', 'asset', 'customers', gen_random_uuid());
    raise exception 'case21 failed: direct linked CoA insert succeeded';
  exception when insufficient_privilege or with_check_option_violation then null; end;
end $$;
rollback;

-- 22. CoA privilege escalation via update blocked (RLS for authenticated; trigger for owner).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_manual uuid;
  v_cnt int;
begin
  v_manual := create_chart_account('{"code":"9200","name_ar":"يدوي","name_en":"Manual","type":"expense"}'::jsonb);
  perform set_config('test.phase4.manual', v_manual::text, true);

  update chart_of_accounts set is_system = true where id = v_manual;
  get diagnostics v_cnt = row_count;
  if v_cnt <> 0 then
    raise exception 'case22 failed: authenticated escalated is_system (% rows)', v_cnt;
  end if;
end $$;
reset role;
do $$
declare
  v_manual uuid := current_setting('test.phase4.manual')::uuid;
begin
  begin
    update chart_of_accounts set is_system = true where id = v_manual;
    raise exception 'case22 failed: owner escalated is_system';
  exception when others then
    if sqlerrm <> 'account_protected' then raise exception 'case22 failed: owner expected account_protected, got %', sqlerrm; end if;
  end;
end $$;
rollback;

-- 23. Unsafe type change blocked when account has children; clean manual type change allowed.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_parent uuid;
  v_child uuid;
  v_clean uuid;
  v_type account_type;
begin
  v_parent := create_chart_account('{"code":"9300","name_ar":"أب","name_en":"Parent","type":"asset"}'::jsonb);
  v_child := create_chart_account(jsonb_build_object('code','9301','name_ar','ابن','name_en','Child','type','asset','parent_id',v_parent::text));
  v_clean := create_chart_account('{"code":"9302","name_ar":"نظيف","name_en":"Clean","type":"asset"}'::jsonb);
  perform set_config('test.phase4.parent', v_parent::text, true);

  -- clean manual account: type change allowed via RPC
  perform update_chart_account(v_clean, '{"type":"liability"}'::jsonb);
  select type into v_type from chart_of_accounts where id = v_clean;
  if v_type <> 'liability' then
    raise exception 'case23 failed: clean type change did not persist';
  end if;
end $$;
reset role;
do $$
declare
  v_parent uuid := current_setting('test.phase4.parent')::uuid;
begin
  begin
    update chart_of_accounts set type = 'liability' where id = v_parent;
    raise exception 'case23 failed: type change with children succeeded';
  exception when others then
    if sqlerrm <> 'account_type_change_unsafe' then raise exception 'case23 failed: expected account_type_change_unsafe, got %', sqlerrm; end if;
  end;
end $$;
rollback;

-- 24. CoA happy path: create (ignores is_system/related_entity_*), edit names/type, deactivate.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_id uuid;
  v_rec record;
begin
  v_id := create_chart_account(jsonb_build_object(
    'code','9400','name_ar','حساب','name_en','Account','type','expense',
    'is_system', true, 'related_entity_table','customers','related_entity_id', gen_random_uuid()::text
  ));

  select * into v_rec from chart_of_accounts where id = v_id;
  if v_rec.is_system or v_rec.is_subaccount or v_rec.related_entity_table is not null or v_rec.related_entity_id is not null then
    raise exception 'case24 failed: create did not force safe flags';
  end if;

  perform update_chart_account(v_id, '{"name_ar":"محدث","name_en":"Updated","type":"income"}'::jsonb);
  select * into v_rec from chart_of_accounts where id = v_id;
  if v_rec.name_en <> 'Updated' or v_rec.type <> 'income' or v_rec.is_active <> true then
    raise exception 'case24 failed: update did not persist or changed is_active';
  end if;

  perform deactivate_chart_account(v_id);
  select is_active into v_rec.is_active from chart_of_accounts where id = v_id;
  if v_rec.is_active <> false then
    raise exception 'case24 failed: deactivate did not set is_active false';
  end if;
end $$;
rollback;

-- 25. Tenant isolation: subaccounts are tenant-scoped; tenant B sees no tenant A customers.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cust uuid;
  v_acct_tenant uuid;
begin
  v_cust := create_customer('{"name_ar":"عميل عزل","phone_primary":"+96550001100"}'::jsonb);
  select coa.tenant_id into v_acct_tenant
  from customers c join chart_of_accounts coa on coa.id = c.account_id
  where c.id = v_cust;
  if v_acct_tenant <> v_tenant_a then
    raise exception 'case25 failed: subaccount not tenant-scoped';
  end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_count int;
begin
  select count(*) into v_count from customers;
  if v_count <> 0 then
    raise exception 'case25 failed: tenant B saw % customers', v_count;
  end if;
end $$;
rollback;

-- 26. Cross-tenant RPC rejection: tenant B manager cannot touch tenant A customer.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.phase4.cust', create_customer('{"name_ar":"عميل عبر مستأجر","phone_primary":"+96550001200"}'::jsonb)::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_id uuid := current_setting('test.phase4.cust')::uuid;
begin
  begin
    perform update_customer(v_id, '{"name_ar":"hack"}'::jsonb);
    raise exception 'case26 failed: cross-tenant update_customer succeeded';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise exception 'case26 failed: update expected validation_failed, got %', sqlerrm; end if;
  end;

  begin
    perform deactivate_customer(v_id);
    raise exception 'case26 failed: cross-tenant deactivate_customer succeeded';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise exception 'case26 failed: deactivate expected validation_failed, got %', sqlerrm; end if;
  end;

  begin
    perform * from get_customer_statement(v_id);
    raise exception 'case26 failed: cross-tenant statement succeeded';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise exception 'case26 failed: statement expected validation_failed, got %', sqlerrm; end if;
  end;
end $$;
rollback;

-- 27. Parent missing: tenant B has no 1201/2101.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
begin
  begin
    perform create_customer('{"name_ar":"عميل","phone_primary":"1"}'::jsonb);
    raise exception 'case27 failed: tenant B created customer without A/R parent';
  exception when others then
    if sqlerrm <> 'ar_parent_missing' then raise exception 'case27 failed: expected ar_parent_missing, got %', sqlerrm; end if;
  end;

  begin
    perform create_supplier('{"name_ar":"مورد"}'::jsonb);
    raise exception 'case27 failed: tenant B created supplier without A/P parent';
  exception when others then
    if sqlerrm <> 'ap_parent_missing' then raise exception 'case27 failed: expected ap_parent_missing, got %', sqlerrm; end if;
  end;
end $$;
rollback;

-- 28. create_chart_account parent validation: inactive parent, type mismatch, then valid.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_parent uuid;
  v_child uuid;
begin
  v_parent := create_chart_account('{"code":"9500","name_ar":"أب","name_en":"Parent","type":"asset"}'::jsonb);

  -- type mismatch under active parent
  begin
    perform create_chart_account(jsonb_build_object('code','9501','name_ar','ابن','name_en','Child','type','liability','parent_id',v_parent::text));
    raise exception 'case28 failed: type-mismatch child accepted';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise exception 'case28 failed: mismatch expected validation_failed, got %', sqlerrm; end if;
  end;

  -- matching active parent succeeds
  v_child := create_chart_account(jsonb_build_object('code','9502','name_ar','ابن','name_en','Child','type','asset','parent_id',v_parent::text));
  if v_child is null then
    raise exception 'case28 failed: valid child not created';
  end if;

  -- now deactivate parent and confirm inactive parent is rejected
  perform deactivate_chart_account(v_parent);
  begin
    perform create_chart_account(jsonb_build_object('code','9503','name_ar','ابن','name_en','Child','type','asset','parent_id',v_parent::text));
    raise exception 'case28 failed: inactive-parent child accepted';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise exception 'case28 failed: inactive expected validation_failed, got %', sqlerrm; end if;
  end;
end $$;
rollback;

-- 29. CoA edit cannot deactivate; deactivate needs delete permission.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'chart_of_accounts.edit', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config('test.phase4.manual', create_chart_account('{"code":"9600","name_ar":"يدوي","name_en":"Manual","type":"expense"}'::jsonb)::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_id uuid := current_setting('test.phase4.manual')::uuid;
  v_active boolean;
begin
  begin
    perform update_chart_account(v_id, '{"is_active":false}'::jsonb);
    raise exception 'case29 failed: edit deactivated via is_active payload';
  exception when others then
    if sqlerrm <> 'validation_failed' then raise exception 'case29 failed: expected validation_failed, got %', sqlerrm; end if;
  end;

  select is_active into v_active from chart_of_accounts where id = v_id;
  if v_active <> true then
    raise exception 'case29 failed: account became inactive via edit';
  end if;

  begin
    perform deactivate_chart_account(v_id);
    raise exception 'case29 failed: edit-only user deactivated account';
  exception when others then
    if sqlerrm <> 'permission_denied' then raise exception 'case29 failed: deactivate expected permission_denied, got %', sqlerrm; end if;
  end;
end $$;
rollback;

-- 30. CoA deactivate works with chart_of_accounts.delete.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_products_tu, 'chart_of_accounts.create', v_owner),
    (v_tenant_a, v_products_tu, 'chart_of_accounts.delete', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_id uuid;
  v_active boolean;
begin
  v_id := create_chart_account('{"code":"9700","name_ar":"يدوي","name_en":"Manual","type":"expense"}'::jsonb);
  perform deactivate_chart_account(v_id);
  select is_active into v_active from chart_of_accounts where id = v_id;
  if v_active <> false then
    raise exception 'case30 failed: delete-permission user could not deactivate';
  end if;
end $$;
rollback;

-- 31. Manual CoA account code is immutable even for the table owner.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform set_config(
    'test.phase4.manual_code_lock',
    create_chart_account('{"code":"9800","name_ar":"كود يدوي","name_en":"Manual Code","type":"expense"}'::jsonb)::text,
    true
  );
end $$;
reset role;
do $$
declare
  v_id uuid := current_setting('test.phase4.manual_code_lock')::uuid;
begin
  begin
    update chart_of_accounts set code = '9801' where id = v_id;
    raise exception 'case31 failed: manual CoA code changed';
  exception when others then
    if sqlerrm <> 'immutable_column' then
      raise exception 'case31 failed: expected immutable_column, got %', sqlerrm;
    end if;
  end;
end $$;
rollback;

select 'phase_4_customers_suppliers_coa_verification_passed' as result;
