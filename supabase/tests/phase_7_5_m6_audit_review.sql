\set ON_ERROR_STOP on

-- Phase 7.5 M6: ACL, redaction, source permission, tenant isolation,
-- filter, cursor paging, and protected-column checks.

do $$
begin
  if has_function_privilege(
    'anon',
    'public.list_phase_7_5_audit_log(text,text,uuid,date,date,text,integer,timestamptz,bigint)',
    'EXECUTE'
  ) then
    raise exception 'm6 fail: anon audit RPC execute';
  end if;
  if has_function_privilege(
    'authenticated',
    'public.phase_7_5_m6_safe_audit_snapshot(jsonb,boolean)',
    'EXECUTE'
  ) then
    raise exception 'm6 fail: internal audit helper leaked';
  end if;
  if has_column_privilege(
    'authenticated', 'public.audit_log', 'before_json', 'SELECT'
  ) or has_column_privilege(
    'authenticated', 'public.audit_log', 'after_json', 'SELECT'
  ) or has_column_privilege(
    'authenticated', 'public.audit_log', 'ip_address', 'SELECT'
  ) or has_column_privilege(
    'authenticated', 'public.audit_log', 'reason', 'SELECT'
  ) then
    raise exception 'm6 fail: protected audit column grant leaked';
  end if;
end $$;

begin;

insert into public.audit_log (
  tenant_id, at, actor_id, actor_account_type, action,
  entity_type, entity_id, before_json, after_json, reason,
  ip_address, user_agent
)
values
  (
    '00000000-0000-0000-0000-000000000101',
    '2026-08-09 08:00:00+00',
    '00000000-0000-0000-0000-000000000201',
    'manager', 'UPDATE', 'customers',
    '00000000-0000-0000-0000-000000000701',
    '{"name_en":"Before name","status":"active","phone_primary":"M6-SECRET-PHONE"}',
    '{"name_en":"After name","status":"inactive","phone_primary":"M6-SECRET-PHONE-2"}',
    'M6 safe customer update', '10.0.0.1', 'M6-SECRET-AGENT'
  ),
  (
    '00000000-0000-0000-0000-000000000101',
    '2026-08-09 07:00:00+00',
    null, null, 'insert', 'journal_entries',
    '00000000-0000-0000-0000-000000000702',
    null,
    '{"entry_number":"M6-JE-001","status":"posted","description_en":"M6-SECRET-DESCRIPTION"}',
    'M6 system journal', null, null
  ),
  (
    '00000000-0000-0000-0000-000000000101',
    '2026-08-09 06:00:00+00',
    '00000000-0000-0000-0000-000000000201',
    'manager', 'update', 'chart_of_accounts',
    '00000000-0000-0000-0000-000000000704',
    '{"code":"M6-COA-001","name_en":"Before account","is_active":true}',
    '{"code":"M6-COA-001","name_en":"After account","is_active":true}',
    'M6 chart account update', null, null
  ),
  (
    '00000000-0000-0000-0000-000000000102',
    '2026-08-09 09:00:00+00',
    '00000000-0000-0000-0000-000000000204',
    'manager', 'update', 'customers',
    '00000000-0000-0000-0000-000000000703',
    '{"name_en":"Other tenant before"}',
    '{"name_en":"Other tenant after"}',
    'M6-OTHER-TENANT', null, null
  );

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';

do $$
begin
  perform public.list_phase_7_5_audit_log(
    null, null, null, '2026-08-09', '2026-08-09', null, 50, null, null
  );
  raise exception 'm6 fail: zero-permission audit call succeeded';
exception
  when others then
    if sqlerrm not like '%permission_denied%' then raise; end if;
end $$;

reset role;
insert into public.user_permissions (
  tenant_id, tenant_user_id, permission_id, granted_by
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000302',
  'audit_log.view',
  '00000000-0000-0000-0000-000000000201'
)
on conflict (tenant_user_id, permission_id) do nothing;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';

do $$
declare
  v_result jsonb;
  v_item jsonb;
begin
  v_result := public.list_phase_7_5_audit_log(
    'parties', 'update', null, '2026-08-09', '2026-08-09',
    null, 50, null, null
  );
  if jsonb_array_length(v_result -> 'items') <> 1 then
    raise exception 'm6 fail: audit-only filtered result %', v_result;
  end if;
  v_item := v_result #> '{items,0}';
  if (v_item ->> 'source_visible')::boolean
     or v_item ? 'before_summary'
     or v_item ? 'after_summary'
     or v_item ? 'source_route'
     or v_item ? 'reason'
     or v_item -> 'changed_fields' <> '[]'::jsonb then
    raise exception 'm6 fail: audit-only source redaction %', v_item;
  end if;
  if v_result::text like '%M6-SECRET%'
     or v_result::text like '%M6-OTHER-TENANT%' then
    raise exception 'm6 fail: protected/tenant data leak %', v_result;
  end if;
  v_result := public.list_phase_7_5_audit_log(
    'parties', 'update', null, '2026-08-09', '2026-08-09',
    'safe customer', 50, null, null
  );
  if jsonb_array_length(v_result -> 'items') <> 0 then
    raise exception 'm6 fail: redacted reason remained searchable %', v_result;
  end if;
end $$;

reset role;
insert into public.user_permissions (
  tenant_id, tenant_user_id, permission_id, granted_by
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000302',
  'customers.view',
  '00000000-0000-0000-0000-000000000201'
)
on conflict (tenant_user_id, permission_id) do nothing;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';

do $$
declare
  v_result jsonb;
  v_item jsonb;
begin
  v_result := public.list_phase_7_5_audit_log(
    'parties', 'update', null, '2026-08-09', '2026-08-09', null, 50, null, null
  );
  v_item := v_result #> '{items,0}';
  if not (v_item ->> 'source_visible')::boolean
     or v_item #>> '{after_summary,name_en}' <> 'After name'
     or v_item ->> 'source_route' <>
       '/customers/00000000-0000-0000-0000-000000000701'
     or v_item ->> 'reason' <> 'M6 safe customer update'
     or not (v_item -> 'changed_fields' @> '["name_en","status"]'::jsonb) then
    raise exception 'm6 fail: source-visible safe projection %', v_item;
  end if;
  if v_result::text like '%M6-SECRET%' then
    raise exception 'm6 fail: protected value entered safe projection %', v_result;
  end if;
end $$;

reset role;
insert into public.user_permissions (
  tenant_id, tenant_user_id, permission_id, granted_by
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000302',
  'chart_of_accounts.view',
  '00000000-0000-0000-0000-000000000201'
)
on conflict (tenant_user_id, permission_id) do nothing;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';

do $$
declare
  v_result jsonb;
  v_item jsonb;
begin
  v_result := public.list_phase_7_5_audit_log(
    'finance', 'update', null, '2026-08-09', '2026-08-09',
    'chart account', 50, null, null
  );
  v_item := v_result #> '{items,0}';
  if jsonb_array_length(v_result -> 'items') <> 1
     or not (v_item ->> 'source_visible')::boolean
     or v_item ->> 'source_route' <> '/accounts'
     or v_item #>> '{after_summary,name_en}' <> 'After account' then
    raise exception 'm6 fail: chart-account source projection %', v_result;
  end if;
end $$;

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';

do $$
declare
  v_first jsonb;
  v_second jsonb;
begin
  v_first := public.list_phase_7_5_audit_log(
    null, null, null, '2026-08-09', '2026-08-09', 'M6', 1, null, null
  );
  if jsonb_array_length(v_first -> 'items') <> 1
     or not (v_first ->> 'has_more')::boolean
     or v_first ->> 'next_before_at' is null
     or v_first ->> 'next_before_id' is null then
    raise exception 'm6 fail: first cursor page %', v_first;
  end if;
  v_second := public.list_phase_7_5_audit_log(
    null, null, null, '2026-08-09', '2026-08-09', 'M6', 1,
    (v_first ->> 'next_before_at')::timestamptz,
    (v_first ->> 'next_before_id')::bigint
  );
  if jsonb_array_length(v_second -> 'items') <> 1
     or v_second #>> '{items,0,id}' = v_first #>> '{items,0,id}'
     or v_second::text like '%M6-OTHER-TENANT%' then
    raise exception 'm6 fail: second cursor page % %', v_first, v_second;
  end if;
end $$;

rollback;

select 'phase_7_5_m6_audit_review: ok' as result;
