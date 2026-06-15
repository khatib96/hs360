-- Phase 5 M4: tax foundation verification.
-- Run after `supabase db reset` via scripts/test/run_sql_suites.sh Phase B.
-- Manual: docker exec -i supabase_db_hs360 psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/phase_5_tax_foundation.sql

\set ON_ERROR_STOP on

-- Seed constants:
--   tenant_a=101, tenant_b=102, owner=201 (manager), zero_user=202, products_user=203,
--   product_a=901, owner_tu=301, zero_tu=302, products_tu=303

-- ---------------------------------------------------------------------------
-- 1. Direct UPDATE tenant_settings.tax_enabled without gate -> direct_write_forbidden
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_zero_tu uuid := '00000000-0000-0000-0000-000000000302';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  delete from public.user_permissions
  where tenant_user_id = v_zero_tu
    and permission_id in (
      'settings.company.edit',
      'settings.company.view',
      'settings.tax.edit',
      'settings.tax.view'
    );

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_zero_tu, 'settings.company.edit', v_owner),
    (v_tenant_a, v_zero_tu, 'settings.company.view', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  begin
    update public.tenant_settings
    set tax_enabled = true
    where tenant_id = v_tenant_a;
    raise exception 'case1 failed: direct tax_enabled update succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2. update_tax_settings via RPC with settings.tax.edit on products_user succeeds
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id in ('settings.tax.edit', 'settings.tax.view');

  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'settings.tax.edit', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  perform public.update_tax_settings(
    jsonb_build_object('tax_registration_number', 'M4-CASE-2')
  );
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 3. Direct INSERT chart_of_accounts code 1151 without provisioning gate -> direct_write_forbidden
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_parent_id uuid;
begin
  begin
    create role m4_gate_test nologin bypassrls;
  exception
    when duplicate_object then null;
  end;

  grant insert, select on public.chart_of_accounts to m4_gate_test;
  grant usage on schema public to m4_gate_test;
  grant m4_gate_test to postgres;

  select id into v_parent_id
  from public.chart_of_accounts
  where tenant_id = v_tenant_a
    and code = '1000';

  perform set_config('test.m4.parent1000', v_parent_id::text, true);
end $$;
set local role m4_gate_test;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_parent_id uuid := current_setting('test.m4.parent1000')::uuid;
begin
  begin
    insert into public.chart_of_accounts (
      tenant_id, code, name_ar, name_en, type, parent_id, is_system, is_active
    )
    values (
      v_tenant_a, '1151', 'ضريبة', 'Input Tax', 'asset', v_parent_id, true, true
    );
    raise exception 'case3 failed: direct 1151 insert succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 4. create_tax_rate with omitted account IDs provisions and returns uuid (manager 201)
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_rate_id uuid;
  v_account_count int;
begin
  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'M4-PROV',
      'name_ar', 'ضريبة تأسيس',
      'name_en', 'Provision Test Rate',
      'rate', 5,
      'effective_from', current_date
    )
  );

  if v_rate_id is null then
    raise exception 'case4 failed: create_tax_rate returned null';
  end if;

  select count(*) into v_account_count
  from public.chart_of_accounts
  where tenant_id = v_tenant_a
    and code in ('1151', '2151', '5151');

  if v_account_count <> 3 then
    raise exception 'case4 failed: expected 3 provisioned tax accounts, got %', v_account_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 5. Pre-insert wrong-type account code 2151 as expense -> tax_account_code_conflict
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_parent_id uuid;
begin
  select id into v_parent_id
  from public.chart_of_accounts
  where tenant_id = v_tenant_a
    and code = '5000';

  insert into public.chart_of_accounts (
    tenant_id, code, name_ar, name_en, type, parent_id, is_system, is_active
  )
  values (
    v_tenant_a, '2151', 'خطأ', 'Wrong Output Tax', 'expense', v_parent_id, true, true
  )
  on conflict (tenant_id, code) do update
  set
    type = excluded.type,
    name_ar = excluded.name_ar,
    name_en = excluded.name_en,
    parent_id = excluded.parent_id,
    is_system = excluded.is_system,
    is_active = excluded.is_active;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform public.create_tax_rate(
      jsonb_build_object(
        'code', 'M4-CONFLICT',
        'name_ar', 'ضريبة',
        'name_en', 'Conflict Test Rate',
        'rate', 5,
        'effective_from', current_date
      )
    );
    raise exception 'case5 failed: create_tax_rate succeeded after wrong-type 2151';
  exception
    when others then
      if sqlerrm not like '%tax_account_code_conflict%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 6. Anchor rollover: default_tax_rate_id advances to latest version
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_v1_id uuid;
  v_v2_id uuid;
  v_default_id uuid;
begin
  v_v1_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'VAT',
      'name_ar', 'ضريبة v1',
      'name_en', 'VAT v1',
      'rate', 5,
      'effective_from', current_date - 30
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object(
      'tax_enabled', true,
      'default_tax_rate_id', v_v1_id
    )
  );

  v_v2_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'VAT',
      'name_ar', 'ضريبة v2',
      'name_en', 'VAT v2',
      'rate', 5,
      'effective_from', current_date
    )
  );

  select default_tax_rate_id into v_default_id
  from public.tenant_settings
  where tenant_id = v_tenant_a;

  if v_default_id is distinct from v_v2_id then
    raise exception 'case6 failed: default_tax_rate_id % expected v2 %', v_default_id, v_v2_id;
  end if;

  if v_v1_id = v_v2_id then
    raise exception 'case6 failed: v1 and v2 ids must differ';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 7. Composite FK: default rate from tenant B -> cross_tenant_reference or validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_b_rate_id uuid;
begin
  v_b_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'B-VAT',
      'name_ar', 'ضريبة B',
      'name_en', 'Tenant B VAT',
      'rate', 5,
      'effective_from', current_date
    )
  );

  perform set_config('test.m4.tenant_b_rate', v_b_rate_id::text, true);
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_b_rate_id uuid := current_setting('test.m4.tenant_b_rate')::uuid;
begin
  begin
    perform public.update_tax_settings(
      jsonb_build_object(
        'tax_enabled', true,
        'default_tax_rate_id', v_b_rate_id
      )
    );
    raise exception 'case7 failed: cross-tenant default_tax_rate_id accepted';
  exception
    when others then
      if sqlerrm not like '%cross_tenant_reference%'
        and sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 8. Historical resolution: deactivated past rate still resolves for past invoice_date
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_v1_id uuid;
  v_v2_id uuid;
  v_past_date date := current_date - 45;
  v_payload jsonb;
begin
  update public.products
  set tax_class = 'taxable'
  where id = v_product_a
    and tenant_id = v_tenant_a;

  v_v1_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'HIST',
      'name_ar', 'ضريبة قديمة',
      'name_en', 'Historical v1',
      'rate', 5,
      'effective_from', current_date - 60
    )
  );

  v_v2_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'HIST',
      'name_ar', 'ضريبة حالية',
      'name_en', 'Historical v2',
      'rate', 10,
      'effective_from', current_date - 30
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object(
      'tax_enabled', true,
      'default_tax_rate_id', v_v2_id
    )
  );

  perform public.deactivate_tax_rate(v_v1_id);

  select public.get_effective_tax_rate(v_product_a, v_past_date) into v_payload;

  if (v_payload ->> 'tax_rate_id')::uuid is distinct from v_v1_id then
    raise exception 'case8 failed: past date resolved % expected v1 %',
      v_payload ->> 'tax_rate_id', v_v1_id;
  end if;

  if (v_payload ->> 'tax_rate')::numeric <> 5 then
    raise exception 'case8 failed: expected rate 5, got %', v_payload ->> 'tax_rate';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 9. Current availability: deactivated current rate not found for current_date
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_rate_id uuid;
begin
  update public.products
  set tax_class = 'taxable'
  where id = v_product_a;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'CURR',
      'name_ar', 'ضريبة حالية',
      'name_en', 'Current Rate',
      'rate', 5,
      'effective_from', current_date - 30
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object(
      'tax_enabled', true,
      'default_tax_rate_id', v_rate_id
    )
  );
end $$;
reset role;
do $$
declare
  v_rate_id uuid;
begin
  select id into v_rate_id
  from public.tax_rates
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and code = 'CURR'
  order by effective_from desc
  limit 1;

  update public.tax_rates
  set is_active = false
  where id = v_rate_id;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
begin
  begin
    perform public.get_effective_tax_rate(v_product_a, current_date);
    raise exception 'case9 failed: deactivated current rate resolved for today';
  exception
    when others then
      if sqlerrm not like '%tax_rate_not_found%' then
        raise;
      end if;
  end;

  begin
    perform public.calculate_invoice_totals(
      'sales',
      current_date,
      jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product_a,
          'qty', 1,
          'unit_price', 10,
          'discount_pct', 0
        )
      )
    );
    raise exception 'case9 failed: calculate_invoice_totals accepted deactivated current rate';
  exception
    when others then
      if sqlerrm not like '%tax_rate_not_found%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 10. Non-append: create_tax_rate with effective_from <= latest -> validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_effective date := current_date - 10;
begin
  perform public.create_tax_rate(
    jsonb_build_object(
      'code', 'APPEND',
      'name_ar', 'ضريبة',
      'name_en', 'Append v1',
      'rate', 5,
      'effective_from', v_effective
    )
  );

  begin
    perform public.create_tax_rate(
      jsonb_build_object(
        'code', 'APPEND',
        'name_ar', 'ضريبة',
        'name_en', 'Append v2 invalid',
        'rate', 5,
        'effective_from', v_effective
      )
    );
    raise exception 'case10 failed: non-append effective_from accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 11. update_tax_rate with is_active in payload -> validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_rate_id uuid;
begin
  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'UPD',
      'name_ar', 'ضريبة',
      'name_en', 'Update Guard Rate',
      'rate', 5,
      'effective_from', current_date
    )
  );

  begin
    perform public.update_tax_rate(
      v_rate_id,
      jsonb_build_object('is_active', false)
    );
    raise exception 'case11 failed: is_active patch accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 12. Direct INSERT child under 1151 parent -> account_protected
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_parent_id uuid;
begin
  perform public.create_tax_rate(
    jsonb_build_object(
      'code', 'LEAF',
      'name_ar', 'ضريبة',
      'name_en', 'Leaf Parent Rate',
      'rate', 5,
      'effective_from', current_date
    )
  );

  select id into v_parent_id
  from public.chart_of_accounts
  where tenant_id = v_tenant_a
    and code = '1151';

  perform set_config('test.m4.leaf_parent', v_parent_id::text, true);
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_parent_id uuid := current_setting('test.m4.leaf_parent')::uuid;
begin
  begin
    insert into public.chart_of_accounts (
      tenant_id, code, name_ar, name_en, type, parent_id, is_system, is_active
    )
    values (
      v_tenant_a, '1151-1', 'فرع', 'Tax Child', 'asset', v_parent_id, false, true
    );
    raise exception 'case12 failed: child insert under 1151 succeeded';
  exception
    when others then
      if sqlerrm not like '%account_protected%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 13. products.tax_class UPDATE without products.edit denied; with products.edit succeeds
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  update public.products
  set tax_class = 'non_taxable'
  where id = v_product_a
    and tenant_id = v_tenant_a;

  delete from public.user_permissions
  where tenant_user_id = v_products_tu
    and permission_id = 'products.edit';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_class public.product_tax_class;
begin
  update public.products
  set tax_class = 'taxable'
  where id = v_product_a;

  select tax_class into v_class
  from public.products
  where id = v_product_a;

  if v_class <> 'non_taxable' then
    raise exception 'case13 failed: tax_class changed without products.edit (now %)', v_class;
  end if;
end $$;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into public.user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (v_tenant_a, v_products_tu, 'products.edit', v_owner)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_class public.product_tax_class;
begin
  update public.products
  set tax_class = 'taxable'
  where id = v_product_a;

  select tax_class into v_class
  from public.products
  where id = v_product_a;

  if v_class <> 'taxable' then
    raise exception 'case13 failed: tax_class not updated with products.edit (still %)', v_class;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 14. DELETE tax_rates blocked -> tax_rate_in_use
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_rate_id uuid;
begin
  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'DEL',
      'name_ar', 'ضريبة',
      'name_en', 'Delete Guard Rate',
      'rate', 5,
      'effective_from', current_date
    )
  );

  perform set_config('test.m4.delete_rate', v_rate_id::text, true);
end $$;
reset role;
do $$
declare
  v_rate_id uuid := current_setting('test.m4.delete_rate')::uuid;
begin
  begin
    delete from public.tax_rates where id = v_rate_id;
    raise exception 'case14 failed: tax_rates delete succeeded';
  exception
    when others then
      if sqlerrm not like '%tax_rate_in_use%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 15. calculate_invoice_totals with forbidden key tax_amount -> validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
begin
  begin
    perform public.calculate_invoice_totals(
      'sales',
      current_date,
      jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product_a,
          'qty', 1,
          'unit_price', 10,
          'discount_pct', 0,
          'tax_amount', 1
        )
      )
    );
    raise exception 'case15 failed: forbidden tax_amount key accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 16. calculate_invoice_totals qty=0 -> validation_failed
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
begin
  begin
    perform public.calculate_invoice_totals(
      'sales',
      current_date,
      jsonb_build_array(
        jsonb_build_object(
          'product_id', v_product_a,
          'qty', 0,
          'unit_price', 10,
          'discount_pct', 0
        )
      )
    );
    raise exception 'case16 failed: qty=0 accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 17. Parity: taxable line qty=2, price=10, rate=5%, tax_enabled -> 20 / 1 / 21
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_rate_id uuid;
  v_result jsonb;
begin
  update public.products
  set tax_class = 'taxable'
  where id = v_product_a;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'PARITY',
      'name_ar', 'ضريبة',
      'name_en', 'Parity Rate',
      'rate', 5,
      'effective_from', current_date - 30
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object(
      'tax_enabled', true,
      'default_tax_rate_id', v_rate_id
    )
  );

  select public.calculate_invoice_totals(
    'sales',
    current_date,
    jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product_a,
        'qty', 2,
        'unit_price', 10,
        'discount_pct', 0
      )
    )
  ) into v_result;

  if (v_result ->> 'subtotal')::numeric <> 20 then
    raise exception 'case17 failed: subtotal % expected 20', v_result ->> 'subtotal';
  end if;
  if (v_result ->> 'tax_amount')::numeric <> 1 then
    raise exception 'case17 failed: tax_amount % expected 1', v_result ->> 'tax_amount';
  end if;
  if (v_result ->> 'total')::numeric <> 21 then
    raise exception 'case17 failed: total % expected 21', v_result ->> 'total';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 18. Tax disabled calculate -> zero tax
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_rate_id uuid;
  v_result jsonb;
begin
  update public.products
  set tax_class = 'taxable'
  where id = v_product_a;

  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'OFF',
      'name_ar', 'ضريبة',
      'name_en', 'Disabled Tax Rate',
      'rate', 5,
      'effective_from', current_date
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object(
      'tax_enabled', false,
      'default_tax_rate_id', v_rate_id
    )
  );

  select public.calculate_invoice_totals(
    'sales',
    current_date,
    jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product_a,
        'qty', 2,
        'unit_price', 10,
        'discount_pct', 0
      )
    )
  ) into v_result;

  if (v_result ->> 'tax_amount')::numeric <> 0 then
    raise exception 'case18 failed: tax_amount % expected 0 when tax disabled', v_result ->> 'tax_amount';
  end if;
  if (v_result ->> 'total')::numeric <> 20 then
    raise exception 'case18 failed: total % expected 20 when tax disabled', v_result ->> 'total';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 19. Direct INSERT tax_rates as authenticated -> insufficient_privilege or direct_write_forbidden
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
begin
  begin
    insert into public.tax_rates (
      tenant_id, code, name_ar, name_en, rate, effective_from,
      output_account_id, input_account_id, is_recoverable, is_active
    )
    values (
      v_tenant_a, 'HACK', 'x', 'x', 5, current_date,
      v_cash, v_cash, true, true
    );
    raise exception 'case19 failed: direct tax_rates insert succeeded';
  exception
    when insufficient_privilege then
      null;
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%'
        and sqlerrm not like '%insufficient_privilege%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 20. Tenant B user cannot SELECT tenant A tax_rates (RLS)
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform public.create_tax_rate(
    jsonb_build_object(
      'code', 'RLS-A',
      'name_ar', 'ضريبة',
      'name_en', 'Tenant A RLS Rate',
      'rate', 5,
      'effective_from', current_date
    )
  );
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
declare
  v_count bigint;
begin
  select count(*) into v_count
  from public.tax_rates
  where tenant_id = '00000000-0000-0000-0000-000000000101';

  if v_count <> 0 then
    raise exception 'case20 failed: tenant B user saw % tenant A tax_rates rows', v_count;
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 21. update_tax_settings validates resulting state when tax already enabled
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_rate_id uuid;
begin
  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'STATE',
      'name_ar', 'ضريبة',
      'name_en', 'State Validation Rate',
      'rate', 5,
      'effective_from', current_date - 30
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object(
      'tax_enabled', true,
      'default_tax_rate_id', v_rate_id
    )
  );
end $$;
reset role;
do $$
declare
  v_rate_id uuid;
begin
  select id into v_rate_id
  from public.tax_rates
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and code = 'STATE'
  order by effective_from desc
  limit 1;

  update public.tax_rates
  set is_active = false
  where id = v_rate_id;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform public.update_tax_settings(
      jsonb_build_object('tax_registration_number', 'STALE-DEFAULT')
    );
    raise exception 'case21 failed: stale default accepted without tax_enabled in payload';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 22. create_tax_rate rejects partial tax account IDs
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
begin
  begin
    perform public.create_tax_rate(
      jsonb_build_object(
        'code', 'PARTIAL',
        'name_ar', 'ضريبة',
        'name_en', 'Partial Accounts',
        'rate', 5,
        'effective_from', current_date,
        'output_account_id', v_cash
      )
    );
    raise exception 'case22 failed: partial account IDs accepted';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 23. Non-reserved chart_of_accounts INSERT with table privilege succeeds
--     (trigger must not call revoked is_reserved_tax_account_code)
-- ---------------------------------------------------------------------------
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_parent_id uuid;
begin
  begin
    create role m4_coa_test nologin bypassrls;
  exception
    when duplicate_object then null;
  end;

  grant insert, select on public.chart_of_accounts to m4_coa_test;
  grant usage on schema public to m4_coa_test;
  grant m4_coa_test to postgres;

  select id into v_parent_id
  from public.chart_of_accounts
  where tenant_id = v_tenant_a
    and code = '5000'
  limit 1;

  perform set_config('test.m4.parent5000', v_parent_id::text, true);
end $$;
set local role m4_coa_test;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_parent_id uuid := current_setting('test.m4.parent5000')::uuid;
  v_new_id uuid;
begin
  insert into public.chart_of_accounts (
    tenant_id, code, name_ar, name_en, type, parent_id, is_system, is_active
  )
  values (
    v_tenant_a, 'M4-NR-9999', 'حساب اختبار', 'Non Reserved Test', 'expense', v_parent_id, false, true
  )
  returning id into v_new_id;

  if v_new_id is null then
    raise exception 'case23 failed: non-reserved insert returned null id';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 24. invoice_lines tax snapshot CHECK rejects inconsistent non_taxable row
-- ---------------------------------------------------------------------------
begin;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_customer uuid;
  v_invoice_id uuid;
  v_rate_id uuid;
begin
  select id into v_customer
  from public.customers
  where tenant_id = v_tenant_a
  limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
    v_customer := public.create_customer(
      '{"name_ar":"عميل M4","phone_primary":"+96550000998","create_account":true}'::jsonb
    );
  end if;

  insert into public.invoices (
    tenant_id, type, status, customer_id, date, subtotal, total
  )
  values (v_tenant_a, 'sales', 'draft', v_customer, current_date, 0, 0)
  returning id into v_invoice_id;

  select id into v_rate_id
  from public.tax_rates
  where tenant_id = v_tenant_a
  limit 1;

  begin
    insert into public.invoice_lines (
      tenant_id,
      invoice_id,
      product_id,
      qty,
      unit_price,
      gross_amount,
      discount_amount,
      before_tax_amount,
      after_tax_amount,
      tax_rate_id,
      tax_rate,
      tax_class,
      taxable_amount,
      tax_amount,
      line_total,
      line_order
    )
    values (
      v_tenant_a,
      v_invoice_id,
      v_product,
      1,
      10,
      10,
      0,
      10,
      10,
      v_rate_id,
      5,
      'non_taxable',
      5,
      0.5,
      10,
      1
    );
    raise exception 'case24 failed: inconsistent non_taxable snapshot accepted';
  exception
    when check_violation then
      null;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 25. deactivate_tax_rate blocks default-series current version while tax enabled
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_rate_id uuid;
begin
  v_rate_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'PROTECT',
      'name_ar', 'ضريبة',
      'name_en', 'Protected Default Series',
      'rate', 5,
      'effective_from', current_date - 30
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object(
      'tax_enabled', true,
      'default_tax_rate_id', v_rate_id
    )
  );

  begin
    perform public.deactivate_tax_rate(v_rate_id);
    raise exception 'case25 failed: default-series deactivation accepted while tax enabled';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 26. Backfill algorithm regression: line_total authoritative (not a 058→059 upgrade replay)
--     Replays the migration 059 normalization UPDATEs on a synthetic legacy-shaped row.
-- ---------------------------------------------------------------------------
begin;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_customer uuid;
  v_invoice_id uuid;
  v_line_id uuid;
  v_before numeric;
  v_after numeric;
begin
  select id into v_customer
  from public.customers
  where tenant_id = v_tenant_a
  limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
    v_customer := public.create_customer(
      '{"name_ar":"عميل M4","phone_primary":"+96550000997","create_account":true}'::jsonb
    );
  end if;

  insert into public.invoices (
    tenant_id, type, status, customer_id, date, subtotal, total
  )
  values (v_tenant_a, 'sales', 'draft', v_customer, current_date, 0, 0)
  returning id into v_invoice_id;

  alter table public.invoice_lines
    drop constraint if exists chk_invoice_lines_tax_snapshot_class,
    drop constraint if exists chk_invoice_lines_snapshot_amounts;

  insert into public.invoice_lines (
    tenant_id,
    invoice_id,
    product_id,
    qty,
    unit_price,
    gross_amount,
    discount_amount,
    before_tax_amount,
    after_tax_amount,
    tax_rate,
    tax_class,
    taxable_amount,
    tax_amount,
    line_total,
    line_order
  )
  values (
    v_tenant_a,
    v_invoice_id,
    v_product,
    1,
    200,
    0,
    0,
    999,
    0,
    0,
    'non_taxable',
    0,
    0,
    150,
    1
  )
  returning id into v_line_id;

  update public.invoice_lines il
  set gross_amount = round(
    il.qty * il.unit_price,
    coalesce(c.decimal_places, 3)
  )
  from public.tenants t
  left join public.currencies c on c.id = t.default_currency_id
  where il.id = v_line_id
    and il.tenant_id = t.id
    and il.gross_amount = 0;

  update public.invoice_lines il
  set before_tax_amount = case
    when il.line_total > 0 then il.line_total
    else il.gross_amount - il.discount_amount
  end
  where il.id = v_line_id;

  update public.invoice_lines il
  set
    after_tax_amount = il.before_tax_amount,
    line_total = case
      when il.line_total > 0 then il.line_total
      else il.before_tax_amount
    end
  where il.id = v_line_id;

  select before_tax_amount, after_tax_amount
  into v_before, v_after
  from public.invoice_lines
  where id = v_line_id;

  if v_before <> 150 or v_after <> 150 then
    raise exception 'case26 failed: legacy backfill before=% after=% expected 150/150',
      v_before, v_after;
  end if;

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
    ),
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
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 27. EXCLUDE constraint blocks overlapping tax rate ranges (postgres direct)
-- ---------------------------------------------------------------------------
begin;
reset role;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_output uuid := '00000000-0000-0000-0000-000000000501';
  v_input uuid := '00000000-0000-0000-0000-000000000501';
begin
  begin
    insert into public.tax_rates (
      tenant_id, code, name_ar, name_en, rate, effective_from, effective_to,
      output_account_id, input_account_id, is_recoverable, is_active
    )
    values
      (
        v_tenant_a, 'OVERLAP', 'v1', 'v1', 5, current_date - 60, current_date - 1,
        v_output, v_input, true, true
      ),
      (
        v_tenant_a, 'OVERLAP', 'v2', 'v2', 5, current_date - 30, current_date + 30,
        v_output, v_input, true, true
      );
    raise exception 'case27 failed: overlapping tax rate ranges accepted';
  exception
    when exclusion_violation then
      null;
  end;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 28. Historical calculate_invoice_totals still resolves deactivated past rate
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_v1_id uuid;
  v_v2_id uuid;
  v_past_date date := current_date - 45;
  v_result jsonb;
begin
  update public.products
  set tax_class = 'taxable'
  where id = v_product_a;

  v_v1_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'CALCHIST',
      'name_ar', 'ضريبة قديمة',
      'name_en', 'Calc Historical v1',
      'rate', 5,
      'effective_from', current_date - 60
    )
  );

  v_v2_id := public.create_tax_rate(
    jsonb_build_object(
      'code', 'CALCHIST',
      'name_ar', 'ضريبة حالية',
      'name_en', 'Calc Historical v2',
      'rate', 10,
      'effective_from', current_date - 30
    )
  );

  perform public.update_tax_settings(
    jsonb_build_object(
      'tax_enabled', true,
      'default_tax_rate_id', v_v2_id
    )
  );

  perform public.deactivate_tax_rate(v_v1_id);

  select public.calculate_invoice_totals(
    'sales',
    v_past_date,
    jsonb_build_array(
      jsonb_build_object(
        'product_id', v_product_a,
        'qty', 2,
        'unit_price', 10,
        'discount_pct', 0
      )
    )
  ) into v_result;

  if (v_result ->> 'tax_amount')::numeric <> 1 then
    raise exception 'case28 failed: historical tax_amount % expected 1', v_result ->> 'tax_amount';
  end if;
end $$;
rollback;

select 'phase_5_tax_foundation.sql: all cases passed' as result;
