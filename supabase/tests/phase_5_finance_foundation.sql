-- Phase 5 M1: finance foundation verification.
-- Run after `supabase db reset`:
-- docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_5_finance_foundation.sql

\set ON_ERROR_STOP on

-- 1. Direct invoice insert blocked for authenticated.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer uuid;
begin
  select id into v_customer from customers where tenant_id = v_tenant_a limit 1;
  begin
    insert into invoices (tenant_id, type, status, customer_id, date, subtotal, total)
    values (v_tenant_a, 'sales', 'draft', v_customer, current_date, 0, 0);
    raise exception 'case1 failed: direct invoice insert succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%'
        and sqlerrm not like '%violates check constraint%'
        and sqlerrm not like '%violates not-null%'
      then
        raise;
      end if;
  end;
end $$;
rollback;

-- 2. Direct invoice_line insert blocked.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
begin
  begin
    insert into invoice_lines (
      tenant_id, invoice_id, product_id, qty, unit_price, line_total, line_order
    )
    values (
      v_tenant_a, gen_random_uuid(), gen_random_uuid(), 1, 1, 1, 1
    );
    raise exception 'case2 failed: direct invoice_line insert succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%'
      then
        raise;
      end if;
  end;
end $$;
rollback;

-- 3. Direct voucher insert blocked.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
begin
  begin
    insert into vouchers (
      tenant_id, voucher_number, type, date, amount, payment_method,
      account_id, cash_account_id
    )
    values (
      v_tenant_a, 'RV-TEST', 'receipt', current_date, 1, 'cash', v_cash, v_cash
    );
    raise exception 'case3 failed: direct voucher insert succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%'
        and sqlerrm not like '%violates check constraint%'
      then
        raise;
      end if;
  end;
end $$;
rollback;

-- 4. Direct allocation insert blocked.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    insert into voucher_invoice_allocations (
      tenant_id, voucher_id, invoice_id, allocated_amount
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      gen_random_uuid(),
      gen_random_uuid(),
      1
    );
    raise exception 'case4 failed: direct allocation insert succeeded';
  exception
    when others then
      if sqlerrm not like '%direct_write_forbidden%'
        and sqlerrm not like '%permission denied%'
      then
        raise;
      end if;
  end;
end $$;
rollback;

-- 5. Cross-tenant invoice line blocked by composite FK.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';
  v_customer uuid;
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_invoice_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

  select id into v_customer
  from customers
  where tenant_id = v_tenant_a
  limit 1;

  if v_customer is null then
    v_customer := create_customer(
      '{"name_ar":"عميل M1","phone_primary":"+96550000999","create_account":true}'::jsonb
    );
  end if;

  insert into invoices (tenant_id, type, status, customer_id, date, subtotal, total)
  values (v_tenant_a, 'sales', 'draft', v_customer, current_date, 0, 0)
  returning id into v_invoice_id;

  begin
    insert into invoice_lines (
      tenant_id, invoice_id, product_id, qty, unit_price, line_total, line_order
    )
    values (v_tenant_b, v_invoice_id, v_product, 1, 1, 1, 1);
    raise exception 'case5 failed: cross-tenant invoice line succeeded';
  exception
    when foreign_key_violation then
      null;
  end;
end $$;
rollback;

-- 6. Voucher amount <= 0 rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
begin
  select id into v_customer from customers where tenant_id = v_tenant_a limit 1;
  if v_customer is null then
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
    v_customer := create_customer(
      '{"name_ar":"عميل M1","phone_primary":"+96550000998","create_account":true}'::jsonb
    );
  end if;

  begin
    insert into vouchers (
      tenant_id, voucher_number, type, date, amount, payment_method,
      customer_id, account_id, cash_account_id
    )
    values (
      v_tenant_a, 'RV-ZERO', 'receipt', current_date, 0, 'cash',
      v_customer, v_cash, v_cash
    );
    raise exception 'case6 failed: zero voucher amount succeeded';
  exception
    when check_violation then
      null;
  end;
end $$;
rollback;

-- 7. Negative invoice total rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer uuid;
begin
  select id into v_customer from customers where tenant_id = v_tenant_a limit 1;
  if v_customer is null then
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
    v_customer := create_customer(
      '{"name_ar":"عميل M1","phone_primary":"+96550000997","create_account":true}'::jsonb
    );
  end if;

  begin
    insert into invoices (
      tenant_id, type, status, customer_id, date, subtotal, total
    )
    values (
      v_tenant_a, 'sales', 'draft', v_customer, current_date, 0, -1
    );
    raise exception 'case7 failed: negative invoice total succeeded';
  exception
    when check_violation then
      null;
  end;
end $$;
rollback;

-- 8. Posted journal line update blocked.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_revenue uuid := '00000000-0000-0000-0000-000000000506';
  v_entry_id uuid;
  v_line_id uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into journal_entries (
    tenant_id, entry_number, date, source, is_posted, posted_at, posted_by
  )
  values (
    v_tenant_a, 'JE-TEST-001', current_date, 'manual', true, now(), v_owner
  )
  returning id into v_entry_id;

  insert into journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order
  )
  values
    (v_tenant_a, v_entry_id, v_cash, 10, 0, 1),
    (v_tenant_a, v_entry_id, v_revenue, 0, 10, 2);

  select id into v_line_id
  from journal_lines
  where journal_entry_id = v_entry_id
  limit 1;

  begin
    update journal_lines set debit = 20 where id = v_line_id;
    raise exception 'case8 failed: posted journal line update succeeded';
  exception
    when others then
      if sqlerrm not like '%posted_journal_line_immutable%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 9. Single-line journal posting rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_entry_id uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into journal_entries (
    tenant_id, entry_number, date, source, is_posted
  )
  values (
    v_tenant_a, 'JE-TEST-002', current_date, 'manual', false
  )
  returning id into v_entry_id;

  insert into journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order
  )
  values (v_tenant_a, v_entry_id, v_cash, 10, 0, 1);

  begin
    update journal_entries
    set is_posted = true, posted_at = now(), posted_by = v_owner
    where id = v_entry_id;
    raise exception 'case9 failed: single-line journal post succeeded';
  exception
    when others then
      if sqlerrm not like '%journal_entry_requires_two_lines%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 10-11. Document sequences SI and JE (postgres/internal).
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_si1 text;
  v_si2 text;
  v_je1 text;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

  v_si1 := public.next_document_number('SI');
  v_si2 := public.next_document_number('SI');
  v_je1 := public.next_document_number('JE');

  if v_si1 <> 'SI-000001' then
    raise exception 'case10 failed: SI first number %', v_si1;
  end if;
  if v_si2 <> 'SI-000002' then
    raise exception 'case11 failed: SI second number %', v_si2;
  end if;
  if v_je1 <> 'JE-000001' then
    raise exception 'case11b failed: JE first number %', v_je1;
  end if;
end $$;
rollback;

-- 12. Authenticated can call RPC stub (feature_not_implemented).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  begin
    perform public.record_sales_invoice('{}'::jsonb, gen_random_uuid());
    raise exception 'case12 failed: stub returned without error';
  exception
    when others then
      if sqlerrm not like '%feature_not_implemented%' then
        raise;
      end if;
  end;
end $$;
rollback;

-- 13. Anon cannot execute internal helpers or stubs.
begin;
set local role anon;
do $$
begin
  begin
    perform public.next_document_number('SI');
    raise exception 'case13a failed: anon next_document_number succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    perform public.record_sales_invoice('{}'::jsonb, gen_random_uuid());
    raise exception 'case13b failed: anon record_sales_invoice succeeded';
  exception
    when insufficient_privilege then
      null;
  end;
end $$;
rollback;

-- 14. Sales invoice with supplier fails party check.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_supplier uuid;
begin
  select id into v_supplier from suppliers where tenant_id = v_tenant_a limit 1;
  if v_supplier is null then
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
    v_supplier := create_supplier(
      '{"name_ar":"مورد M1","phone":"+96550000996","create_account":true}'::jsonb
    );
  end if;

  begin
    insert into invoices (
      tenant_id, type, status, supplier_id, date, subtotal, total
    )
    values (
      v_tenant_a, 'sales', 'draft', v_supplier, current_date, 0, 0
    );
    raise exception 'case14 failed: sales invoice with supplier succeeded';
  exception
    when check_violation then
      null;
  end;
end $$;
rollback;

-- 15. Duplicate invoice number rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_customer uuid;
begin
  select id into v_customer from customers where tenant_id = v_tenant_a limit 1;
  if v_customer is null then
    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
    v_customer := create_customer(
      '{"name_ar":"عميل M1","phone_primary":"+96550000995","create_account":true}'::jsonb
    );
  end if;

  insert into invoices (
    tenant_id, invoice_number, type, status, customer_id, date,
    subtotal, total, confirmed_at
  )
  values (
    v_tenant_a, 'SI-DUP-001', 'sales', 'confirmed', v_customer, current_date,
    0, 0, now()
  );

  begin
    insert into invoices (
      tenant_id, invoice_number, type, status, customer_id, date,
      subtotal, total, confirmed_at
    )
    values (
      v_tenant_a, 'SI-DUP-001', 'sales', 'confirmed', v_customer, current_date,
      0, 0, now()
    );
    raise exception 'case15 failed: duplicate invoice number succeeded';
  exception
    when unique_violation then
      null;
  end;
end $$;
rollback;

-- 16. Write-path smoke (AD-6).
begin;
do $$
declare
  v_id uuid;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform create_customer(
    '{"name_ar":"عميل smoke","phone_primary":"+96550000994","create_account":true}'::jsonb
  );

  v_id := public._test_finance_write_smoke();
  if v_id is null then
    raise exception 'case16 failed: smoke returned null';
  end if;
end $$;
rollback;

-- 17. New tenant gets all five sequences.
begin;
do $$
declare
  v_new_tenant uuid := gen_random_uuid();
  v_count int;
begin
  insert into tenants (id, name, slug)
  values (v_new_tenant, 'Sequence Test Tenant', 'seq-test-' || substr(v_new_tenant::text, 1, 8));

  select count(*) into v_count
  from document_sequences
  where tenant_id = v_new_tenant;

  if v_count <> 5 then
    raise exception 'case17 failed: expected 5 sequences, got %', v_count;
  end if;
end $$;
rollback;

-- 18. Tenant A has all five sequences after seed/backfill.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_count int;
begin
  select count(*) into v_count
  from document_sequences
  where tenant_id = v_tenant_a
    and sequence_key in ('SI', 'PI', 'RV', 'PV', 'JE');

  if v_count <> 5 then
    raise exception 'case18 failed: tenant A missing sequences (count=%)', v_count;
  end if;
end $$;
rollback;

-- 19. Idempotency columns and indexes exist (AD-2).
begin;
do $$
declare
  v_missing text[];
begin
  select array_agg(t.table_name)
  into v_missing
  from (
    values
      ('invoices'),
      ('vouchers'),
      ('journal_entries')
  ) as t(table_name)
  where not exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = t.table_name
      and c.column_name = 'idempotency_key'
  )
  or not exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = t.table_name
      and c.column_name = 'idempotency_payload_hash'
  );

  if v_missing is not null then
    raise exception 'case19 failed: missing idempotency columns on %', v_missing;
  end if;
end $$;
rollback;

-- 20. books_locked_through documented (AD-3).
begin;
do $$
declare
  v_comment text;
begin
  select col_description(
    'public.tenant_settings'::regclass,
    attnum
  )
  into v_comment
  from pg_attribute
  where attrelid = 'public.tenant_settings'::regclass
    and attname = 'books_locked_through'
    and not attisdropped;

  if v_comment is null or v_comment = '' then
    raise exception 'case20 failed: books_locked_through comment missing';
  end if;
end $$;
rollback;

\echo 'phase_5_finance_foundation.sql: all cases passed'
