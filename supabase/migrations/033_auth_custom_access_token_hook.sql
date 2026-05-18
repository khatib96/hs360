-- Phase 2 M3: enrich access tokens with tenant context from active tenant_users row.

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  claims jsonb;
  v_tenant_id uuid;
  v_tenant_user_id uuid;
  v_account_type public.user_account_type;
begin
  claims := coalesce(event->'claims', '{}'::jsonb);

  select tu.tenant_id, tu.id, tu.account_type
  into v_tenant_id, v_tenant_user_id, v_account_type
  from public.tenant_users tu
  where tu.user_id = (event->>'user_id')::uuid
    and tu.is_active = true
  order by tu.joined_at asc
  limit 1;

  if v_tenant_id is not null then
    claims := jsonb_set(claims, '{tenant_id}', to_jsonb(v_tenant_id::text), true);
    claims := jsonb_set(claims, '{tenant_user_id}', to_jsonb(v_tenant_user_id::text), true);
    claims := jsonb_set(claims, '{account_type}', to_jsonb(v_account_type::text), true);
  end if;

  return jsonb_build_object('claims', claims);
end;
$$;

grant usage on schema public to supabase_auth_admin;

grant execute
  on function public.custom_access_token_hook(jsonb)
  to supabase_auth_admin;

revoke execute
  on function public.custom_access_token_hook(jsonb)
  from authenticated, anon, public;

grant select on public.tenant_users to supabase_auth_admin;

create policy tenant_users_auth_admin_select
  on public.tenant_users
  as permissive
  for select
  to supabase_auth_admin
  using (true);
