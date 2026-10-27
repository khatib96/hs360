-- Phase 7.5 hardening (migration 108): anon cannot execute project routines.
\set ON_ERROR_STOP on

-- 1. Only the five row-policy helpers remain executable by anon.
do $$
declare
  v_exposed text;
begin
  select string_agg(p.oid::regprocedure::text, ', ' order by p.proname)
  into v_exposed
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and not exists (
      select 1 from pg_depend d
      where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e'
    )
    and has_function_privilege('anon', p.oid, 'execute')
    and p.proname not in (
      'current_tenant_id', 'current_tenant_user_id', 'current_employee_id',
      'is_manager', 'user_has_permission'
    );

  if v_exposed is not null then
    raise exception 'anon acl fail: anon can execute %', v_exposed;
  end if;
end $$;

-- 2. Business RPCs are denied to anon before any business logic runs.
begin;
set local role anon;
do $$
begin
  perform public.collect_rental_payment('{}'::jsonb, gen_random_uuid());
  raise exception 'anon acl fail: collect_rental_payment executed';
exception
  when insufficient_privilege then null;
end $$;
do $$
begin
  perform public.get_my_permissions();
  raise exception 'anon acl fail: get_my_permissions executed';
exception
  when insufficient_privilege then null;
end $$;
rollback;

-- 3. Anonymous table reads still evaluate policies and return no rows.
begin;
set local role anon;
do $$
declare
  v_count int;
begin
  select count(*) into v_count from public.products;
  if v_count <> 0 then
    raise exception 'anon acl fail: anon saw % products', v_count;
  end if;
end $$;
rollback;

-- 4. Signed-in users keep their RPC access.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000201';
do $$
declare
  v_permissions json;
begin
  v_permissions := public.get_my_permissions();
  if (v_permissions ->> 'is_manager')::boolean is distinct from true then
    raise exception 'anon acl fail: manager lost get_my_permissions %', v_permissions;
  end if;
  perform 1 from public.list_sales_invoices(null, null, null, null, null, 5, 0);
end $$;
rollback;

select 'phase_7_5_anon_routine_acl: ok' as result;
