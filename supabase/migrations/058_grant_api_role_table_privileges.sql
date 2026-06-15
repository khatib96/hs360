-- Phase 5 local/self-hosted API ACL compatibility.
--
-- Some Supabase installations do not provision the same API-role table grants
-- as hosted projects. Grant only operations backed by an RLS policy. Never
-- grant TRUNCATE, REFERENCES, TRIGGER, or blanket routine EXECUTE to
-- API roles; those privileges bypass the RPC-only boundaries established by
-- migrations 045, 054, 056, and 057.

grant usage on schema public to authenticated, service_role;

-- Remove installation-specific grants before rebuilding the authenticated ACL.
revoke all privileges on all tables in schema public from authenticated;
revoke all privileges on all sequences in schema public from authenticated;
revoke all privileges on all tables in schema public from anon;
revoke all privileges on all sequences in schema public from anon;

do $$
declare
  v_relation record;
  v_privileges text[];
begin
  for v_relation in
    select
      c.oid,
      format('%I.%I', n.nspname, c.relname) as qualified_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and c.relrowsecurity
    order by c.relname
  loop
    v_privileges := array[]::text[];

    if exists (
      select 1 from pg_policy
      where polrelid = v_relation.oid and polcmd in ('r', '*')
    ) then
      v_privileges := array_append(v_privileges, 'select');
      execute format(
        'grant select on table %s to anon',
        v_relation.qualified_name
      );
    end if;

    if exists (
      select 1 from pg_policy
      where polrelid = v_relation.oid and polcmd in ('a', '*')
    ) then
      v_privileges := array_append(v_privileges, 'insert');
    end if;

    if exists (
      select 1 from pg_policy
      where polrelid = v_relation.oid and polcmd in ('w', '*')
    ) then
      v_privileges := array_append(v_privileges, 'update');
    end if;

    if exists (
      select 1 from pg_policy
      where polrelid = v_relation.oid and polcmd in ('d', '*')
    ) then
      v_privileges := array_append(v_privileges, 'delete');
    end if;

    if cardinality(v_privileges) > 0 then
      execute format(
        'grant %s on table %s to authenticated',
        array_to_string(v_privileges, ', '),
        v_relation.qualified_name
      );
    end if;
  end loop;
end
$$;

-- Views are not RLS relations and therefore remain explicit.
grant select on public.products_safe to authenticated;
grant select on public.contracts_safe to authenticated;
grant select on public.v_unit_timeline to authenticated;

-- UUIDs are the application default, but sequence access is safe for any
-- RLS-protected table that uses an identity/serial default.
grant usage, select on all sequences in schema public to authenticated;

-- The service role is trusted infrastructure and bypasses RLS by design.
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant all privileges on all routines in schema public to service_role;

-- Future migrations must grant authenticated access explicitly after defining
-- their RLS policies. Do not inherit broad client privileges.
alter default privileges in schema public
  revoke all on tables from authenticated;
alter default privileges in schema public
  revoke all on sequences from authenticated;
alter default privileges in schema public
  revoke all on routines from authenticated;
alter default privileges in schema public
  revoke all on tables from anon;
alter default privileges in schema public
  revoke all on sequences from anon;
alter default privileges in schema public
  revoke all on routines from anon;

alter default privileges in schema public
  grant all on tables to service_role;
alter default privileges in schema public
  grant all on sequences to service_role;
alter default privileges in schema public
  grant all on routines to service_role;
