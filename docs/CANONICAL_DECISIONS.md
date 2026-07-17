# CANONICAL_DECISIONS.md — Source of Truth

> Updated 2026-06-15 with inventory-accounting, return-document, and
> year-end-close placement decisions.
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

## 2.5 Tax Foundation

Tax support is an invoice-foundation concern, not a Phase 4/M7 chart-of-accounts scope item.

- Phase 5 must add a small Tax Foundation before `record_sales_invoice` and `record_purchase_invoice`.
- Out of scope for this foundation: VAT returns, tax authority integrations, country-specific e-invoicing, ZATCA/FTA integrations, and government filing.
- The tax engine calculates tax. The chart of accounts only receives the resulting accounting postings.
- Prefer `tenant_settings.default_tax_rate_id` over a raw numeric `default_tax_rate`.
- Product tax treatment must not be a boolean. Use explicit classes such as `taxable`, `zero_rated`, `exempt`, and `non_taxable`.
- Tax rates should be tenant-scoped rows with stable IDs, rate snapshots, effective date ranges, active state, and posting account references.
- Suggested tax-rate fields: `code`, `name_ar`, `name_en`, `rate`, `output_account_id`, `input_account_id`, optional `expense_account_id`, `is_recoverable`, `effective_from`, `effective_to`, and `is_active`.
- Invoice lines must snapshot tax at issue/confirmation time: `tax_rate_id`, numeric `tax_rate`, `tax_class`, `taxable_amount`, `tax_amount`, and before/after-tax line totals.
- Old invoices must never be recomputed from a newer tax rate. Historical invoices keep the tax values saved on their lines.
- Tax posting accounts such as `Input VAT Recoverable` and `Output VAT Payable` should be seeded as protected system accounts when Tax Foundation is implemented, not required during Phase 4 M7.
- Kuwait/default v1 tenants may run with tax disabled and zero tax amounts, but the invoice structure must remain tax-ready.

---

## 2.6 Inventory Accounting and Financial Close

**Implementation status (2026-06-17): approved and implemented in migrations
`065`–`070`.** Inventory financial documents post through RPC-only
`inventory_documents` with balanced journals. Purchase invoice WAC continues to
use `qty_available` via `apply_purchase_wac_internal`; inventory-document WAC
uses all owned buckets via `apply_inventory_wac_internal`. Cancel supports
idempotent replay; serialized document cancel is rejected in M4.5.

Inventory quantity and inventory value must never diverge after the Phase 5
finance engine becomes operational.

- Phase 5 M4.5 supersedes the Phase 3 rule that manual inventory adjustments
  have no journal entry.
- Opening stock is a dedicated financial inventory document:
  `Dr Inventory / Cr Opening Balance Equity`.
- Owner-contributed stock uses owner capital, not inventory gain.
- Owner withdrawals use owner drawings, not an operating expense.
- In-period found surplus posts to inventory gain income.
- Shrinkage, damage, expiry, and write-off post to an inventory loss/expense
  account.
- Internal consumption posts to an explicitly allowed expense account.
- Warehouse transfers produce paired inventory movements but no general-ledger
  journal because ownership and total inventory value do not change.
- A stock count is one immutable document whose lines compare system quantity
  with counted quantity and create only the required positive/negative
  movements and accounting lines.
- Generic stock-in/stock-out cannot accept an unrestricted counter-account ID.
  A tenant-scoped, permission-controlled reason must resolve to an allowed
  posting account and direction.
- Every confirmed inventory financial document is RPC-only, idempotent,
  immutable, audited, period-lock aware, and linked to a balanced journal.
- Sales returns and purchase returns are distinct financial documents linked to
  the original invoice. They are not aliases for cancellation and are
  implemented in Phase 5 M7.5 after the voucher/credit settlement foundation.
- Full fiscal periods and year-end close belong in Phase 10 after trial balance
  and P&L reporting exist. Year-end close zeros income/expense accounts into
  retained earnings; it does not reset inventory or other balance-sheet
  accounts.
- M5 purchase posting preserves the existing `apply_purchase_wac_internal`
  (`qty_available` across warehouses). M4.5 inventory documents use a separate
  all-owned-buckets WAC helper and do not alter purchase WAC behavior.

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

- Contract creation stores device monthly cost, rental-consumable monthly cost,
  total monthly cost, expected monthly profit, and the pricing basis used.
- Phase 6 pricing basis is tenant-configurable. Default owner preference:
  selected unit purchase cost for rental assets, product sale price for rental
  consumables.
- Contract creation also snapshots selected service-location contact/address/map fields.
- Profit reports use snapshots, not current product cost.
- Later WAC changes do not rewrite historical contract economics.
- Later service-location edits do not rewrite historical contract location data.
- Accounting depreciation and deep asset-consumption adjustments are deferred
  beyond Phase 6; device usage must be based on real activity when implemented,
  not on idle elapsed time.

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

## 4.6 Barcode, Serial, and Asset Identity

SKU, product barcode, and unit serial are separate identities.

- `products.sku` stays in the database as an internal product code for integrity and uniqueness.
- Normal product UI should generate SKU automatically and hide it from the user.
- `products.barcode` identifies the product type for sales, purchase entry, POS, and search.
- `product_units.serial_number` identifies one physical device.
- `products.is_serialized = true` is the explicit toggle for unit-level tracking; it is independent from `product_type`.
- Asset labels use QR codes whose payload is the human-readable serial text, not a raw UUID or opaque URL.
- Printed asset tags should include tenant/company name, product name, serial number, and QR code.

For serialized products, mutating RPCs must require a concrete `product_unit_id` whenever the operation affects one physical asset: contract assignment, return, maintenance, correction, and future serialized transfers. Missing unit identity is a validation error at the RPC boundary, not only a UI concern.

For serialized inventory, `product_units` is the identity and lifecycle source of truth. `inventory_balances` remains the aggregate stock cache and must be updated atomically by RPCs. Backfill tools that generate missing serials for existing stock must reconcile units without increasing stock again.

`product_units` is an asset lifecycle table, not only a serial-number table. RPCs should keep lifecycle state and current pointers in sync:

- purchase/creation -> available
- contract assignment -> rented or trial
- return -> available/maintenance as appropriate
- issue handling -> maintenance, damaged, lost, or retired
- `current_warehouse_id`, `current_customer_id`, `current_service_location_id`, and `current_contract_id` describe the current location/context

The canonical unit history is `v_unit_timeline`, built from source events such as purchases, inventory movements, contracts, visits, maintenance, audit log, and `unit_events`. Keep `unit_events` for manual events or notes without another natural source. If a maintained `last_event_at` is added, it is only an index/sorting helper and must be derived from event writes.

Barcode scanning is global infrastructure. The pattern is `scan -> resolve object -> open/apply in current context`, and it must support product search, unit lookup, contract device picking, visits, maintenance, inventory count, return/replacement, and POS later.

---

## 4.7 Document Templates and Printing

The canonical document-template representation is structured JSON, not FastReport, Crystal Reports, raw free-form HTML, or runtime AI generation.

- Store templates as JSON blocks/settings so they can be rendered, validated, versioned, and later edited safely.
- First renderer is Flutter client-side `pdf`/`printing` for A4 invoices, thermal receipts, statements, contracts, and asset labels.
- A later server/Edge renderer may archive or auto-send PDFs, but it must consume the same JSON template model.
- v1 template customization is tenant settings only: logo, colors, header/footer, language, paper size, and optional columns.
- A visual template editor is Phase 10+ and must be built on top of the same JSON model.

---

## 4.8 Service Location Coordinates and Maps

Operational coordinates live on `customer_service_locations.latitude` and `customer_service_locations.longitude`.

- Customer-level GPS columns are not part of the current model.
- `google_maps_url` is an input/source and convenience link, not the authoritative location.
- Future capture should store `resolution_source` such as `map_pick`, `device_gps`, `url`, or `manual`.
- Future capture should also store `resolved_at`, `coordinate_accuracy_m`, and optional `resolution_status`/`resolution_error`.
- Visit GPS matching uses a configurable radius and the recorded device accuracy.
- Outside-range visits should proceed with a required reason and be flagged for review, not silently pass or fail.
- The mobile "Directions" action opens the native maps app through `url_launcher`.
- The internal operations map is a later reusable map widget with typed layers, not a large generic map engine in early phases.

---

## 4.9 Phase 7 Hybrid Company Calendar and Actual Refill Cadence

Phase 7 is the company-wide appointment-management surface. Contract-generated
events and untimed manual events are date-based; an explicitly timed manual
event may optionally carry a same-day start/end window.

M7A implemented and owner-accepted this manual company-event contract on
2026-07-15 through migrations `098`/`099` and the typed Flutter calendar layer.
M7B working-date exceptions are implemented through migration `100` and are
**CLOSED / ACCEPTED** as of 2026-07-17 after automated and owner visual
acceptance (safe calendar projection of kind+titles only; settings-gated full
CRUD; exceptions override weekly resolve; events on closures are never
mutated).

The M7B settings list uses an explicit selected-year window, including while the
weekly schedule/timezone is unconfigured. Date exceptions remain authoritative
for the selected date in that state. Public M7B RPC execution is authenticated-
only, pagination reuses server-echoed bounds, and an active exception's kind is
editable through the versioned/idempotent update contract.

- `scheduled_date` remains canonical for every event. Legacy `scheduled_time`
  remains null/compatibility-only. M7A uses a reviewed optional start/end/
  timezone contract and never invents a time for generated or untimed events.
- Manual categories initially cover customer visits, internal meetings,
  tasks/reminders, internal activities/training, and custom events.
- Participants are separate from assignment/responsibility. Assigned-only
  visibility includes an employee's assignments or explicit participation.
- Holidays, company closures, and exceptional working days are date-specific
  working-calendar exceptions, not ordinary appointment events.
- Working days, working windows, and IANA timezone are configured explicitly by
  the owner/manager. No country, locale, weekend, timezone, or working-hours
  default is inferred.
- The system creates seven initially unreviewed weekday rows and keeps
  `working_schedule_configured = false` until a manager selects a valid IANA
  timezone and atomically reviews all seven days.
- The existing legacy `tenants.timezone = Asia/Kuwait` default is not proof of
  owner selection and cannot enable reminders without that explicit review.
- No working-hours-based reminder is created while settings are unconfigured.
- Initial in-app reminder policies are working-day start and previous-working-
  day start; each is independently configurable.
- Calendar Settings use dedicated `settings.calendar.view` and
  `settings.calendar.edit` permissions. Calendar event-view permissions do not
  imply settings access.
- A missed event stays pending and is derived/displayed as overdue, including
  `original_due_date` and overdue-day count, until trusted actual execution.
- Phase 7 plans and displays; Phase 8 records `actual_completion_date`, actual
  delivered quantity, confirmed coverage, and confirmed `next_due_date`.
- A refill cadence has one outstanding due event. No later refill is generated
  from the missed planned date while that event remains unexecuted.
- After execution, the next refill is anchored to actual completion plus
  confirmed coverage. Manual next-date override requires permission, reason,
  and audit.
- Billing cadence is financially independent from refill execution cadence.

The detailed source of truth is `PHASE_7_CALENDAR_PLAN.md`.

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
- Products, customers, trial contracts, rental contracts
- Basic invoices and vouchers
- Mobile refill flow with GPS and live photo
- Date-based calendar planning per section 4.9
- Basic reports: customer balance and contract list

Phase 2+:

- POS
- Full HR payroll and commissions
- WhatsApp campaigns
- Maintenance module
- Quotations
- Offline sync
- Full P&L reporting
