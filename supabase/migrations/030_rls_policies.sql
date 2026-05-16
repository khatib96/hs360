-- Phase 1C: RLS policies per docs/SECURITY.md section 3.

-- ---------------------------------------------------------------------------
-- tenants
-- ---------------------------------------------------------------------------
alter table tenants enable row level security;

create policy tenants_select_own on tenants
  for select using (id = current_tenant_id());

-- ---------------------------------------------------------------------------
-- permissions (read-only catalog; seed via service role in 1D)
-- ---------------------------------------------------------------------------
alter table permissions enable row level security;

create policy permissions_select_authenticated on permissions
  for select using (auth.uid() is not null);

-- ---------------------------------------------------------------------------
-- tenant_users
-- ---------------------------------------------------------------------------
alter table tenant_users enable row level security;

create policy tenant_users_select on tenant_users
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.users.view')
  );

create policy tenant_users_insert on tenant_users
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.users.invite')
  );

create policy tenant_users_update on tenant_users
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.users.edit')
  );

create policy tenant_users_delete on tenant_users
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.users.deactivate')
  );

-- ---------------------------------------------------------------------------
-- tenant_settings
-- ---------------------------------------------------------------------------
alter table tenant_settings enable row level security;

create policy tenant_settings_select on tenant_settings
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.company.view')
  );

create policy tenant_settings_update on tenant_settings
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.company.edit')
  );

create policy tenant_settings_delete on tenant_settings
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.company.delete')
  );

-- ---------------------------------------------------------------------------
-- currencies
-- ---------------------------------------------------------------------------
alter table currencies enable row level security;

create policy currencies_select on currencies
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.company.view')
  );

create policy currencies_insert on currencies
  for insert with check (
    tenant_id = current_tenant_id()
    and is_manager()
  );

create policy currencies_update on currencies
  for update using (
    tenant_id = current_tenant_id()
    and is_manager()
  );

create policy currencies_delete on currencies
  for delete using (
    tenant_id = current_tenant_id()
    and is_manager()
  );

-- ---------------------------------------------------------------------------
-- user_permissions
-- ---------------------------------------------------------------------------
alter table user_permissions enable row level security;

create policy user_permissions_select on user_permissions
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.users.view')
  );

create policy user_permissions_insert on user_permissions
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.users.edit')
    and tenant_user_id <> current_tenant_user_id()
  );

create policy user_permissions_update on user_permissions
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.users.edit')
    and tenant_user_id <> current_tenant_user_id()
  );

create policy user_permissions_delete on user_permissions
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('settings.users.edit')
    and tenant_user_id <> current_tenant_user_id()
  );

-- ---------------------------------------------------------------------------
-- employees
-- ---------------------------------------------------------------------------
alter table employees enable row level security;

create policy employees_select on employees
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.employees.view')
  );

create policy employees_insert on employees
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.employees.create')
  );

create policy employees_update on employees
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.employees.edit')
  );

create policy employees_delete on employees
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.employees.delete')
  );

-- ---------------------------------------------------------------------------
-- commission_rules
-- ---------------------------------------------------------------------------
alter table commission_rules enable row level security;

create policy commission_rules_select on commission_rules
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.commissions.view')
  );

create policy commission_rules_insert on commission_rules
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.commissions.create')
  );

create policy commission_rules_update on commission_rules
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.commissions.edit')
  );

create policy commission_rules_delete on commission_rules
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.commissions.delete')
  );

-- ---------------------------------------------------------------------------
-- salaries
-- ---------------------------------------------------------------------------
alter table salaries enable row level security;

create policy salaries_select on salaries
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.salaries.view')
  );

create policy salaries_insert on salaries
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.salaries.create')
  );

create policy salaries_update on salaries
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.salaries.edit')
  );

create policy salaries_delete on salaries
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.salaries.delete')
  );

-- ---------------------------------------------------------------------------
-- advances
-- ---------------------------------------------------------------------------
alter table advances enable row level security;

create policy advances_select on advances
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.advances.view')
  );

create policy advances_insert on advances
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.advances.create')
  );

create policy advances_update on advances
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.advances.edit')
  );

create policy advances_delete on advances
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('hr.advances.delete')
  );

-- ---------------------------------------------------------------------------
-- warehouses
-- ---------------------------------------------------------------------------
alter table warehouses enable row level security;

create policy warehouses_select on warehouses
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('warehouses.view')
  );

create policy warehouses_insert on warehouses
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('warehouses.create')
  );

create policy warehouses_update on warehouses
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('warehouses.edit')
  );

create policy warehouses_delete on warehouses
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('warehouses.delete')
  );

-- ---------------------------------------------------------------------------
-- chart_of_accounts
-- ---------------------------------------------------------------------------
alter table chart_of_accounts enable row level security;

create policy chart_of_accounts_select on chart_of_accounts
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('chart_of_accounts.view')
  );

create policy chart_of_accounts_insert on chart_of_accounts
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('chart_of_accounts.create')
  );

create policy chart_of_accounts_update on chart_of_accounts
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('chart_of_accounts.edit')
  );

create policy chart_of_accounts_delete on chart_of_accounts
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('chart_of_accounts.delete')
    and not is_system
  );

-- ---------------------------------------------------------------------------
-- product_groups
-- ---------------------------------------------------------------------------
alter table product_groups enable row level security;

create policy product_groups_select on product_groups
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('product_groups.view')
  );

create policy product_groups_insert on product_groups
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('product_groups.create')
  );

create policy product_groups_update on product_groups
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('product_groups.edit')
  );

create policy product_groups_delete on product_groups
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('product_groups.delete')
  );

-- ---------------------------------------------------------------------------
-- products
-- ---------------------------------------------------------------------------
alter table products enable row level security;

create policy products_select on products
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('products.view')
  );

create policy products_insert on products
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('products.create')
  );

create policy products_update on products
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('products.edit')
  );

create policy products_delete on products
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('products.delete')
  );

-- ---------------------------------------------------------------------------
-- product_units
-- ---------------------------------------------------------------------------
alter table product_units enable row level security;

create policy product_units_select on product_units
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('product_units.view')
  );

create policy product_units_insert on product_units
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('product_units.create')
  );

create policy product_units_update on product_units
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('product_units.edit')
  );

create policy product_units_delete on product_units
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('product_units.delete')
  );

-- ---------------------------------------------------------------------------
-- maintenance_records
-- ---------------------------------------------------------------------------
alter table maintenance_records enable row level security;

create policy maintenance_records_select on maintenance_records
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('maintenance.view')
  );

create policy maintenance_records_insert on maintenance_records
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('maintenance.create')
  );

create policy maintenance_records_update on maintenance_records
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('maintenance.edit')
  );

create policy maintenance_records_delete on maintenance_records
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('maintenance.delete')
  );

-- ---------------------------------------------------------------------------
-- inventory_balances (read-only for clients)
-- ---------------------------------------------------------------------------
alter table inventory_balances enable row level security;

create policy inventory_balances_select on inventory_balances
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('inventory.view')
  );

-- ---------------------------------------------------------------------------
-- inventory_movements
-- ---------------------------------------------------------------------------
alter table inventory_movements enable row level security;

create policy inventory_movements_select on inventory_movements
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('inventory_movements.view')
  );

create policy inventory_movements_insert on inventory_movements
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('inventory_movements.create')
  );

create policy inventory_movements_delete on inventory_movements
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('inventory_movements.delete')
  );

-- ---------------------------------------------------------------------------
-- customers
-- ---------------------------------------------------------------------------
alter table customers enable row level security;

create policy customers_select on customers
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('customers.view')
  );

create policy customers_insert on customers
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('customers.create')
  );

create policy customers_update on customers
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('customers.edit')
  );

create policy customers_delete on customers
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('customers.delete')
  );

-- ---------------------------------------------------------------------------
-- suppliers
-- ---------------------------------------------------------------------------
alter table suppliers enable row level security;

create policy suppliers_select on suppliers
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('suppliers.view')
  );

create policy suppliers_insert on suppliers
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('suppliers.create')
  );

create policy suppliers_update on suppliers
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('suppliers.edit')
  );

create policy suppliers_delete on suppliers
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('suppliers.delete')
  );

-- ---------------------------------------------------------------------------
-- journal_entries / journal_lines (read-only for clients)
-- ---------------------------------------------------------------------------
alter table journal_entries enable row level security;

create policy journal_entries_select on journal_entries
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('journal.view')
  );

alter table journal_lines enable row level security;

create policy journal_lines_select on journal_lines
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('journal.view')
  );

-- ---------------------------------------------------------------------------
-- invoices
-- ---------------------------------------------------------------------------
alter table invoices enable row level security;

create policy invoices_select on invoices
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('invoices.view')
  );

create policy invoices_insert on invoices
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('invoices.create')
  );

create policy invoices_update on invoices
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('invoices.edit')
  );

create policy invoices_delete on invoices
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('invoices.cancel')
  );

-- ---------------------------------------------------------------------------
-- invoice_lines
-- ---------------------------------------------------------------------------
alter table invoice_lines enable row level security;

create policy invoice_lines_select on invoice_lines
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('invoices.view')
  );

create policy invoice_lines_insert on invoice_lines
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('invoices.create')
  );

create policy invoice_lines_update on invoice_lines
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('invoices.edit')
  );

-- ---------------------------------------------------------------------------
-- vouchers
-- ---------------------------------------------------------------------------
alter table vouchers enable row level security;

create policy vouchers_select on vouchers
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('vouchers.view')
  );

create policy vouchers_insert on vouchers
  for insert with check (
    tenant_id = current_tenant_id()
    and (
      user_has_permission('vouchers.create_receipt')
      or user_has_permission('vouchers.create_payment')
    )
  );

create policy vouchers_update on vouchers
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('vouchers.edit')
  );

create policy vouchers_delete on vouchers
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('vouchers.cancel')
  );

-- ---------------------------------------------------------------------------
-- voucher_invoice_allocations
-- ---------------------------------------------------------------------------
alter table voucher_invoice_allocations enable row level security;

create policy voucher_invoice_allocations_select on voucher_invoice_allocations
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('vouchers.view')
  );

create policy voucher_invoice_allocations_delete on voucher_invoice_allocations
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('vouchers.cancel')
  );

-- ---------------------------------------------------------------------------
-- contracts
-- ---------------------------------------------------------------------------
alter table contracts enable row level security;

create policy contracts_select on contracts
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.view')
  );

create policy contracts_insert on contracts
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.create')
  );

create policy contracts_update on contracts
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.edit')
  );

create policy contracts_delete on contracts
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.delete')
  );

-- ---------------------------------------------------------------------------
-- contract_lines
-- ---------------------------------------------------------------------------
alter table contract_lines enable row level security;

create policy contract_lines_select on contract_lines
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.view')
  );

create policy contract_lines_insert on contract_lines
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.create')
  );

create policy contract_lines_update on contract_lines
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.edit')
  );

-- ---------------------------------------------------------------------------
-- contract_oil_changes
-- ---------------------------------------------------------------------------
alter table contract_oil_changes enable row level security;

create policy contract_oil_changes_select on contract_oil_changes
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.view')
  );

create policy contract_oil_changes_insert on contract_oil_changes
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.oil_change')
  );

create policy contract_oil_changes_update on contract_oil_changes
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.oil_change')
  );

create policy contract_oil_changes_delete on contract_oil_changes
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.oil_change.delete')
  );

-- ---------------------------------------------------------------------------
-- visits
-- ---------------------------------------------------------------------------
alter table visits enable row level security;

create policy visits_select on visits
  for select using (
    tenant_id = current_tenant_id()
    and (
      user_has_permission('visits.view')
      or (
        user_has_permission('visits.view_assigned')
        and agent_id = current_employee_id()
      )
    )
  );

create policy visits_insert on visits
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('visits.create')
  );

create policy visits_update on visits
  for update using (
    tenant_id = current_tenant_id()
    and (
      user_has_permission('visits.edit')
      or (
        user_has_permission('visits.edit_assigned')
        and agent_id = current_employee_id()
      )
    )
  );

create policy visits_delete on visits
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('visits.delete')
  );

-- ---------------------------------------------------------------------------
-- quotations
-- ---------------------------------------------------------------------------
alter table quotations enable row level security;

create policy quotations_select on quotations
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('quotations.view')
  );

create policy quotations_insert on quotations
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('quotations.create')
  );

create policy quotations_update on quotations
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('quotations.edit')
  );

create policy quotations_delete on quotations
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('quotations.delete')
  );

-- ---------------------------------------------------------------------------
-- quotation_lines
-- ---------------------------------------------------------------------------
alter table quotation_lines enable row level security;

create policy quotation_lines_select on quotation_lines
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('quotations.view')
  );

create policy quotation_lines_insert on quotation_lines
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('quotations.create')
  );

create policy quotation_lines_update on quotation_lines
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('quotations.edit')
  );

create policy quotation_lines_delete on quotation_lines
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('quotations.delete')
  );

-- ---------------------------------------------------------------------------
-- calendar_events
-- ---------------------------------------------------------------------------
alter table calendar_events enable row level security;

create policy calendar_events_select on calendar_events
  for select using (
    tenant_id = current_tenant_id()
    and (
      user_has_permission('calendar.view')
      or (
        user_has_permission('calendar.view_assigned')
        and assigned_agent_id = current_employee_id()
      )
    )
  );

create policy calendar_events_insert on calendar_events
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('calendar.create')
  );

create policy calendar_events_update on calendar_events
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('calendar.edit')
  );

create policy calendar_events_delete on calendar_events
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('calendar.delete')
  );

-- ---------------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------------
alter table notifications enable row level security;

create policy notifications_select on notifications
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('notifications.view')
  );

create policy notifications_insert on notifications
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('notifications.create')
  );

create policy notifications_delete on notifications
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('notifications.delete')
  );

-- ---------------------------------------------------------------------------
-- audit_log (read-only; writes via security definer triggers)
-- ---------------------------------------------------------------------------
alter table audit_log enable row level security;

create policy audit_log_select on audit_log
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('audit_log.view')
  );
