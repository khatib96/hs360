-- Phase 5 fix: restore PostgREST role privileges for the public schema.
--
-- Hosted Supabase grants table/sequence privileges to the API roles via its
-- managed default privileges. This self-hosted/local stack did not, so every
-- table only had REFERENCES/TRIGGER/TRUNCATE for `authenticated` and PostgREST
-- returned `42501 permission denied for table ...` after login (e.g. reading
-- `tenant_users` during session bootstrap).
--
-- Row Level Security (enabled in 030_rls_policies.sql and later) remains the
-- access-control layer. These grants only let the API roles reach the
-- RLS-protected objects. `anon` is intentionally excluded: the app performs no
-- table access before authentication.

grant usage on schema public to authenticated, service_role;

grant all on all tables in schema public to authenticated, service_role;
grant all on all sequences in schema public to authenticated, service_role;
grant all on all routines in schema public to authenticated, service_role;

-- Ensure objects created by future migrations inherit the same privileges.
alter default privileges in schema public
  grant all on tables to authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to authenticated, service_role;
alter default privileges in schema public
  grant all on routines to authenticated, service_role;
