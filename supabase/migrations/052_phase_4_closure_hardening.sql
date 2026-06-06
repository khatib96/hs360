-- Phase 4 M8 closure hardening.
--
-- Supabase's default function privileges grant EXECUTE to anon and
-- authenticated. Phase 4 RPCs must be authenticated-only, while internal
-- helpers must not be callable by either API role.
--
-- Entity/account relationships are also made tenant-safe at the FK layer.

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.chart_of_accounts'::regclass
      and conname = 'ux_coa_tenant_id_id'
  ) then
    alter table public.chart_of_accounts
      add constraint ux_coa_tenant_id_id unique (tenant_id, id);
  end if;
end
$$;

alter table public.chart_of_accounts
  drop constraint if exists chart_of_accounts_parent_id_fkey;
alter table public.chart_of_accounts
  drop constraint if exists fk_coa_parent_tenant;
alter table public.chart_of_accounts
  add constraint fk_coa_parent_tenant
  foreign key (tenant_id, parent_id)
  references public.chart_of_accounts (tenant_id, id);

alter table public.customers
  drop constraint if exists customers_account_id_fkey;
alter table public.customers
  drop constraint if exists fk_customers_account_tenant;
alter table public.customers
  add constraint fk_customers_account_tenant
  foreign key (tenant_id, account_id)
  references public.chart_of_accounts (tenant_id, id);

alter table public.suppliers
  drop constraint if exists suppliers_account_id_fkey;
alter table public.suppliers
  drop constraint if exists fk_suppliers_account_tenant;
alter table public.suppliers
  add constraint fk_suppliers_account_tenant
  foreign key (tenant_id, account_id)
  references public.chart_of_accounts (tenant_id, id);

-- Internal helpers: owner/service-role use only.
revoke all on function public.get_entity_parent_account(text)
  from public, anon, authenticated;
revoke all on function public.generate_entity_code(text)
  from public, anon, authenticated;
revoke all on function public.generate_subaccount_code(uuid, text)
  from public, anon, authenticated;
revoke all on function public.generate_service_location_code(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.insert_primary_service_location_from_customer(
  uuid,
  uuid,
  jsonb
) from public, anon, authenticated;

-- Public Phase 4 API: authenticated only.
revoke all on function public.create_customer(jsonb)
  from public, anon, authenticated;
revoke all on function public.update_customer(uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.deactivate_customer(uuid)
  from public, anon, authenticated;
revoke all on function public.ensure_customer_account(uuid)
  from public, anon, authenticated;
revoke all on function public.create_supplier(jsonb)
  from public, anon, authenticated;
revoke all on function public.update_supplier(uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.deactivate_supplier(uuid)
  from public, anon, authenticated;
revoke all on function public.ensure_supplier_account(uuid)
  from public, anon, authenticated;
revoke all on function public.create_chart_account(jsonb)
  from public, anon, authenticated;
revoke all on function public.update_chart_account(uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.deactivate_chart_account(uuid)
  from public, anon, authenticated;
revoke all on function public.get_customer_balance_summary(uuid)
  from public, anon, authenticated;
revoke all on function public.get_customer_statement(uuid, date, date)
  from public, anon, authenticated;
revoke all on function public.list_customer_service_locations(uuid)
  from public, anon, authenticated;
revoke all on function public.create_customer_service_location(uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.update_customer_service_location(uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.deactivate_customer_service_location(uuid)
  from public, anon, authenticated;
revoke all on function public.set_primary_customer_service_location(uuid)
  from public, anon, authenticated;

grant execute on function public.create_customer(jsonb) to authenticated;
grant execute on function public.update_customer(uuid, jsonb) to authenticated;
grant execute on function public.deactivate_customer(uuid) to authenticated;
grant execute on function public.ensure_customer_account(uuid) to authenticated;
grant execute on function public.create_supplier(jsonb) to authenticated;
grant execute on function public.update_supplier(uuid, jsonb) to authenticated;
grant execute on function public.deactivate_supplier(uuid) to authenticated;
grant execute on function public.ensure_supplier_account(uuid) to authenticated;
grant execute on function public.create_chart_account(jsonb) to authenticated;
grant execute on function public.update_chart_account(uuid, jsonb)
  to authenticated;
grant execute on function public.deactivate_chart_account(uuid)
  to authenticated;
grant execute on function public.get_customer_balance_summary(uuid)
  to authenticated;
grant execute on function public.get_customer_statement(uuid, date, date)
  to authenticated;
grant execute on function public.list_customer_service_locations(uuid)
  to authenticated;
grant execute on function public.create_customer_service_location(uuid, jsonb)
  to authenticated;
grant execute on function public.update_customer_service_location(uuid, jsonb)
  to authenticated;
grant execute on function public.deactivate_customer_service_location(uuid)
  to authenticated;
grant execute on function public.set_primary_customer_service_location(uuid)
  to authenticated;
