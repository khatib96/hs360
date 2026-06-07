-- Phase 5 M1/M2 hardening verification.
-- Run after `supabase db reset`:
-- docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_5_m1_m2_hardening.sql

\set ON_ERROR_STOP on

-- ACL: authenticated SELECT on document_sequences denied (42501).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform 1 from public.document_sequences limit 1;
  raise exception 'acl_auth_select_docseq failed: select succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: authenticated INSERT on document_sequences denied (42501).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  insert into public.document_sequences (tenant_id, sequence_key, prefix, next_value, padding)
  values ('00000000-0000-0000-0000-000000000101', 'X', 'X', 1, 6);
  raise exception 'acl_auth_insert_docseq failed: insert succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: authenticated UPDATE on document_sequences denied (42501).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  update public.document_sequences
  set next_value = next_value + 1
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  raise exception 'acl_auth_update_docseq failed: update succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: authenticated DELETE on document_sequences denied (42501).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  delete from public.document_sequences
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and sequence_key = 'SI';
  raise exception 'acl_auth_delete_docseq failed: delete succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: authenticated TRUNCATE on document_sequences denied (42501).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  execute 'truncate public.document_sequences';
  raise exception 'acl_auth_truncate_docseq failed: truncate succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: anon SELECT on document_sequences denied (42501).
begin;
set local role anon;
do $$
begin
  perform 1 from public.document_sequences limit 1;
  raise exception 'acl_anon_select_docseq failed: select succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: anon INSERT on document_sequences denied (42501).
begin;
set local role anon;
do $$
begin
  insert into public.document_sequences (tenant_id, sequence_key, prefix, next_value, padding)
  values ('00000000-0000-0000-0000-000000000101', 'X', 'X', 1, 6);
  raise exception 'acl_anon_insert_docseq failed: insert succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: anon UPDATE on document_sequences denied (42501).
begin;
set local role anon;
do $$
begin
  update public.document_sequences
  set next_value = next_value + 1
  where tenant_id = '00000000-0000-0000-0000-000000000101';
  raise exception 'acl_anon_update_docseq failed: update succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: anon DELETE on document_sequences denied (42501).
begin;
set local role anon;
do $$
begin
  delete from public.document_sequences
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and sequence_key = 'SI';
  raise exception 'acl_anon_delete_docseq failed: delete succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: anon TRUNCATE on document_sequences denied (42501).
begin;
set local role anon;
do $$
begin
  execute 'truncate public.document_sequences';
  raise exception 'acl_anon_truncate_docseq failed: truncate succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: cross-tenant sequence tampering impossible.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_rows int;
begin
  update public.document_sequences
  set next_value = next_value + 999
  where tenant_id = '00000000-0000-0000-0000-000000000102';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'cross_tenant_docseq failed: updated % rows', v_rows;
  end if;
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: authenticated cannot execute next_document_number (42501).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  perform public.next_document_number('SI');
  raise exception 'acl_next_docnum_auth failed: execute succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: anon cannot execute next_document_number (42501).
begin;
set local role anon;
do $$
begin
  perform public.next_document_number('SI');
  raise exception 'acl_next_docnum_anon failed: execute succeeded';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: SKU creation via product insert still works.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_sku text;
begin
  insert into public.products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, is_serialized, created_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'SKU-HARD', 'SKU Hard', '00000000-0000-0000-0000-000000000801',
    'asset_rental', 'piece', 1, 0, false,
    '00000000-0000-0000-0000-000000000201'
  )
  returning sku into v_sku;

  if v_sku is null or v_sku not like 'SKU-%' then
    raise exception 'sku_insert failed: got %', v_sku;
  end if;
end $$;
rollback;

-- ACL: unit_events INSERT denied (42501).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  insert into public.unit_events (tenant_id, product_unit_id, event_type)
  values (
    '00000000-0000-0000-0000-000000000101',
    gen_random_uuid(),
    'test'
  );
  raise exception 'acl_unit_events_insert failed';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: unit_events UPDATE denied (42501).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  update public.unit_events set event_type = 'hack' where false;
  raise exception 'acl_unit_events_update failed: unexpected success path';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: unit_events DELETE denied (42501).
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  delete from public.unit_events where false;
  raise exception 'acl_unit_events_delete failed: unexpected success path';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- ACL: unit_events SELECT requires product_units.view.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_count bigint;
begin
  select count(*) into v_count from public.unit_events;
  if v_count <> 0 then
    raise exception 'unit_events_select_no_perm failed: saw % rows', v_count;
  end if;
end $$;
rollback;

-- ACL: authorized unit_events SELECT succeeds for manager with product_units.view.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
  v_event_count bigint;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, is_serialized, created_by
  )
  values (
    v_tenant_a, 'حدث', 'Event', v_group, 'asset_rental',
    'piece', 1, 0, true, v_owner
  )
  returning id into v_product_id;

  perform create_product_units(
    v_product_id, v_wh,
    jsonb_build_array(jsonb_build_object('serial_number', 'EVT-1'))
  );

  update inventory_balances
  set qty_available = 2
  where tenant_id = v_tenant_a and product_id = v_product_id and warehouse_id = v_wh;

  perform reconcile_serialized_stock(
    v_product_id, v_wh, jsonb_build_array('EVT-2'), 'Event visibility test'
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_count bigint;
begin
  select count(*) into v_count
  from public.unit_events
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and event_type = 'reconciled'
    and notes = 'Event visibility test';

  if v_count <> 1 then
    raise exception 'unit_events_select_authorized failed: count=%', v_count;
  end if;
end $$;
rollback;

-- Journal: insert line after posting rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_revenue uuid := '00000000-0000-0000-0000-000000000506';
  v_entry_id uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into journal_entries (
    tenant_id, entry_number, date, source, is_posted
  )
  values (
    v_tenant_a, 'JE-HARD-001', current_date, 'manual', false
  )
  returning id into v_entry_id;

  insert into journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order
  )
  values
    (v_tenant_a, v_entry_id, v_cash, 10, 0, 1),
    (v_tenant_a, v_entry_id, v_revenue, 0, 10, 2);

  update journal_entries
  set is_posted = true, posted_at = now(), posted_by = v_owner
  where id = v_entry_id;

  begin
    insert into journal_lines (
      tenant_id, journal_entry_id, account_id, debit, credit, line_order
    )
    values (v_tenant_a, v_entry_id, v_cash, 5, 0, 3);
    raise exception 'journal_insert_after_post failed';
  exception
    when others then
      if sqlerrm not like '%posted_journal_line_immutable%' then raise; end if;
  end;
end $$;
rollback;

-- Journal: update line under posted entry rejected.
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
    tenant_id, entry_number, date, source, is_posted
  )
  values (
    v_tenant_a, 'JE-HARD-002', current_date, 'manual', false
  )
  returning id into v_entry_id;

  insert into journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order
  )
  values
    (v_tenant_a, v_entry_id, v_cash, 10, 0, 1),
    (v_tenant_a, v_entry_id, v_revenue, 0, 10, 2);

  update journal_entries
  set is_posted = true, posted_at = now(), posted_by = v_owner
  where id = v_entry_id;

  select id into v_line_id from journal_lines where journal_entry_id = v_entry_id limit 1;

  begin
    update journal_lines set debit = 20 where id = v_line_id;
    raise exception 'journal_update_posted_line failed';
  exception
    when others then
      if sqlerrm not like '%posted_journal_line_immutable%' then raise; end if;
  end;
end $$;
rollback;

-- Journal: delete line from posted entry rejected.
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
    tenant_id, entry_number, date, source, is_posted
  )
  values (
    v_tenant_a, 'JE-HARD-003', current_date, 'manual', false
  )
  returning id into v_entry_id;

  insert into journal_lines (
    tenant_id, journal_entry_id, account_id, debit, credit, line_order
  )
  values
    (v_tenant_a, v_entry_id, v_cash, 10, 0, 1),
    (v_tenant_a, v_entry_id, v_revenue, 0, 10, 2);

  update journal_entries
  set is_posted = true, posted_at = now(), posted_by = v_owner
  where id = v_entry_id;

  select id into v_line_id from journal_lines where journal_entry_id = v_entry_id limit 1;

  begin
    delete from journal_lines where id = v_line_id;
    raise exception 'journal_delete_posted_line failed';
  exception
    when others then
      if sqlerrm not like '%posted_journal_line_immutable%' then raise; end if;
  end;
end $$;
rollback;

-- Journal: move line out of posted entry rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_revenue uuid := '00000000-0000-0000-0000-000000000506';
  v_posted_id uuid;
  v_open_id uuid;
  v_line_id uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'JE-HARD-004P', current_date, 'manual', false)
  returning id into v_posted_id;

  insert into journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'JE-HARD-004O', current_date, 'manual', false)
  returning id into v_open_id;

  insert into journal_lines (tenant_id, journal_entry_id, account_id, debit, credit, line_order)
  values
    (v_tenant_a, v_posted_id, v_cash, 10, 0, 1),
    (v_tenant_a, v_posted_id, v_revenue, 0, 10, 2);

  update journal_entries
  set is_posted = true, posted_at = now(), posted_by = v_owner
  where id = v_posted_id;

  select id into v_line_id from journal_lines where journal_entry_id = v_posted_id and line_order = 1;

  begin
    update journal_lines set journal_entry_id = v_open_id where id = v_line_id;
    raise exception 'journal_move_out_posted failed';
  exception
    when others then
      if sqlerrm not like '%posted_journal_line_immutable%' then raise; end if;
  end;
end $$;
rollback;

-- Journal: move line into posted entry rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_revenue uuid := '00000000-0000-0000-0000-000000000506';
  v_posted_id uuid;
  v_open_id uuid;
  v_line_id uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'JE-HARD-005P', current_date, 'manual', false)
  returning id into v_posted_id;

  insert into journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'JE-HARD-005O', current_date, 'manual', false)
  returning id into v_open_id;

  insert into journal_lines (tenant_id, journal_entry_id, account_id, debit, credit, line_order)
  values
    (v_tenant_a, v_posted_id, v_cash, 10, 0, 1),
    (v_tenant_a, v_posted_id, v_revenue, 0, 10, 2),
    (v_tenant_a, v_open_id, v_cash, 5, 0, 1);

  update journal_entries
  set is_posted = true, posted_at = now(), posted_by = v_owner
  where id = v_posted_id;

  select id into v_line_id from journal_lines where journal_entry_id = v_open_id;

  begin
    update journal_lines set journal_entry_id = v_posted_id where id = v_line_id;
    raise exception 'journal_move_into_posted failed';
  exception
    when others then
      if sqlerrm not like '%posted_journal_line_immutable%' then raise; end if;
  end;
end $$;
rollback;

-- Journal: direct INSERT with is_posted=true rejected.
begin;
do $$
begin
  insert into journal_entries (
    tenant_id, entry_number, date, source, is_posted, posted_at, posted_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'JE-HARD-006', current_date, 'manual', true, now(),
    '00000000-0000-0000-0000-000000000201'
  );
  raise exception 'journal_direct_posted_insert failed';
exception
  when others then
    if sqlerrm not like '%journal_entry_cannot_be_created_posted%' then raise; end if;
end $$;
rollback;

-- Journal: post with one line rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_entry_id uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'JE-HARD-007', current_date, 'manual', false)
  returning id into v_entry_id;

  insert into journal_lines (tenant_id, journal_entry_id, account_id, debit, credit, line_order)
  values (v_tenant_a, v_entry_id, v_cash, 10, 0, 1);

  begin
    update journal_entries
    set is_posted = true, posted_at = now(), posted_by = v_owner
    where id = v_entry_id;
    raise exception 'journal_single_line_post failed';
  exception
    when others then
      if sqlerrm not like '%journal_entry_requires_two_lines%' then raise; end if;
  end;
end $$;
rollback;

-- Journal: post with zero lines rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_entry_id uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'JE-HARD-007Z', current_date, 'manual', false)
  returning id into v_entry_id;

  begin
    update journal_entries
    set is_posted = true, posted_at = now(), posted_by = v_owner
    where id = v_entry_id;
    raise exception 'journal_zero_line_post failed';
  exception
    when others then
      if sqlerrm not like '%journal_entry_requires_two_lines%' then raise; end if;
  end;
end $$;
rollback;

-- Journal: post unbalanced entry rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_revenue uuid := '00000000-0000-0000-0000-000000000506';
  v_entry_id uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  insert into journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'JE-HARD-008', current_date, 'manual', false)
  returning id into v_entry_id;

  insert into journal_lines (tenant_id, journal_entry_id, account_id, debit, credit, line_order)
  values
    (v_tenant_a, v_entry_id, v_cash, 10, 0, 1),
    (v_tenant_a, v_entry_id, v_revenue, 0, 5, 2);

  begin
    update journal_entries
    set is_posted = true, posted_at = now(), posted_by = v_owner
    where id = v_entry_id;
    raise exception 'journal_unbalanced_post failed';
  exception
    when others then
      if sqlerrm not like '%journal_entry_not_balanced%' then raise; end if;
  end;
end $$;
rollback;

-- Journal: valid balanced post succeeds.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_revenue uuid := '00000000-0000-0000-0000-000000000506';
  v_entry_id uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_posted boolean;
begin
  insert into journal_entries (tenant_id, entry_number, date, source, is_posted)
  values (v_tenant_a, 'JE-HARD-009', current_date, 'manual', false)
  returning id into v_entry_id;

  insert into journal_lines (tenant_id, journal_entry_id, account_id, debit, credit, line_order)
  values
    (v_tenant_a, v_entry_id, v_cash, 10, 0, 1),
    (v_tenant_a, v_entry_id, v_revenue, 0, 10, 2);

  update journal_entries
  set is_posted = true, posted_at = now(), posted_by = v_owner
  where id = v_entry_id;

  select is_posted into v_posted from journal_entries where id = v_entry_id;
  if not coalesce(v_posted, false) then
    raise exception 'journal_valid_post failed: not posted';
  end if;
end $$;
rollback;

-- Audit: tenant_settings update succeeds and writes audit row.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_before int;
  v_after int;
  v_entity_id uuid;
  v_before_json jsonb;
  v_after_json jsonb;
  v_old_books date;
  v_old_mode text;
  v_old_prefix text;
  v_old_padding int;
  v_new_books date := current_date + 7;
  v_new_mode text := 'manual';
  v_new_prefix text := 'SN-HARD';
  v_new_padding int;
begin
  select
    books_locked_through,
    serial_number_mode::text,
    serial_number_prefix,
    serial_number_padding
  into v_old_books, v_old_mode, v_old_prefix, v_old_padding
  from tenant_settings
  where tenant_id = v_tenant_a;

  v_new_padding := coalesce(v_old_padding, 6) + 1;

  select count(*) into v_before
  from audit_log
  where tenant_id = v_tenant_a and entity_type = 'tenant_settings';

  update tenant_settings
  set
    books_locked_through = v_new_books,
    serial_number_mode = v_new_mode::serial_number_mode,
    serial_number_prefix = v_new_prefix,
    serial_number_padding = v_new_padding
  where tenant_id = v_tenant_a;

  select count(*) into v_after
  from audit_log
  where tenant_id = v_tenant_a and entity_type = 'tenant_settings';

  if v_after <= v_before then
    raise exception 'audit_tenant_settings failed: delta=%', v_after - v_before;
  end if;

  select entity_id, before_json, after_json
  into v_entity_id, v_before_json, v_after_json
  from audit_log
  where tenant_id = v_tenant_a
    and entity_type = 'tenant_settings'
  order by at desc
  limit 1;

  if v_entity_id <> v_tenant_a then
    raise exception 'audit_tenant_settings entity_id wrong: %', v_entity_id;
  end if;

  if v_before_json ->> 'books_locked_through' is distinct from v_old_books::text
    or v_before_json ->> 'serial_number_mode' is distinct from v_old_mode
    or v_before_json ->> 'serial_number_prefix' is distinct from v_old_prefix
    or (v_before_json ->> 'serial_number_padding')::int is distinct from v_old_padding
  then
    raise exception 'audit_tenant_settings before_json wrong: %', v_before_json;
  end if;

  if v_after_json ->> 'books_locked_through' is distinct from v_new_books::text
    or v_after_json ->> 'serial_number_mode' is distinct from v_new_mode
    or v_after_json ->> 'serial_number_prefix' is distinct from v_new_prefix
    or (v_after_json ->> 'serial_number_padding')::int is distinct from v_new_padding
  then
    raise exception 'audit_tenant_settings after_json wrong: %', v_after_json;
  end if;
end $$;
rollback;

-- Audit: product_units INSERT audited.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_unit_id uuid := gen_random_uuid();
  v_audit_count int;
begin
  insert into product_units (
    id, tenant_id, product_id, serial_number, status, current_warehouse_id, acquired_at
  )
  values (v_unit_id, v_tenant_a, v_product, 'AUDIT-INS-1', 'available_new', v_wh, current_date);

  select count(*) into v_audit_count
  from audit_log
  where tenant_id = v_tenant_a
    and entity_type = 'product_units'
    and entity_id = v_unit_id
    and action = 'insert';

  if v_audit_count <> 1 then
    raise exception 'audit_pu_insert failed: count=%', v_audit_count;
  end if;
end $$;
rollback;

-- Audit: product_units status UPDATE audited.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_unit_id uuid := gen_random_uuid();
  v_audit_count int;
begin
  insert into product_units (
    id, tenant_id, product_id, serial_number, status, current_warehouse_id, acquired_at
  )
  values (v_unit_id, v_tenant_a, v_product, 'AUDIT-UPD-1', 'available_new', v_wh, current_date);

  update product_units set status = 'rented' where id = v_unit_id;

  select count(*) into v_audit_count
  from audit_log
  where tenant_id = v_tenant_a
    and entity_type = 'product_units'
    and entity_id = v_unit_id
    and action = 'update'
    and before_json ->> 'status' = 'available_new'
    and after_json ->> 'status' = 'rented';

  if v_audit_count <> 1 then
    raise exception 'audit_pu_status_update failed: count=%', v_audit_count;
  end if;
end $$;
rollback;

-- Audit: product_units DELETE audited.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_unit_id uuid := gen_random_uuid();
  v_audit_count int;
begin
  insert into product_units (
    id, tenant_id, product_id, serial_number, status, current_warehouse_id, acquired_at
  )
  values (v_unit_id, v_tenant_a, v_product, 'AUDIT-DEL-1', 'available_new', v_wh, current_date);

  delete from product_units where id = v_unit_id;

  select count(*) into v_audit_count
  from audit_log
  where tenant_id = v_tenant_a
    and entity_type = 'product_units'
    and entity_id = v_unit_id
    and action = 'delete'
    and before_json is not null;

  if v_audit_count <> 1 then
    raise exception 'audit_pu_delete failed: count=%', v_audit_count;
  end if;
end $$;
rollback;

-- Reconcile auth: view-only denied on preview.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  perform 1 from preview_serialized_stock_reconciliation(
    '00000000-0000-0000-0000-000000000901',
    '00000000-0000-0000-0000-000000000701'
  );
  raise exception 'reconcile_preview_view_only failed';
exception
  when others then
    if sqlerrm not like '%permission_denied%' then raise; end if;
end $$;
rollback;

-- Reconcile auth: view-only denied on reconcile.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  perform reconcile_serialized_stock(
    '00000000-0000-0000-0000-000000000901',
    '00000000-0000-0000-0000-000000000701',
    '[]'::jsonb,
    'test'
  );
  raise exception 'reconcile_rpc_view_only failed';
exception
  when others then
    if sqlerrm not like '%permission_denied%' then raise; end if;
end $$;
rollback;

-- Reconcile: fractional qty rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  update inventory_balances
  set qty_available = 3.5
  where tenant_id = v_tenant_a and product_id = v_product and warehouse_id = v_wh;

  if not found then
    insert into inventory_balances (tenant_id, product_id, warehouse_id, qty_available)
    values (v_tenant_a, v_product, v_wh, 3.5);
  end if;

  begin
    perform 1 from preview_serialized_stock_reconciliation(v_product, v_wh);
    raise exception 'reconcile_fractional_preview failed';
  exception
    when others then
      if sqlerrm not like '%serialized_qty_must_be_whole%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product, v_wh, jsonb_build_array('FRAC-1'), 'Fractional reconcile'
    );
    raise exception 'reconcile_fractional_rpc failed';
  exception
    when others then
      if sqlerrm not like '%serialized_qty_must_be_whole%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: negative qty rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  update inventory_balances
  set qty_available = -1
  where tenant_id = v_tenant_a and product_id = v_product and warehouse_id = v_wh;

  if not found then
    insert into inventory_balances (tenant_id, product_id, warehouse_id, qty_available)
    values (v_tenant_a, v_product, v_wh, -1);
  end if;

  begin
    perform 1 from preview_serialized_stock_reconciliation(v_product, v_wh);
    raise exception 'reconcile_negative_preview failed';
  exception
    when others then
      if sqlerrm not like '%serialized_qty_cannot_be_negative%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product, v_wh, jsonb_build_array('NEG-1'), 'Negative reconcile'
    );
    raise exception 'reconcile_negative_rpc failed';
  exception
    when others then
      if sqlerrm not like '%serialized_qty_cannot_be_negative%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: non-available bucket rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into inventory_balances (
    tenant_id, product_id, warehouse_id, qty_available, qty_rented
  )
  values (v_tenant_a, v_product, v_wh, 2, 1)
  on conflict (warehouse_id, product_id)
  do update set qty_available = 2, qty_rented = 1;

  begin
    perform 1 from preview_serialized_stock_reconciliation(v_product, v_wh);
    raise exception 'reconcile_bucket_preview failed';
  exception
    when others then
      if sqlerrm not like '%serialized_reconciliation_non_available_buckets%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product, v_wh, jsonb_build_array('BKT-1'), 'Bucket reconcile'
    );
    raise exception 'reconcile_bucket_rpc failed';
  exception
    when others then
      if sqlerrm not like '%serialized_reconciliation_non_available_buckets%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: unit count exceeds balance.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, is_serialized, created_by
  )
  values (
    v_tenant_a, 'زيادة', 'Excess', v_group, 'asset_rental',
    'piece', 1, 0, true, v_owner
  )
  returning id into v_product_id;

  perform create_product_units(
    v_product_id, v_wh,
    jsonb_build_array(
      jsonb_build_object('serial_number', 'EX-1'),
      jsonb_build_object('serial_number', 'EX-2'),
      jsonb_build_object('serial_number', 'EX-3')
    )
  );

  update inventory_balances
  set qty_available = 1
  where tenant_id = v_tenant_a and product_id = v_product_id and warehouse_id = v_wh;

  begin
    perform 1 from preview_serialized_stock_reconciliation(v_product_id, v_wh);
    raise exception 'reconcile_exceeds_preview failed';
  exception
    when others then
      if sqlerrm not like '%serialized_unit_count_exceeds_balance%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product_id, v_wh, jsonb_build_array('EX-HACK'), 'Exceeds reconcile'
    );
    raise exception 'reconcile_exceeds_rpc failed';
  exception
    when others then
      if sqlerrm not like '%serialized_unit_count_exceeds_balance%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: inactive product rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, is_serialized, is_active, created_by
  )
  values (
    v_tenant_a, 'غ غ', 'Inactive', v_group, 'asset_rental',
    'piece', 1, 0, true, false, v_owner
  )
  returning id into v_product_id;

  begin
    perform preview_serialized_stock_reconciliation(v_product_id, v_wh);
    raise exception 'reconcile_inactive_product failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product_id, v_wh, '[]'::jsonb, 'Inactive product test'
    );
    raise exception 'reconcile_inactive_product_rpc failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: non-serialized product rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, is_serialized, created_by
  )
  values (
    v_tenant_a, 'غير ت', 'NonSerial', v_group, 'asset_rental',
    'piece', 1, 0, false, v_owner
  )
  returning id into v_product_id;

  begin
    perform preview_serialized_stock_reconciliation(v_product_id, v_wh);
    raise exception 'reconcile_non_serialized failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product_id, v_wh, '[]'::jsonb, 'Non-serialized product test'
    );
    raise exception 'reconcile_non_serialized_rpc failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: cross-tenant product rejected.
begin;
do $$
declare
  v_product_b uuid := '00000000-0000-0000-0000-000000000902';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  begin
    perform preview_serialized_stock_reconciliation(v_product_b, v_wh);
    raise exception 'reconcile_cross_tenant_product failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product_b, v_wh, '[]'::jsonb, 'Cross-tenant product test'
    );
    raise exception 'reconcile_cross_tenant_product_rpc failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: inactive warehouse rejected.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  update warehouses set is_active = false where id = v_wh and tenant_id = v_tenant_a;

  begin
    perform preview_serialized_stock_reconciliation(v_product, v_wh);
    raise exception 'reconcile_inactive_warehouse failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product, v_wh, '[]'::jsonb, 'Inactive warehouse test'
    );
    raise exception 'reconcile_inactive_warehouse_rpc failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: real cross-tenant warehouse rejected.
begin;
do $$
declare
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';
  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse_b uuid := '00000000-0000-0000-0000-000000000703';
  v_owner_a uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform set_config('request.jwt.claim.sub', v_owner_a::text, true);

  insert into warehouses (
    id, tenant_id, name_ar, name_en, type, is_active
  )
  values (
    v_warehouse_b, v_tenant_b, 'Tenant B warehouse',
    'Tenant B warehouse', 'main', true
  );

  begin
    perform preview_serialized_stock_reconciliation(v_product_a, v_warehouse_b);
    raise exception 'reconcile_cross_tenant_warehouse failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product_a, v_warehouse_b, '[]'::jsonb, 'Cross-tenant warehouse test'
    );
    raise exception 'reconcile_cross_tenant_warehouse_rpc failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: unknown warehouse rejected.
begin;
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_fake_wh uuid := '00000000-0000-0000-0000-000000009999';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  begin
    perform preview_serialized_stock_reconciliation(v_product, v_fake_wh);
    raise exception 'reconcile_unknown_warehouse failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;

  begin
    perform reconcile_serialized_stock(
      v_product, v_fake_wh, '[]'::jsonb, 'Unknown warehouse test'
    );
    raise exception 'reconcile_unknown_warehouse_rpc failed';
  exception
    when others then
      if sqlerrm not like '%validation_failed%' then raise; end if;
  end;
end $$;
rollback;

-- Reconcile: exact match preview difference=0; reconcile not needed.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
  v_diff bigint;
  v_units_before bigint;
  v_events_before bigint;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, is_serialized, created_by
  )
  values (
    v_tenant_a, 'تطابق', 'Exact', v_group, 'asset_rental',
    'piece', 1, 0, true, v_owner
  )
  returning id into v_product_id;

  perform create_product_units(
    v_product_id, v_wh,
    jsonb_build_array(jsonb_build_object('serial_number', 'EXACT-1'))
  );

  update inventory_balances
  set qty_available = 1
  where tenant_id = v_tenant_a and product_id = v_product_id and warehouse_id = v_wh;

  select difference into v_diff
  from preview_serialized_stock_reconciliation(v_product_id, v_wh);

  if v_diff <> 0 then
    raise exception 'reconcile_exact_preview failed: diff=%', v_diff;
  end if;

  select count(*) into v_units_before from product_units where product_id = v_product_id;
  select count(*) into v_events_before from unit_events where tenant_id = v_tenant_a;

  begin
    perform reconcile_serialized_stock(
      v_product_id, v_wh, '[]'::jsonb, 'Exact match test'
    );
    raise exception 'reconcile_exact_rpc failed: succeeded';
  exception
    when others then
      if sqlerrm not like '%serialized_reconciliation_not_needed%' then raise; end if;
  end;

  if (select count(*) from product_units where product_id = v_product_id) <> v_units_before then
    raise exception 'reconcile_exact created units';
  end if;

  if (select count(*) from unit_events where tenant_id = v_tenant_a) <> v_events_before then
    raise exception 'reconcile_exact created events';
  end if;
end $$;
rollback;

-- Reconcile: valid gap creates units without balance/movement change.
begin;
do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_group uuid := '00000000-0000-0000-0000-000000000801';
  v_wh uuid := '00000000-0000-0000-0000-000000000701';
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
  v_product_id uuid;
  v_bal_before numeric;
  v_bal_after numeric;
  v_mov_before bigint;
  v_mov_after bigint;
  v_meta jsonb;
  v_created_by uuid;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into products (
    tenant_id, name_ar, name_en, group_id, product_type,
    unit_primary, conversion_factor, sale_price, is_serialized, created_by
  )
  values (
    v_tenant_a, 'فجوة', 'Gap', v_group, 'asset_rental',
    'piece', 1, 0, true, v_owner
  )
  returning id into v_product_id;

  perform create_product_units(
    v_product_id, v_wh,
    jsonb_build_array(jsonb_build_object('serial_number', 'GAP-1'))
  );

  update inventory_balances
  set qty_available = 3
  where tenant_id = v_tenant_a and product_id = v_product_id and warehouse_id = v_wh;

  select qty_available into v_bal_before
  from inventory_balances
  where tenant_id = v_tenant_a and product_id = v_product_id and warehouse_id = v_wh;

  select count(*) into v_mov_before from inventory_movements where tenant_id = v_tenant_a;

  perform reconcile_serialized_stock(
    v_product_id,
    v_wh,
    jsonb_build_array('GAP-2', 'GAP-3'),
    'Gap fill test'
  );

  select qty_available into v_bal_after
  from inventory_balances
  where tenant_id = v_tenant_a and product_id = v_product_id and warehouse_id = v_wh;

  select count(*) into v_mov_after from inventory_movements where tenant_id = v_tenant_a;

  if v_bal_before is distinct from v_bal_after then
    raise exception 'reconcile_gap balance changed';
  end if;

  if v_mov_before <> v_mov_after then
    raise exception 'reconcile_gap movements changed';
  end if;

  select metadata_json, created_by
  into v_meta, v_created_by
  from unit_events
  where tenant_id = v_tenant_a
    and event_type = 'reconciled'
    and metadata_json ->> 'serial_number' = 'GAP-2'
  limit 1;

  if v_created_by is distinct from v_owner then
    raise exception 'reconcile_gap created_by wrong: %', v_created_by;
  end if;

  if (v_meta ->> 'qty_available')::numeric is distinct from 3::numeric then
    raise exception 'reconcile_gap qty_available wrong: %', v_meta ->> 'qty_available';
  end if;

  if v_meta ->> 'reconciliation_reason' is distinct from 'Gap fill test'
    or v_meta ->> 'physical_count_before' is distinct from '1'
    or v_meta ->> 'physical_count_after' is distinct from '3'
    or v_meta ->> 'difference' is distinct from '2'
  then
    raise exception 'reconcile_gap metadata wrong: %', v_meta;
  end if;
end $$;
rollback;

-- Metadata: confirmed invoice without confirmed_by rejected.
begin;
do $$
declare
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"عميل رفض","phone_primary":"+96550000992","create_account":true}'::jsonb
    );
  end if;

  begin
    insert into invoices (
      tenant_id, invoice_number, type, status, customer_id, date,
      subtotal, total, confirmed_at
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      'SI-BAD-001', 'sales', 'confirmed', v_customer, current_date,
      0, 0, now()
    );
    raise exception 'meta_invoice_no_by failed';
  exception
    when check_violation then null;
  end;
end $$;
rollback;

-- Metadata: valid confirmed invoice succeeds.
begin;
do $$
declare
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"عميل تأكيد","phone_primary":"+96550000994","create_account":true}'::jsonb
    );
  end if;

  insert into invoices (
    tenant_id, invoice_number, type, status, customer_id, date,
    subtotal, total, confirmed_at, confirmed_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'SI-GOOD-001', 'sales', 'confirmed', v_customer, current_date,
    0, 0, now(), '00000000-0000-0000-0000-000000000201'
  );
end $$;
rollback;

-- Metadata: valid cancelled invoice succeeds.
begin;
do $$
declare
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"عميل إلغاء","phone_primary":"+96550000993","create_account":true}'::jsonb
    );
  end if;

  insert into invoices (
    tenant_id, invoice_number, type, status, customer_id, date,
    subtotal, total, cancelled_at, cancelled_by, cancellation_reason
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'SI-CAN-001', 'sales', 'cancelled', v_customer, current_date,
    0, 0, now(), '00000000-0000-0000-0000-000000000201', 'Test cancel'
  );
end $$;
rollback;

-- Metadata: confirmed voucher without metadata rejected.
begin;
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"عميل سند","phone_primary":"+96550000991","create_account":true}'::jsonb
    );
  end if;

  begin
    insert into vouchers (
      tenant_id, voucher_number, type, date, amount, payment_method,
      customer_id, account_id, cash_account_id, status
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      'RV-BAD-001', 'receipt', current_date, 1, 'cash',
      v_customer, v_cash, v_cash, 'confirmed'
    );
    raise exception 'meta_voucher_no_confirm failed';
  exception
    when check_violation then null;
  end;
end $$;
rollback;

-- Metadata: valid confirmed voucher succeeds.
begin;
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"عميل سند2","phone_primary":"+96550000990","create_account":true}'::jsonb
    );
  end if;

  insert into vouchers (
    tenant_id, voucher_number, type, date, amount, payment_method,
    customer_id, account_id, cash_account_id, status,
    confirmed_at, confirmed_by
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'RV-GOOD-001', 'receipt', current_date, 1, 'cash',
    v_customer, v_cash, v_cash, 'confirmed',
    now(), '00000000-0000-0000-0000-000000000201'
  );
end $$;
rollback;

-- Metadata: valid cancelled voucher succeeds.
begin;
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"عميل سند3","phone_primary":"+96550000989","create_account":true}'::jsonb
    );
  end if;

  insert into vouchers (
    tenant_id, voucher_number, type, date, amount, payment_method,
    customer_id, account_id, cash_account_id, status,
    cancelled_at, cancelled_by, cancellation_reason
  )
  values (
    '00000000-0000-0000-0000-000000000101',
    'RV-CAN-001', 'receipt', current_date, 1, 'cash',
    v_customer, v_cash, v_cash, 'cancelled',
    now(), '00000000-0000-0000-0000-000000000201', 'Test cancel'
  );
end $$;
rollback;

-- Metadata: cancelled invoice missing cancelled_by rejected.
begin;
do $$
declare
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"عميل إلغاء2","phone_primary":"+96550000988","create_account":true}'::jsonb
    );
  end if;

  begin
    insert into invoices (
      tenant_id, invoice_number, type, status, customer_id, date,
      subtotal, total, cancelled_at, cancellation_reason
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      'SI-BAD-CAN-001', 'sales', 'cancelled', v_customer, current_date,
      0, 0, now(), 'Missing actor'
    );
    raise exception 'meta_invoice_cancel_no_by failed';
  exception
    when check_violation then null;
  end;
end $$;
rollback;

-- Metadata: cancelled invoice with blank reason rejected.
begin;
do $$
declare
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"عميل إلغاء3","phone_primary":"+96550000987","create_account":true}'::jsonb
    );
  end if;

  begin
    insert into invoices (
      tenant_id, invoice_number, type, status, customer_id, date,
      subtotal, total, cancelled_at, cancelled_by, cancellation_reason
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      'SI-BAD-CAN-002', 'sales', 'cancelled', v_customer, current_date,
      0, 0, now(), v_owner, '   '
    );
    raise exception 'meta_invoice_cancel_blank_reason failed';
  exception
    when check_violation then null;
  end;
end $$;
rollback;

-- Metadata: cancelled voucher missing cancelled_by rejected.
begin;
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"سند إلغاء","phone_primary":"+96550000986","create_account":true}'::jsonb
    );
  end if;

  begin
    insert into vouchers (
      tenant_id, voucher_number, type, date, amount, payment_method,
      customer_id, account_id, cash_account_id, status,
      cancelled_at, cancellation_reason
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      'RV-BAD-CAN-001', 'receipt', current_date, 1, 'cash',
      v_customer, v_cash, v_cash, 'cancelled',
      now(), 'Missing actor'
    );
    raise exception 'meta_voucher_cancel_no_by failed';
  exception
    when check_violation then null;
  end;
end $$;
rollback;

-- Metadata: cancelled voucher with blank reason rejected.
begin;
do $$
declare
  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_customer uuid;
  v_owner uuid := '00000000-0000-0000-0000-000000000201';
begin
  select id into v_customer from customers
  where tenant_id = '00000000-0000-0000-0000-000000000101' limit 1;

  if v_customer is null then
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    v_customer := create_customer(
      '{"name_ar":"سند إلغاء2","phone_primary":"+96550000985","create_account":true}'::jsonb
    );
  end if;

  begin
    insert into vouchers (
      tenant_id, voucher_number, type, date, amount, payment_method,
      customer_id, account_id, cash_account_id, status,
      cancelled_at, cancelled_by, cancellation_reason
    )
    values (
      '00000000-0000-0000-0000-000000000101',
      'RV-BAD-CAN-002', 'receipt', current_date, 1, 'cash',
      v_customer, v_cash, v_cash, 'cancelled',
      now(), v_owner, ''
    );
    raise exception 'meta_voucher_cancel_blank_reason failed';
  exception
    when check_violation then null;
  end;
end $$;
rollback;

-- Scan: product-only resolves product barcode.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
declare
  v_result jsonb;
begin
  v_result := resolve_scan_code('628000000001');
  if v_result ->> 'matched_by' is distinct from 'product_barcode' then
    raise exception 'scan_product_only failed: %', v_result;
  end if;
end $$;
rollback;

-- Scan: product-only cannot resolve unit barcode (scan_not_found).
begin;
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform create_product_units(
    v_product,
    v_warehouse,
    jsonb_build_array(jsonb_build_object(
      'serial_number', 'HARD-SCAN-1',
      'barcode', 'HARD-UNIT-BC'
    ))
  );
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  perform resolve_scan_code('HARD-UNIT-BC');
  raise exception 'scan_product_only_unit failed: resolved unit';
exception
  when others then
    if sqlerrm not like '%scan_not_found%' then raise; end if;
end $$;
rollback;

-- Scan: unit-only user resolves unit barcode and serial.
begin;
do $$
declare
  v_product uuid := '00000000-0000-0000-0000-000000000901';
  v_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_tu uuid;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  perform create_product_units(
    v_product,
    v_warehouse,
    jsonb_build_array(jsonb_build_object(
      'serial_number', 'HARD-SERIAL-1',
      'barcode', 'HARD-UNIT-BC2'
    ))
  );

  select id into v_tu from tenant_users
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and user_id = '00000000-0000-0000-0000-000000000202';

  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (
    '00000000-0000-0000-0000-000000000101',
    v_tu,
    'product_units.view',
    '00000000-0000-0000-0000-000000000201'
  )
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
declare
  v_result jsonb;
begin
  v_result := resolve_scan_code('HARD-UNIT-BC2');
  if v_result ->> 'matched_by' is distinct from 'unit_barcode' then
    raise exception 'scan_unit_only_barcode failed: %', v_result;
  end if;

  v_result := resolve_scan_code('hard-serial-1');
  if v_result ->> 'matched_by' is distinct from 'serial_number' then
    raise exception 'scan_unit_only_serial failed: %', v_result;
  end if;
end $$;
rollback;

-- Scan: unit-only cannot resolve product barcode (scan_not_found).
begin;
do $$
declare
  v_tu uuid;
begin
  select id into v_tu from tenant_users
  where tenant_id = '00000000-0000-0000-0000-000000000101'
    and user_id = '00000000-0000-0000-0000-000000000202';

  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values (
    '00000000-0000-0000-0000-000000000101',
    v_tu,
    'product_units.view',
    '00000000-0000-0000-0000-000000000201'
  )
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
begin
  perform resolve_scan_code('628000000001');
  raise exception 'scan_unit_only_product failed';
exception
  when others then
    if sqlerrm not like '%scan_not_found%' then raise; end if;
end $$;
rollback;

-- Scan: neither permission -> permission_denied.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
do $$
begin
  perform resolve_scan_code('628000000001');
  raise exception 'scan_no_perm failed';
exception
  when others then
    if sqlerrm not like '%permission_denied%' then raise; end if;
end $$;
rollback;

-- Scan: cross-tenant isolation -> scan_not_found.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000204';
do $$
begin
  perform resolve_scan_code('628000000001');
  raise exception 'scan_cross_tenant failed';
exception
  when others then
    if sqlerrm not like '%scan_not_found%' then raise; end if;
end $$;
rollback;

-- Internal SKU via next_document_number still works for postgres.
begin;
do $$
declare
  v_si text;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
  v_si := public.next_document_number('SI');
  if v_si is null or v_si = '' then
    raise exception 'internal_next_docnum failed';
  end if;
end $$;
rollback;

\echo 'phase_5_m1_m2_hardening.sql: all cases passed'
