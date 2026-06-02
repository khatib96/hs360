# CANONICAL_DECISIONS.md — Source of Truth

> Updated 2026-05-16 to resolve conflicts before Phase 0.
> If this file conflicts with any older document, this file wins.

---

## 1. Permissions

The access model is **Manager/User only**.

- `manager`: full access inside their tenant. Permission checks return true.
- `user`: zero permissions by default. Every action and sensitive field must be explicitly granted.
- There are no hardcoded access roles. Operational job labels are descriptive only.
- Operational job names may appear in examples, but they are not access-control roles.

Canonical database objects:

```sql
create type user_account_type as enum ('manager', 'user');

create table tenant_users (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  account_type user_account_type not null default 'user',
  display_name text,
  preferred_locale text,
  is_active boolean default true,
  invited_by uuid references auth.users(id),
  joined_at timestamptz default now(),
  unique(tenant_id, user_id)
);
```

RLS policies use `user_has_permission('module.action')`, never role checks.

---

## 2. Currencies

Currencies are dynamic. Hayat Secret starts with KWD, but KWD is an example, not a system constant.

- v1 supports one default currency per tenant.
- `currencies.decimal_places` controls display precision.
- Multi-currency invoices, exchange rates, and realized FX gains/losses are Phase 2.
- Money is stored with `numeric(15,3)` in PostgreSQL and `Decimal` in Dart.
- UI must use `MoneyDisplay`; never hardcode `KWD`, `د.ك`, or `toStringAsFixed(3)`.

---

## 3. Field Permissions

Field hiding is implemented with:

1. RLS on base tables.
2. `security_invoker = true` safe views that omit sensitive columns.
3. Optional RPCs that shape JSON based on `user_has_permission()`.

Correct safe-view pattern:

```sql
create or replace view contracts_safe
with (security_invoker = true) as
  select
    id, tenant_id, contract_number, type, status,
    customer_id, service_location_id, monthly_rental_value,
    start_date, end_date, billing_day, refill_day,
    created_at, updated_at
  from contracts;
```

Do not describe this as view-level RLS. RLS belongs on the base tables; `security_invoker` makes the view respect the caller's privileges and underlying RLS.

---

## 4. Snapshot Principle

Contract cost snapshots are frozen forever.

- Contract creation stores device monthly cost, oil monthly cost, total monthly cost, and expected monthly profit.
- Contract creation also snapshots selected service-location contact/address/map fields.
- Profit reports use snapshots, not current product cost.
- Later WAC changes do not rewrite historical contract economics.
- Later service-location edits do not rewrite historical contract location data.

This is a business rule, not an implementation detail.

---

## 4.5 Customer Service Locations

The customer is the company/account. Branches, offices, homes, warehouses, and installation addresses are service locations under the customer.

- Do not create duplicate customer records for customer branches.
- Use `customer_service_locations` for operational addresses.
- Contracts, visits, calendar events, and rented product units should reference `service_location_id` when the work happens at a physical site.
- Enforce tenant/customer/location alignment with **composite foreign keys only** (no parallel simple FK on `customer_id` or `service_location_id`).
- `product_units.current_service_location_id` is the **current** operational site only; movement history belongs in a future `product_unit_location_history` table (not Phase 4).
- Phase 6+ RPCs that move a device must update `current_customer_id` and `current_service_location_id` together in one transaction.
- Customer balance, statement, invoices, and vouchers stay at customer level.
- Contracts keep frozen location snapshots at signing.

---

## 5. RLS

Every business table has:

- `tenant_id uuid not null`
- RLS enabled
- `select`, `insert`, `update`, and delete/cancel policies in the same migration
- Permission checks through `user_has_permission()`

Service-role access is only allowed in Edge Functions, scheduled jobs, and provisioning scripts. It is never used in Flutter client code.

---

## 6. MVP Boundary

v1 is intentionally narrow:

- Auth + Manager/User permissions
- Products, customers, rental contracts
- Basic invoices and vouchers
- Mobile refill flow with GPS and live photo
- Calendar view only
- Basic reports: customer balance and contract list

Phase 2+:

- POS
- Full HR payroll and commissions
- WhatsApp campaigns
- Maintenance module
- Quotations
- Trial contracts
- Offline sync
- Full P&L reporting
