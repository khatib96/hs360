-- Phase 7.5 hardening: project routines require a signed-in session.
--
-- PostgreSQL grants EXECUTE on every new routine to PUBLIC, so the anon API
-- role could call 102 project routines (68 of them SECURITY DEFINER business
-- RPCs such as create_rental_contract and collect_rental_payment). Each one
-- currently rejects callers without a tenant, but that is a per-function
-- guard: a future routine that forgets it would be reachable without sign-in.
--
-- This migration:
-- 1. keeps authenticated and service_role on exactly the routines they could
--    execute before, now through explicit grants;
-- 2. removes PUBLIC and anon EXECUTE from every project-owned routine in
--    public (extension-owned routines are left untouched);
-- 3. re-grants anon only the five helpers referenced by row policies, so
--    anonymous table reads still return zero rows instead of raising errors.
--
-- PUBLIC EXECUTE is a global PostgreSQL default that cannot be removed per
-- schema, and SQL suites rely on it for pg_temp helpers. Later migrations must
-- therefore revoke PUBLIC/anon on each new routine themselves;
-- supabase/tests/phase_7_5_anon_routine_acl.sql fails if one is missed.

do $$
declare
  v_routine record;
begin
  for v_routine in
    select
      p.oid::regprocedure as signature,
      has_function_privilege('authenticated', p.oid, 'execute') as authenticated_exec,
      has_function_privilege('service_role', p.oid, 'execute') as service_exec
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and not exists (
        select 1
        from pg_depend d
        where d.classid = 'pg_proc'::regclass
          and d.objid = p.oid
          and d.deptype = 'e'
      )
  loop
    if v_routine.authenticated_exec then
      execute format(
        'grant execute on routine %s to authenticated',
        v_routine.signature
      );
    end if;

    if v_routine.service_exec then
      execute format(
        'grant execute on routine %s to service_role',
        v_routine.signature
      );
    end if;

    execute format(
      'revoke execute on routine %s from public, anon',
      v_routine.signature
    );
  end loop;
end $$;

-- Row-policy helpers: anon must be able to evaluate policies (they return
-- no tenant / no permission for anon), otherwise anonymous reads would error.
grant execute on function public.current_tenant_id() to anon;
grant execute on function public.current_tenant_user_id() to anon;
grant execute on function public.current_employee_id() to anon;
grant execute on function public.is_manager() to anon;
grant execute on function public.user_has_permission(text) to anon;
