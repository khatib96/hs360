-- Users & Permissions management (migration 111).
-- Seed: tenant A manager 201 (tu 301), zero-permission user 202 (tu 302),
-- products user 203 (tu 303); tenant B manager 204 (tu 304).
\set ON_ERROR_STOP on

create or replace function pg_temp.expect_error(p_sql text, p_expected text)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  raise exception 'user mgmt fail: % succeeded (expected %)', p_sql, p_expected;
exception
  when insufficient_privilege then
    if p_expected <> 'insufficient_privilege' then
      raise exception 'user mgmt fail: % denied by ACL (expected %)', p_sql, p_expected;
    end if;
  when raise_exception then
    if sqlerrm <> p_expected then
      raise exception 'user mgmt fail: % raised % (expected %)', p_sql, sqlerrm, p_expected;
    end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. A delegated (non-manager) admin cannot bypass the RPCs with direct
--    writes: no self-promotion to manager, no granting arbitrary permissions.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
select public.set_tenant_user_permissions(
  '00000000-0000-0000-0000-000000000303',
  array['products.view', 'settings.users.view', 'settings.users.edit',
        'settings.users.invite', 'settings.users.deactivate']
);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
update public.tenant_users set account_type = 'manager'
where id in ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000303');
select pg_temp.expect_error(
  $q$insert into public.user_permissions (tenant_id, tenant_user_id, permission_id)
     values ('00000000-0000-0000-0000-000000000101',
             '00000000-0000-0000-0000-000000000302', 'invoices.view')$q$,
  'insufficient_privilege'
);
delete from public.user_permissions
where tenant_user_id = '00000000-0000-0000-0000-000000000302';
reset role;
do $$
begin
  if exists (
    select 1 from public.tenant_users
    where id in ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000303')
      and account_type = 'manager'
  ) then
    raise exception 'user mgmt fail: delegated admin promoted an account directly';
  end if;
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 2. list_tenant_users is permission-gated and tenant-scoped.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_list jsonb := public.list_tenant_users();
begin
  if v_list::text like '%tenant-b.test%' then
    raise exception 'user mgmt fail: list leaks tenant B';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(v_list) e
    where e ->> 'login' = 'owner@hayat-secret.test'
      and (e ->> 'is_self')::boolean
      and e ->> 'account_type' = 'manager'
  ) then
    raise exception 'user mgmt fail: manager row missing %', v_list;
  end if;
  if (v_list -> 0 ->> 'account_type') <> 'manager' then
    raise exception 'user mgmt fail: managers are not listed first';
  end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
select pg_temp.expect_error('select public.list_tenant_users()', 'permission_denied');
rollback;

-- ---------------------------------------------------------------------------
-- 3. A manager replaces a user's permission set; changes are audited.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_result jsonb;
  v_now text[];
  v_audit int;
begin
  v_result := public.set_tenant_user_permissions(
    '00000000-0000-0000-0000-000000000302',
    array['products.view', 'customers.view', 'customers.view', ' ']
  );
  if v_result -> 'added' <> '["customers.view", "products.view"]'::jsonb then
    raise exception 'user mgmt fail: added %', v_result;
  end if;

  v_result := public.set_tenant_user_permissions(
    '00000000-0000-0000-0000-000000000302', array['customers.view']
  );
  if v_result -> 'removed' <> '["products.view"]'::jsonb
     or v_result -> 'added' <> '[]'::jsonb then
    raise exception 'user mgmt fail: replace %', v_result;
  end if;

  select array_agg(permission_id order by permission_id) into v_now
  from public.user_permissions
  where tenant_user_id = '00000000-0000-0000-0000-000000000302';
  if v_now <> array['customers.view'] then
    raise exception 'user mgmt fail: stored %', v_now;
  end if;

  select count(*) into v_audit
  from public.audit_log
  where entity_type = 'user_permissions'
    and at > now() - interval '1 minute';
  if v_audit < 3 then
    raise exception 'user mgmt fail: % permission audit rows', v_audit;
  end if;
end $$;
select pg_temp.expect_error(
  $q$select public.set_tenant_user_permissions(
       '00000000-0000-0000-0000-000000000302', array['no.such.permission'])$q$,
  'validation_failed'
);
select pg_temp.expect_error(
  $q$select public.set_tenant_user_permissions(
       '00000000-0000-0000-0000-000000000301', array['customers.view'])$q$,
  'cannot_modify_self'
);
select pg_temp.expect_error(
  $q$select public.set_tenant_user_permissions(
       '00000000-0000-0000-0000-000000000304', array['customers.view'])$q$,
  'user_not_found'
);
rollback;

-- ---------------------------------------------------------------------------
-- 4. A non-manager editor can only hand out permissions they hold and cannot
--    touch managers.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
select public.set_tenant_user_permissions(
  '00000000-0000-0000-0000-000000000303',
  array['products.view', 'settings.users.view', 'settings.users.edit',
        'settings.users.invite', 'settings.users.deactivate']
);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
select public.set_tenant_user_permissions(
  '00000000-0000-0000-0000-000000000302', array['products.view']
);
select pg_temp.expect_error(
  $q$select public.set_tenant_user_permissions(
       '00000000-0000-0000-0000-000000000302', array['products.view', 'invoices.view'])$q$,
  'permission_not_held'
);
select pg_temp.expect_error(
  $q$select public.set_tenant_user_permissions(
       '00000000-0000-0000-0000-000000000303', array['products.view'])$q$,
  'cannot_modify_self'
);
select pg_temp.expect_error(
  $q$select public.set_tenant_user_active('00000000-0000-0000-0000-000000000301', false)$q$,
  'manager_required'
);
select pg_temp.expect_error(
  $q$select public.prepare_tenant_user_password_reset('00000000-0000-0000-0000-000000000301')$q$,
  'manager_required'
);
rollback;

-- ---------------------------------------------------------------------------
-- 5. Deactivation removes access immediately; reactivation restores it.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
select public.set_tenant_user_active('00000000-0000-0000-0000-000000000303', false);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
do $$
begin
  if public.current_tenant_id() is not null then
    raise exception 'user mgmt fail: deactivated user still resolves a tenant';
  end if;
  if exists (select 1 from public.products) then
    raise exception 'user mgmt fail: deactivated user still reads products';
  end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
select public.set_tenant_user_active('00000000-0000-0000-0000-000000000303', true);
select pg_temp.expect_error(
  $q$select public.set_tenant_user_active('00000000-0000-0000-0000-000000000301', false)$q$,
  'cannot_modify_self'
);
rollback;

-- ---------------------------------------------------------------------------
-- 6. register_tenant_user only attaches fresh, unused logins.
-- ---------------------------------------------------------------------------
begin;
insert into auth.users (id, aud, role, email, created_at, updated_at, last_sign_in_at)
values
  ('00000000-0000-0000-0000-00000000d001', 'authenticated', 'authenticated', 'fresh@test.local', now(), now(), null),
  ('00000000-0000-0000-0000-00000000d002', 'authenticated', 'authenticated', 'old@test.local', now() - interval '1 day', now(), null),
  ('00000000-0000-0000-0000-00000000d003', 'authenticated', 'authenticated', 'used@test.local', now(), now(), now());
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_id uuid;
  v_row public.tenant_users%rowtype;
begin
  v_id := public.register_tenant_user('00000000-0000-0000-0000-00000000d001', 'موظف جديد', 'user');
  select * into v_row from public.tenant_users where id = v_id;
  if v_row.tenant_id <> '00000000-0000-0000-0000-000000000101'
     or v_row.account_type <> 'user'
     or not v_row.must_change_password
     or v_row.invited_by <> '00000000-0000-0000-0000-000000000201' then
    raise exception 'user mgmt fail: registered row %', row_to_json(v_row);
  end if;
end $$;
select pg_temp.expect_error(
  $q$select public.register_tenant_user('00000000-0000-0000-0000-00000000d001', 'x', 'user')$q$,
  'login_already_member'
);
select pg_temp.expect_error(
  $q$select public.register_tenant_user('00000000-0000-0000-0000-00000000d002', 'x', 'user')$q$,
  'login_not_fresh'
);
select pg_temp.expect_error(
  $q$select public.register_tenant_user('00000000-0000-0000-0000-00000000d003', 'x', 'user')$q$,
  'login_not_fresh'
);
select pg_temp.expect_error(
  $q$select public.register_tenant_user('00000000-0000-0000-0000-000000000204', 'x', 'user')$q$,
  'login_not_fresh'
);
select pg_temp.expect_error(
  $q$select public.register_tenant_user(gen_random_uuid(), 'x', 'user')$q$,
  'user_not_found'
);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
select pg_temp.expect_error(
  $q$select public.register_tenant_user('00000000-0000-0000-0000-00000000d002', 'x', 'user')$q$,
  'permission_denied'
);
rollback;

begin;
insert into auth.users (id, aud, role, email, created_at, updated_at)
values ('00000000-0000-0000-0000-00000000d004', 'authenticated', 'authenticated', 'fresh2@test.local', now(), now());
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
select public.set_tenant_user_permissions(
  '00000000-0000-0000-0000-000000000303', array['settings.users.invite']
);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000203';
select pg_temp.expect_error(
  $q$select public.register_tenant_user('00000000-0000-0000-0000-00000000d004', 'x', 'manager')$q$,
  'manager_required'
);
rollback;

-- ---------------------------------------------------------------------------
-- 7. Password reset forces a change; only the service clears the flag.
-- ---------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
begin
  if public.prepare_tenant_user_password_reset('00000000-0000-0000-0000-000000000302')
     <> '00000000-0000-0000-0000-000000000202' then
    raise exception 'user mgmt fail: reset returned the wrong login';
  end if;
  if not (select must_change_password from public.tenant_users
          where id = '00000000-0000-0000-0000-000000000302') then
    raise exception 'user mgmt fail: reset did not force a password change';
  end if;
end $$;
reset role;
do $$
begin
  if not exists (
    select 1 from public.audit_log
    where entity_type = 'tenant_users'
      and entity_id = '00000000-0000-0000-0000-000000000302'
      and action = 'password_reset'
      and actor_id = '00000000-0000-0000-0000-000000000201'
  ) then
    raise exception 'user mgmt fail: password reset not audited';
  end if;
end $$;
set local role authenticated;
select pg_temp.expect_error(
  $q$select public.prepare_tenant_user_password_reset('00000000-0000-0000-0000-000000000301')$q$,
  'cannot_modify_self'
);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000202';
select pg_temp.expect_error(
  $q$select public.complete_own_password_change('00000000-0000-0000-0000-000000000202')$q$,
  'insufficient_privilege'
);
set local role service_role;
select public.complete_own_password_change('00000000-0000-0000-0000-000000000202');
reset role;
do $$
begin
  if (select must_change_password from public.tenant_users
      where id = '00000000-0000-0000-0000-000000000302') then
    raise exception 'user mgmt fail: flag not cleared';
  end if;
end $$;
rollback;

select 'user_management: ok' as result;
