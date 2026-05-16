-- Phase 1C: audit, journal balance, tenant_users guards, touch_updated_at.

create or replace function audit_log_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_entity_id uuid;
  v_action text;
begin
  v_action := lower(tg_op);

  if tg_op = 'DELETE' then
    v_tenant_id := old.tenant_id;
    v_entity_id := case
      when tg_table_name = 'tenant_settings' then old.tenant_id
      else old.id
    end;
  else
    v_tenant_id := new.tenant_id;
    v_entity_id := case
      when tg_table_name = 'tenant_settings' then new.tenant_id
      else new.id
    end;
  end if;

  insert into audit_log (
    tenant_id,
    actor_id,
    actor_account_type,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  values (
    v_tenant_id,
    auth.uid(),
    current_account_type()::text,
    v_action,
    tg_table_name,
    v_entity_id,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );

  return coalesce(new, old);
end;
$$;

-- contracts
create trigger trg_audit_contracts
  after insert or update or delete on contracts
  for each row execute function audit_log_row();

create trigger trg_audit_contract_lines
  after insert or update or delete on contract_lines
  for each row execute function audit_log_row();

-- invoices
create trigger trg_audit_invoices_insert
  after insert on invoices
  for each row execute function audit_log_row();

create trigger trg_audit_invoices_delete
  after delete on invoices
  for each row execute function audit_log_row();

create trigger trg_audit_invoices_status
  after update on invoices
  for each row
  when (old.status is distinct from new.status)
  execute function audit_log_row();

-- vouchers (insert/delete only; no status column in schema)
create trigger trg_audit_vouchers_insert
  after insert on vouchers
  for each row execute function audit_log_row();

create trigger trg_audit_vouchers_delete
  after delete on vouchers
  for each row execute function audit_log_row();

-- user_permissions (grant/revoke)
create trigger trg_audit_user_permissions_insert
  after insert on user_permissions
  for each row execute function audit_log_row();

create trigger trg_audit_user_permissions_delete
  after delete on user_permissions
  for each row execute function audit_log_row();

-- journal_entries
create trigger trg_audit_journal_entries_insert
  after insert on journal_entries
  for each row execute function audit_log_row();

create trigger trg_audit_journal_entries_posted
  after update on journal_entries
  for each row
  when (old.is_posted is distinct from new.is_posted and new.is_posted = true)
  execute function audit_log_row();

-- product_units
create trigger trg_audit_product_units_insert
  after insert on product_units
  for each row execute function audit_log_row();

create trigger trg_audit_product_units_delete
  after delete on product_units
  for each row execute function audit_log_row();

create trigger trg_audit_product_units_status
  after update on product_units
  for each row
  when (old.status is distinct from new.status)
  execute function audit_log_row();

-- products (price/cost changes only)
create trigger trg_audit_products_pricing
  after update on products
  for each row
  when (
    old.sale_price is distinct from new.sale_price
    or old.rental_price_monthly is distinct from new.rental_price_monthly
    or old.avg_cost is distinct from new.avg_cost
    or old.last_purchase_cost is distinct from new.last_purchase_cost
    or old.min_sale_price is distinct from new.min_sale_price
  )
  execute function audit_log_row();

-- tenant_users
create trigger trg_audit_tenant_users_insert
  after insert on tenant_users
  for each row execute function audit_log_row();

create trigger trg_audit_tenant_users_update
  after update on tenant_users
  for each row
  when (
    old.account_type is distinct from new.account_type
    or old.is_active is distinct from new.is_active
  )
  execute function audit_log_row();

-- tenant_settings
create trigger trg_audit_tenant_settings_update
  after update on tenant_settings
  for each row execute function audit_log_row();

-- inventory_movements
create trigger trg_audit_inventory_movements_insert
  after insert on inventory_movements
  for each row execute function audit_log_row();

-- tenant_users safety triggers
create or replace function prevent_last_manager_demotion()
returns trigger
language plpgsql
as $$
begin
  if old.account_type = 'manager'
    and (
      new.account_type = 'user'
      or (old.is_active = true and new.is_active = false)
    )
  then
    if (
      select count(*)
      from tenant_users
      where tenant_id = new.tenant_id
        and account_type = 'manager'
        and is_active = true
        and id <> new.id
    ) = 0
    then
      raise exception 'Cannot demote or deactivate the last active manager';
    end if;
  end if;

  return new;
end;
$$;

create or replace function prevent_self_tenant_user_modification()
returns trigger
language plpgsql
as $$
begin
  if new.user_id = auth.uid()
    and (
      new.account_type is distinct from old.account_type
      or new.is_active is distinct from old.is_active
    )
  then
    raise exception 'Cannot modify your own tenant membership';
  end if;

  return new;
end;
$$;

create trigger trg_prevent_last_manager_demotion
  before update of account_type, is_active on tenant_users
  for each row execute function prevent_last_manager_demotion();

create trigger trg_prevent_self_tenant_user_modification
  before update on tenant_users
  for each row execute function prevent_self_tenant_user_modification();

-- journal balance check
create or replace function check_journal_balanced()
returns trigger
language plpgsql
as $$
begin
  if (
    select coalesce(sum(debit), 0) - coalesce(sum(credit), 0)
    from journal_lines
    where journal_entry_id = new.journal_entry_id
  ) <> 0
  then
    raise exception 'Journal entry % not balanced', new.journal_entry_id;
  end if;

  return new;
end;
$$;

create constraint trigger journal_balance_check
  after insert or update on journal_lines
  deferrable initially deferred
  for each row execute function check_journal_balanced();

-- touch_updated_at (canonical six tables only)
create trigger trg_touch_tenant_settings
  before update on tenant_settings
  for each row execute function touch_updated_at();

create trigger trg_touch_products
  before update on products
  for each row execute function touch_updated_at();

create trigger trg_touch_product_units
  before update on product_units
  for each row execute function touch_updated_at();

create trigger trg_touch_inventory_balances
  before update on inventory_balances
  for each row execute function touch_updated_at();

create trigger trg_touch_customers
  before update on customers
  for each row execute function touch_updated_at();

create trigger trg_touch_contracts
  before update on contracts
  for each row execute function touch_updated_at();
