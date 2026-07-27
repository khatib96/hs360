\set ON_ERROR_STOP on

-- Phase 7.5 M4: permission-shaped global search and recipient-scoped
-- in-app notification center.

do $$
begin
  if has_function_privilege(
    'anon',
    'public.global_navigation_search(text, integer)',
    'EXECUTE'
  ) then
    raise exception 'm4 fail: anon search execute';
  end if;
  if has_function_privilege(
    'anon',
    'public.list_my_in_app_notifications(integer, timestamptz)',
    'EXECUTE'
  ) then
    raise exception 'm4 fail: anon notification list execute';
  end if;
  if has_function_privilege(
    'anon',
    'public.set_my_in_app_notification_read(uuid, boolean)',
    'EXECUTE'
  ) then
    raise exception 'm4 fail: anon notification mutation execute';
  end if;
end $$;

begin;

insert into public.user_permissions (
  tenant_id,
  tenant_user_id,
  permission_id,
  granted_by
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000302',
  'notifications.view',
  '00000000-0000-0000-0000-000000000201'
)
on conflict (tenant_user_id, permission_id) do nothing;

insert into public.notifications (
  id,
  tenant_id,
  channel,
  recipient_type,
  recipient_id,
  recipient_address,
  subject,
  body_ar,
  body_en,
  status,
  created_at
)
values
  (
    '75000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000101',
    'in_app',
    'user',
    '00000000-0000-0000-0000-000000000201',
    'owner@test.local',
    'M4 owner notice',
    'إشعار المالك',
    'Owner notice',
    'sent',
    '2026-07-27 10:00:00+00'
  ),
  (
    '75000000-0000-0000-0000-000000000402',
    '00000000-0000-0000-0000-000000000101',
    'in_app',
    'user',
    '00000000-0000-0000-0000-000000000202',
    'zero@test.local',
    'M4 zero notice',
    'إشعار المستخدم',
    'Zero notice',
    'sent',
    '2026-07-27 09:00:00+00'
  );

-- A stale/unsupported source is not returned and cannot leak its existence.
insert into public.notifications (
  id,
  tenant_id,
  channel,
  recipient_type,
  recipient_id,
  recipient_address,
  subject,
  body_ar,
  body_en,
  status,
  related_entity_table,
  related_entity_id,
  created_at
)
values (
  '75000000-0000-0000-0000-000000000403',
  '00000000-0000-0000-0000-000000000101',
  'in_app',
  'user',
  '00000000-0000-0000-0000-000000000201',
  'owner@test.local',
  'M4 stale notice',
  'مصدر قديم',
  'Stale source',
  'sent',
  'removed_entity',
  '75000000-0000-0000-0000-000000000499',
  '2026-07-27 11:00:00+00'
);

do $$
declare
  v_result jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000201',
    true
  );

  v_result := public.global_navigation_search('HS-DEV', 5);
  if not exists (
    select 1
    from jsonb_array_elements(v_result -> 'items') item
    where item ->> 'category' = 'products'
      and item ->> 'identifier' = 'HS-DEV-001'
  ) then
    raise exception 'm4 fail: manager product search';
  end if;

  v_result := public.list_my_in_app_notifications(30, null);
  if jsonb_array_length(v_result -> 'items') <> 1
     or (v_result ->> 'unread_count')::integer <> 1
     or v_result #>> '{items,0,id}' <>
        '75000000-0000-0000-0000-000000000401' then
    raise exception 'm4 fail: own/stale notification shaping %', v_result;
  end if;

  if not public.set_my_in_app_notification_read(
    '75000000-0000-0000-0000-000000000401',
    true
  ) then
    raise exception 'm4 fail: mark own read';
  end if;
  if not public.set_my_in_app_notification_read(
    '75000000-0000-0000-0000-000000000401',
    true
  ) then
    raise exception 'm4 fail: idempotent mark own read';
  end if;
  if public.set_my_in_app_notification_read(
    '75000000-0000-0000-0000-000000000402',
    true
  ) then
    raise exception 'm4 fail: cross-recipient mutation';
  end if;

  if not exists (
    select 1
    from public.notifications
    where id = '75000000-0000-0000-0000-000000000401'
      and status = 'read'
      and read_at is not null
  ) then
    raise exception 'm4 fail: read state persistence';
  end if;
end $$;

do $$
declare
  v_result jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000202',
    true
  );

  v_result := public.global_navigation_search('HS-DEV', 5);
  if jsonb_array_length(v_result -> 'items') <> 0 then
    raise exception 'm4 fail: zero-permission search leak %', v_result;
  end if;

  v_result := public.list_my_in_app_notifications(30, null);
  if jsonb_array_length(v_result -> 'items') <> 1
     or v_result #>> '{items,0,id}' <>
        '75000000-0000-0000-0000-000000000402' then
    raise exception 'm4 fail: zero user own notification %', v_result;
  end if;
end $$;

insert into public.user_permissions (
  tenant_id,
  tenant_user_id,
  permission_id,
  granted_by
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000302',
  'customers.view',
  '00000000-0000-0000-0000-000000000201'
)
on conflict (tenant_user_id, permission_id) do nothing;

do $$
declare
  v_result jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000202',
    true
  );
  v_result := public.global_navigation_search('P7R', 5);
  if jsonb_array_length(v_result -> 'items') < 1
     or exists (
       select 1
       from jsonb_array_elements(v_result -> 'items') item
       where item ->> 'category' <> 'customers'
     ) then
    raise exception 'm4 fail: granted category search %', v_result;
  end if;
end $$;

rollback;

select 'phase_7_5_m4_global_tools: ok' as result;
