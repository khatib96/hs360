# Phase 4 - Customers, Suppliers & Chart of Accounts Plan

> Purpose: build the customer, supplier, and chart-of-accounts foundation that Phase 5 invoices/vouchers, Phase 6 contracts, and Phase 8 field operations will depend on.
> Created 2026-05-30 after inspecting the current Flutter, Supabase, docs, permissions, routing, RLS, and Phase 3 implementation patterns.

---

## Executive Summary

Do not implement Phase 4 in one large pass.

Phase 4 looks smaller than Phase 3, but it sits directly on the accounting boundary. It is not only customer CRUD. It touches:

- customer and supplier identity data.
- automatic customer/supplier codes.
- automatic A/R and A/P subaccounts in `chart_of_accounts`.
- customer ledger and statement surfaces.
- future contracts, invoices, vouchers, visits, and reports.
- sensitive accounting permissions.
- mobile and desktop workflows.

The safe approach is to implement Phase 4 as milestones: `M0` through `M8`. Each milestone should end with targeted tests and a clean acceptance check.

---

## Current Project Inspection Summary

### Confirmed Current State

- Phase 3 is complete per `ai_memory.md` and `docs/PHASE_3_PRODUCTS_INVENTORY_PLAN.md`.
- Products and inventory now have working domain/data/presentation layers, routing, permission guards, SQL verification, and tests.
- Existing app architecture is feature-based:
  - `lib/features/<feature>/domain`
  - `lib/features/<feature>/data`
  - `lib/features/<feature>/presentation`
- Existing repositories use Riverpod generated providers and keep Supabase access outside widgets.
- Existing route guards already include `customers.view` in office permissions, but no customer routes/screens are implemented yet.
- Existing navigation has Products, Warehouses, Inventory, Movements, and Transfers, but no Customers/Suppliers/CoA navigation entries yet.
- Existing localization files are already large and must be updated carefully in both AR and EN.

### Database Already Exists

Phase 1 already created:

- `chart_of_accounts`
- `customers`
- `suppliers`
- `journal_entries`
- `journal_lines`
- `invoices`
- `invoice_lines`
- `vouchers`
- `voucher_invoice_allocations`
- `contracts`
- `visits`

Key schema facts:

- `customers.account_id` is `not null` and references `chart_of_accounts`.
- `suppliers.account_id` is `not null` and references `chart_of_accounts`.
- `customers.code` is unique per tenant.
- `suppliers.code` is unique per tenant.
- `chart_of_accounts.code` is unique per tenant.
- `chart_of_accounts` supports hierarchy through `parent_id`.
- `chart_of_accounts` supports system rows and linked entity subaccounts through:
  - `is_system`
  - `is_subaccount`
  - `related_entity_table`
  - `related_entity_id`

### Permissions Already Exist

Seeded permissions include:

- `customers.view`
- `customers.create`
- `customers.edit`
- `customers.delete`
- `customers.view_ledger`
- `suppliers.view`
- `suppliers.create`
- `suppliers.edit`
- `suppliers.delete`
- `chart_of_accounts.view`
- `chart_of_accounts.create`
- `chart_of_accounts.edit`
- `chart_of_accounts.delete`
- `journal.view`
- `invoices.view`
- `vouchers.view`
- `contracts.view`

### RLS Already Exists

Existing RLS policies allow tenant-scoped access based on the permissions above.

Important gap: direct `customers_insert` and `suppliers_insert` currently allow a user with create permission to insert rows if they provide an `account_id`. Phase 4 should make RPCs the canonical create path so account creation and customer/supplier creation happen atomically.

### Existing Gaps Phase 4 Must Close

- No customer/supplier Flutter feature exists yet.
- No chart-of-accounts Flutter feature exists yet.
- No customer/supplier repositories or validators exist yet.
- No customer/supplier route constants or GoRouter routes exist yet.
- No customer/supplier navigation entries exist yet.
- No RPC exists for:
  - generating `CUST-0001`.
  - generating `SUP-0001`.
  - creating A/R subaccount automatically.
  - creating A/P subaccount automatically.
  - preventing client-controlled `account_id` creation.
- No Phase 4 SQL test exists.
- Customer ledger/statement views or RPCs are not implemented yet.
- Audit triggers currently cover products, product units, contracts, invoices, vouchers, journal, inventory movements, tenant users, permissions, and settings. Customers, suppliers, and CoA need explicit Phase 4 audit coverage for create/update/deactivate/account changes.
- `BUILD_PLAN.md` top progress overview is stale for Phase 2/3 even though later sections and `ai_memory.md` show Phase 3 complete. Update it during Phase 4 M0 documentation cleanup.

---

## Phase 4 Scope

### In Scope

1. Customer list, search, filters, create, edit, deactivate.
2. Supplier list, search, filters, create, edit, deactivate.
3. Automatic customer code generation: `CUST-0001`, `CUST-0002`, ...
4. Automatic supplier code generation: `SUP-0001`, `SUP-0002`, ...
5. Automatic A/R subaccount creation when a customer is created.
6. Automatic A/P subaccount creation when a supplier is created.
7. CoA tree view with hierarchy.
8. CoA add/edit/deactivate for non-system accounts.
9. Protect system accounts and entity-linked subaccounts from unsafe edits.
10. Customer detail screen with:
    - profile.
    - contracts tab.
    - invoices tab.
    - vouchers tab.
    - statement/ledger tab.
    - timeline tab.
11. Empty-safe customer statement before Phase 5 data exists.
12. Permission-aware routes and navigation.
13. Responsive desktop/mobile layouts for customers and suppliers.
14. SQL, domain, repository, route, and widget tests.
15. Phase close verification.

### Out of Scope

Do not build these in Phase 4:

- creating invoices.
- creating vouchers.
- journal posting RPCs.
- opening balance invoices.
- contract creation.
- visit workflows.
- PDF generation.
- WhatsApp/email sending.
- two-way customer messaging.
- full reports or aging dashboards.
- POS.
- HR.
- offline mobile sync.

Phase 4 may show empty or read-only tabs that will later be populated by Phase 5, Phase 6, and Phase 8.

---

## Accounting And Data Decisions

1. Customer balance is never stored on `customers`.
2. Customer balance comes from journal lines linked to the customer's A/R account.
3. Supplier balance is never stored on `suppliers`.
4. Supplier balance comes from journal lines linked to the supplier's A/P account.
5. The UI must not ask the user to choose `account_id` when creating a customer or supplier.
6. Customer/supplier creation must call RPCs, not direct table inserts.
7. Customer code and supplier code are generated in the database transaction.
8. Related subaccount code should be generated from the parent account sequence:
   - customer A/R example: parent `1201` -> subaccount `1201.0001`.
   - supplier A/P example: parent `2101` -> subaccount `2101.0001`.
9. `chart_of_accounts.related_entity_table` must be:
   - `customers` for customer subaccounts.
   - `suppliers` for supplier subaccounts.
10. `chart_of_accounts.related_entity_id` must point to the created customer/supplier row.
11. Entity-linked accounts should not be manually deleted.
12. Deactivate instead of hard delete for customers/suppliers/CoA rows in normal UI.
13. System CoA rows must not be deleted. Default Phase 4 rule: system CoA rows are read-only from the UI.
14. Money values remain `numeric(15,3)` in Postgres and `Decimal` in Dart.
15. Widgets must not call Supabase directly.

---

## Milestone Plan

| Milestone | Name | Result |
|---|---|---|
| M0 | Phase 4 Baseline | Confirm Phase 3 is clean and document the exact starting point |
| M0.5 | Safety Snapshot & Rollback | Backup/schema snapshot before migrations |
| M1 | DB Gap Review & Accounting Rules | Finalize RPC, account-code, ledger, and audit rules |
| M2 | Database RPCs, Views & SQL Tests | Atomic create/update/deactivate paths and Phase 4 SQL verification |
| M3 | Domain Models, Validators & Repositories | Testable Dart layer with no UI business rules |
| M4 | Routes, Guards, Navigation & Localization | App can route to Phase 4 modules with correct permissions |
| M5 | Customers & Suppliers Lists/Forms | Operational customer/supplier CRUD on desktop/mobile |
| M6 | Customer Detail, Statement & Timeline | Customer 360 shell works, empty-safe before Phase 5 |
| M7 | Chart Of Accounts Tree | CoA hierarchy view and safe non-system account editing |
| M7.5 | Hardening, Performance & UX Pass | Search, pagination, file size, permission edge cases |
| M8 | Verification & Phase Close | Tests, SQL verification, manual acceptance, docs close |

---

## M0 - Phase 4 Baseline

### Goal

Prove the current project is stable before Phase 4 changes begin.

### Work

1. Check git state:

   ```powershell
   git status --short
   ```

2. Confirm Phase 3 close files exist:

   ```powershell
   Get-Content ai_memory.md
   Get-Content docs\PHASE_3_PRODUCTS_INVENTORY_PLAN.md
   ```

3. Run Flutter checks:

   ```powershell
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   flutter analyze
   flutter test
   ```

4. Run database checks when local Supabase is available:

   ```powershell
   npx --yes supabase status
   docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_1d_rls.sql
   docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_3_products_inventory.sql
   ```

5. Update stale progress references in `docs/BUILD_PLAN.md` if needed.

### Acceptance

- Phase 3 tests still pass.
- No unrelated dirty work is mixed into Phase 4.
- Known Supabase CLI reset issue from Phase 3 M8 is documented if it still exists.

---

## M0.5 - Safety Snapshot & Rollback

### Goal

Create a clear rollback point before adding Phase 4 migrations.

### Work

1. Capture current migration list.
2. Capture schema snapshot if local DB is running.
3. Record rollback notes in the Phase 4 implementation log or `ai_memory.md` if the session pauses.
4. Do not wipe useful local data unless explicitly intended.

### Acceptance

- We know the last migration before Phase 4.
- We know what new migration number Phase 4 starts with. Current expected next migration: `045`.
- Rollback path is clear before changing database behavior.

---

## M1 - DB Gap Review & Accounting Rules

### Goal

Lock the data and accounting rules before UI work.

### Confirmed Findings (verified against migrations)

These were confirmed by inspecting `010`, `016`, `017`, `018`, `026`, `027`, `029`, `030`, `031` and enums (`003`).

- Seeded parent accounts (`031_seed.sql`): A/R is `1201` "Accounts receivable" (`asset`), A/P is `2101` "Accounts payable" (`liability`). Both are seeded with `is_system = true`.
- The seed creates `1201`/`2101` for tenant A only. Tenant B has only `1101`. There is no column flagging "this is the A/R/A/P parent"; the only stable handle is `(tenant_id, code)`.
- `customers.account_id` and `suppliers.account_id` are `not null` FKs to `chart_of_accounts`; both tables enforce `unique (tenant_id, code)`. `chart_of_accounts` enforces `unique (tenant_id, code)`.
- `chart_of_accounts` already has `parent_id`, `is_subaccount`, `is_system`, `related_entity_table`, `related_entity_id`, `is_active`. No `updated_at` column.
- Current RLS (`030`) lets any user with `customers.create` / `suppliers.create` directly `INSERT` a row **with a client-supplied `account_id`**, and `*_update` lets `*.edit` users change any column including `account_id`/`code`/`tenant_id`. This is the gap M2 must close (mirrors the M6 pattern in `040` that dropped direct `product_units` insert/update/delete).
- `chart_of_accounts_delete` already blocks system rows (`and not is_system`) but **does not** block entity-linked subaccounts (those are `is_system = false`), and `chart_of_accounts_update` has no protection for system or linked rows.
- `audit_log_row()` (`029`) is generic and tenant-aware; there are currently **no** audit triggers on `customers`, `suppliers`, or `chart_of_accounts`. `trg_touch_customers` exists; `suppliers` has no `updated_at`.
- `journal_lines` (`018`) is indexed on `journal_entry_id` only. There is **no** index on `account_id`, which the customer statement RPC will filter on.
- Last migration is `044`; Phase 4 starts at `045`. Helpers available: `current_tenant_id()`, `current_account_type()`, `is_manager()`, `user_has_permission(text)`.

### M1 Locked Decisions

1. **Customer creation = RPC only.** `create_customer(...)` (security definer). Drop the `customers_insert` RLS policy so direct inserts are impossible.
2. **Supplier creation = RPC only.** `create_supplier(...)` (security definer). Drop the `suppliers_insert` RLS policy.
3. **Client never sends `tenant_id` or `account_id`.** RPCs derive `tenant_id` from `current_tenant_id()` and create the account server-side. Any client-supplied account/tenant is ignored/rejected.
4. **Customer code:** `CUST-0001`, `CUST-0002`, ... zero-padded to 4 digits, per tenant, generated inside the RPC transaction. Rely on `unique (tenant_id, code)` as the hard guard; lock the parent A/R row `FOR UPDATE` (or use `pg_advisory_xact_lock`) to serialize numbering and avoid races.
5. **Supplier code:** `SUP-0001`, `SUP-0002`, ... same rules as customers.
6. **Customer A/R subaccount** is created automatically under the tenant's A/R parent, in the same transaction, and linked via `customers.account_id`.
7. **Supplier A/P subaccount** is created automatically under the tenant's A/P parent, in the same transaction, and linked via `suppliers.account_id`.
8. **Parent account codes are confirmed: A/R = `1201`, A/P = `2101`.** RPCs resolve the parent by `(tenant_id, code)` = `1201` / `2101`. If the parent is missing for the tenant, the RPC raises a clear error (`ar_parent_missing` / `ap_parent_missing`) rather than guessing. **Gap to close:** tenant onboarding/seed must guarantee every tenant has `1201` and `2101` before any customer/supplier is created (today only tenant A does).
9. **Linked subaccount code format:** `<parent_code>.NNNN`, zero-padded to 4 digits, e.g. `1201.0001`, `2101.0001`. Sequence is derived per parent from existing subaccounts of that parent within the tenant. New subaccount inherits the parent's `type` (`asset` for A/R, `liability` for A/P), sets `parent_id = parent`, `is_subaccount = true`, `is_system = false`, `related_entity_table = 'customers'|'suppliers'`, `related_entity_id = <entity id>`, `is_active = true`.
10. **Immutable after creation** (enforced by `BEFORE UPDATE` guard triggers, not just UI): on `customers`/`suppliers` → `tenant_id`, generated `code`, `account_id`; on `chart_of_accounts` → `tenant_id`, `related_entity_table`, `related_entity_id`, and the generated subaccount `code`. Profile fields (name, phone, etc.) remain editable via `update_customer` / `update_supplier`.
11. **Deactivation, not hard delete.** UI path sets `is_active = false` via `deactivate_customer` / `deactivate_supplier`. Deactivating an entity does **not** delete or deactivate its linked A/R/A/P account (the account may carry balances and is needed for the ledger). Hard delete stays unavailable from the app.
12. **CoA protections** (enforced in RLS + guard trigger):
    - System rows (`is_system = true`) are read-only: no manual update, deactivate, or delete.
    - Entity-linked rows (`related_entity_id is not null`) cannot be manually deleted or deactivated (extend the delete policy with `and related_entity_id is null`; block `is_active` flips in the trigger).
    - `type` cannot change if the account has child accounts or any `journal_lines`.
    - Manual non-system, non-linked accounts remain fully create/edit/deactivate-able with the right permission.
13. **Customer statement access** is via security-definer RPCs (`get_customer_statement`, `get_customer_balance_summary`) gated on `customers.view_ledger`. They read `journal_lines` internally so the caller does **not** need raw `journal.view`. Raw `journal_entries` / `journal_lines` tables stay gated on `journal.view`.
14. **Audit additions** (reuse `audit_log_row()`): `customers` (insert, delete, update when key/contact/`is_active`/`account_id` change), `suppliers` (insert, delete, update), `chart_of_accounts` (insert, delete, update when `is_active`/`type`/`name_*` change). Account auto-creation inside the create RPC is captured by the `chart_of_accounts` insert trigger.
15. **M2 deliverables are fixed** (see task list below): migration `045_customers_suppliers_coa_rpc.sql` and test `phase_4_customers_suppliers_coa.sql`.

### Exact M2 Implementation Tasks

In `supabase/migrations/045_customers_suppliers_coa_rpc.sql`:

1. Helper `get_or_resolve_entity_parent_account(p_kind)` (or inline) that returns the tenant's `1201`/`2101` row id, raising `ar_parent_missing`/`ap_parent_missing` if absent.
2. Helper to generate the next entity code (`CUST-`/`SUP-`) and the next `<parent_code>.NNNN` subaccount code, race-safe.
3. `create_customer(...)` and `create_supplier(...)`: validate tenant + permission, generate codes, insert linked subaccount + entity atomically, return new id. Ignore any client `tenant_id`/`account_id`.
4. `update_customer(...)` / `update_supplier(...)`: mutable profile fields only.
5. `deactivate_customer(...)` / `deactivate_supplier(...)`: set `is_active = false`; leave linked account intact.
6. `create_chart_account(...)` / `update_chart_account(...)` / `deactivate_chart_account(...)`: manual non-system, non-linked accounts only.
7. `get_customer_statement(...)` / `get_customer_balance_summary(...)`: `customers.view_ledger`-gated, empty-safe, no `journal.view` requirement.
8. `BEFORE UPDATE` guard triggers: `enforce_customer_immutable_columns`, `enforce_supplier_immutable_columns`, `enforce_chart_account_protection` (system read-only, linked no-deactivate/delete, type-change guard, immutable cols).
9. RLS changes: drop `customers_insert`, `suppliers_insert`; extend `chart_of_accounts_delete` with `and related_entity_id is null`; decide direct `*_update` policy stays only as a backstop behind the immutable triggers (RPCs are security definer).
10. Audit triggers for `customers`, `suppliers`, `chart_of_accounts` per decision 14.
11. Add index `idx_jlines_account on journal_lines (tenant_id, account_id)` for statement performance.
12. `revoke all ... from public; grant execute ... to authenticated;` on every new RPC (match `040`).

In `supabase/tests/phase_4_customers_suppliers_coa.sql`: the case list already in M2 below, plus: `ar_parent_missing`/`ap_parent_missing` raised when parent absent; immutable-column update rejected; system/linked CoA update+deactivate rejected; `type` change rejected when children/journal lines exist.

### Acceptance

- All M1 decisions above are locked; no UI work begins before M2 implements them.
- RPC names, code formats (`CUST-NNNN`, `SUP-NNNN`, `<parent_code>.NNNN`), and the `1201`/`2101` parent resolution are fixed.
- Permission boundaries (`customers.view_ledger` vs `journal.view`) and CoA/entity protections are documented.
- The tenant-onboarding A/R/A/P parent gap is recorded as a prerequisite for M2.

---

## M2 - Database RPCs, Views & SQL Tests

### Goal

Build the safe database write/read layer for Phase 4.

### Suggested Migration

```text
supabase/migrations/045_customers_suppliers_coa_rpc.sql
```

### RPCs

Create RPCs like:

```sql
create_customer(...)
update_customer(...)
deactivate_customer(...)
create_supplier(...)
update_supplier(...)
deactivate_supplier(...)
create_chart_account(...)
update_chart_account(...)
deactivate_chart_account(...)
get_customer_statement(...)
get_customer_balance_summary(...)
list_customer_timeline(...)
```

Exact signatures should be chosen during implementation, but the rules are fixed:

- RPC validates `current_tenant_id()`.
- RPC checks `user_has_permission(...)`.
- RPC generates codes server-side.
- RPC inserts account and entity in one transaction.
- RPC never trusts a client-supplied tenant id.
- RPC does not expose raw journal data without `customers.view_ledger`.
- RPC prevents unsafe edits to system or linked accounts.

### Views Or RPCs For Ledger

Prefer RPCs for customer statement and balance because raw journal tables are protected by `journal.view`. Customer ledger should use `customers.view_ledger`, not raw journal access.

For Phase 4, the ledger can be empty. The important requirement is that it returns a valid empty result and does not crash.

### SQL Test

Create:

```text
supabase/tests/phase_4_customers_suppliers_coa.sql
```

Test cases:

- manager can create customer through RPC.
- customer receives `CUST-0001` style code.
- customer receives linked A/R subaccount.
- customer `account_id` points to the created subaccount.
- supplier receives `SUP-0001` style code.
- supplier receives linked A/P subaccount.
- tenant isolation is preserved.
- zero-permission user cannot create/view customers.
- user with `customers.create` can create only through intended path.
- user without `customers.view_ledger` cannot read statement.
- user with `customers.view_ledger` can read empty statement.
- CoA system accounts cannot be deleted.
- non-system manual CoA account can be created/edited/deactivated.
- linked customer/supplier accounts cannot be manually deleted.

### Acceptance

- All Phase 4 SQL tests pass.
- Phase 1D RLS tests still pass.
- Phase 3 inventory tests still pass.
- No Phase 5 invoice/voucher behavior is implemented here.

---

## M3 - Domain Models, Validators & Repositories

### Goal

Create testable Dart logic before UI.

### Suggested Files

```text
lib/core/errors/customer_exception.dart
lib/core/errors/supplier_exception.dart
lib/core/errors/accounting_exception.dart

lib/domain/validators/customer_validator.dart
lib/domain/validators/supplier_validator.dart
lib/domain/validators/chart_account_validator.dart

lib/features/customers/domain/customer.dart
lib/features/customers/domain/customer_type.dart
lib/features/customers/domain/customer_form_state.dart
lib/features/customers/domain/customer_filters.dart
lib/features/customers/domain/customer_statement_row.dart
lib/features/customers/domain/customer_timeline_event.dart

lib/features/customers/data/customer_repository.dart

lib/features/suppliers/domain/supplier.dart
lib/features/suppliers/domain/supplier_form_state.dart
lib/features/suppliers/domain/supplier_filters.dart
lib/features/suppliers/data/supplier_repository.dart

lib/features/accounting/domain/chart_account.dart
lib/features/accounting/domain/account_type.dart
lib/features/accounting/domain/chart_account_tree.dart
lib/features/accounting/domain/chart_account_form_state.dart
lib/features/accounting/data/chart_account_repository.dart
```

### Rules

- Repositories own Supabase/RPC calls.
- Validators own field rules.
- Domain models parse rows.
- Controllers orchestrate loading/saving.
- Widgets render only.
- Use `Decimal` for money and balances.
- Keep generated providers consistent with Phase 3 patterns.

### Tests

```text
test/domain/validators/customer_validator_test.dart
test/domain/validators/supplier_validator_test.dart
test/domain/validators/chart_account_validator_test.dart
test/features/customers/domain/customer_code_test.dart
test/features/accounting/domain/chart_account_tree_test.dart
```

### Acceptance

- Domain tests pass.
- Repository APIs are ready for UI.
- No widget directly calls Supabase.

---

## M4 - Routes, Guards, Navigation & Localization

### Goal

Open Phase 4 modules in the app safely.

### Routes

Add:

```text
/customers
/customers/:id
/customers/:id/edit
/suppliers
/suppliers/:id
/accounts
```

Implementation can choose whether suppliers are a tab under `/customers` or a separate route. The navigation brief prefers one "Customers" area with tabs for Customers and Suppliers. Recommended:

- sidebar item: `/customers`.
- `/customers` screen contains Customers/Suppliers tabs.
- `/suppliers` may exist as an internal direct route only if useful.

### Guard Rules

- `/customers` requires `customers.view` or `suppliers.view`.
- `/customers/:id` requires `customers.view`.
- `/customers/:id/edit` requires `customers.view` and `customers.edit`.
- supplier tab/list requires `suppliers.view`.
- `/accounts` requires `chart_of_accounts.view`.
- create actions require create permissions.
- edit/deactivate actions require edit/delete permissions.

### Navigation

Add visible items:

- Customers: visible if `customers.view` or `suppliers.view`.
- Chart of Accounts: visible if `chart_of_accounts.view`.

### Localization

Add AR/EN strings for:

- customers.
- suppliers.
- customer detail tabs.
- statement.
- timeline.
- chart of accounts.
- validation and error messages.
- empty/loading/error states.

### Tests

- route guard tests for Phase 4 routes.
- app shell permission tests for new navigation items.
- localization generation check through normal Flutter build/test flow.

### Acceptance

- Manager can navigate to customers and CoA.
- User without permission is redirected/blocked.
- Navigation does not show unauthorized modules.
- Arabic/English strings exist for user-facing text.

---

## M5 - Customers & Suppliers Lists/Forms

### Goal

Make customer and supplier management usable.

### Customer List

Required:

- search by code, Arabic name, English name, phone, WhatsApp, email.
- filters:
  - active/inactive.
  - VIP.
  - customer type: individual/company.
  - area/city if useful.
- columns:
  - code.
  - name.
  - phone.
  - WhatsApp.
  - area/city.
  - payment terms.
  - credit limit.
  - status.
- actions:
  - view.
  - edit if allowed.
  - deactivate if allowed.
  - create if allowed.

### Customer Form

Required fields:

- `customer_type`.
- `name_ar`.
- `phone_primary`.

Optional fields:

- `name_en`.
- contact person fields.
- phone secondary.
- WhatsApp.
- email.
- address, area, city, country.
- GPS lat/lng.
- payment terms.
- credit limit.
- VIP flag.
- notes.
- acquired_by/acquired_at if employee data is available.

Rules:

- code is generated, not editable.
- account is generated, not editable.
- phone validation is practical, not over-strict.
- GPS values must be valid if entered.
- credit limit cannot be negative.
- payment terms cannot be negative.

### Supplier List/Form

Required:

- search by code, name, phone, email.
- active/inactive filter.
- create/edit/deactivate.
- generated supplier code.
- generated A/P subaccount.

Supplier form fields:

- `name_ar` required.
- `name_en` optional.
- `phone` optional.
- `email` optional.
- `address` optional.

### Responsive UX

- Desktop: table-first, dense, operational layout.
- Mobile: list cards with primary contact actions.
- No marketing/landing-page UI.
- No card-in-card layouts.
- Keep text inside controls from overflowing.

### Tests

- customer list empty/error/loading.
- customer form validation.
- create button hidden without permission.
- supplier list empty/error/loading.
- supplier form validation.
- repository/controller state transitions.

### Acceptance

- Create customer -> appears in list.
- Edit customer -> changes persist.
- Deactivate customer -> no longer appears in active-only view.
- Create supplier -> appears in supplier list.
- User without create permission cannot create.
- Generated codes/account IDs are visible but not editable.

---

## M6 - Customer Detail, Statement & Timeline

### Goal

Create the Customer 360 shell that later phases will populate.

### Detail Header

Show:

- code.
- Arabic/English display name.
- customer type.
- active/VIP status.
- primary phone.
- WhatsApp.
- email.
- location summary.
- payment terms.
- credit limit.
- linked A/R account.

### Tabs

Use in-screen tabs:

- Profile.
- Contracts.
- Invoices.
- Vouchers.
- Statement.
- Timeline.

### Phase 4 Behavior

- Profile tab is fully functional.
- Contracts tab is read-only and may be empty until Phase 6.
- Invoices tab is read-only and may be empty until Phase 5.
- Vouchers tab is read-only and may be empty until Phase 5.
- Statement tab uses `customers.view_ledger` and returns empty safely before journal entries exist.
- Timeline tab combines available events only; empty state is acceptable.

### Out Of Scope Inside M6

- no invoice creation.
- no voucher creation.
- no contract creation.
- no PDF statement export.
- no WhatsApp send.

### Tests

- customer detail not found.
- tabs render.
- statement permission denied state.
- empty statement does not error.
- future data tabs show permission-aware empty states.

### Acceptance

- Open customer detail from list.
- Customer profile is readable.
- Statement tab opens without error for permitted user.
- Unauthorized user cannot view ledger/statement.
- Empty future tabs do not look broken.

---

## M7 - Chart Of Accounts Tree

### Goal

Make CoA visible and safely customizable.

### CoA Tree

Required:

- hierarchical display from `parent_id`.
- search by code/name.
- filter by account type.
- filter active/inactive.
- badge for:
  - system account.
  - customer subaccount.
  - supplier subaccount.
  - inactive.
- expand/collapse tree.

### Account Actions

Allowed:

- create non-system manual account.
- edit non-system manual account.
- deactivate non-system manual account.

Blocked:

- delete/deactivate system account if unsafe.
- delete/deactivate linked customer/supplier account manually.
- change account `type` if child accounts or journal lines exist.
- change `tenant_id`.
- change `related_entity_*` from UI.

### Accounting Rules

- Parent and child account types should be compatible unless explicitly allowed.
- Leaf/manual account creation should require `chart_of_accounts.create`.
- Editing should require `chart_of_accounts.edit`.
- Deactivation should require `chart_of_accounts.delete` or a dedicated delete/deactivate rule if implemented.

### Tests

- tree builder handles parent/child ordering.
- orphan accounts are handled gracefully.
- system account edit/deactivate is blocked.
- linked account edit/deactivate is blocked.
- permission-gated actions are hidden.

### Acceptance

- Manager sees the CoA tree.
- User with view permission sees read-only tree.
- Non-system manual account can be created and edited.
- System and linked accounts are protected.
- Customer-created A/R subaccounts appear under A/R.
- Supplier-created A/P subaccounts appear under A/P.

---

## M7.5 - Hardening, Performance & UX Pass

### Goal

Make Phase 4 robust with realistic data and edge cases.

### Work

1. Add local performance seed if needed:
   - 200 customers.
   - 50 suppliers.
   - 300 CoA rows.
2. Confirm list queries are bounded/paginated.
3. Review indexes:
   - `customers(tenant_id, phone_primary)` exists.
   - `customers(tenant_id, code)` unique exists.
   - `suppliers(tenant_id, code)` unique exists.
   - consider supplier phone/email indexes only if query plans justify them.
   - consider customer search indexes only if needed.
4. Check file sizes.
5. Check no widgets call Supabase.
6. Check Arabic/English text.
7. Check mobile layouts for:
   - customers list.
   - customer detail.
   - supplier list.
   - CoA tree.
8. Check permission edge cases:
   - customer-only user.
   - supplier-only user.
   - CoA read-only user.
   - ledger-denied user.
   - zero-permission user.

### Acceptance

- Lists remain usable with realistic data.
- No unbounded customer/supplier/timeline query.
- No large handwritten file is left unexplained.
- Responsive layouts remain readable.

---

## M8 - Verification & Phase Close

### Goal

Prove Phase 4 is complete and safe for Phase 5.

### Required Commands

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
git diff --check
```

Database verification when local Supabase is available:

```powershell
npx --yes supabase status
npx --yes supabase db reset
docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_1d_rls.sql
docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_3_products_inventory.sql
docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_4_customers_suppliers_coa.sql
```

If `supabase db reset` is still blocked by the known local CLI issue, document it and run the SQL verification against the migrated local database.

### Manual Acceptance Matrix

| Done | Case | Expected |
|---|---|---|
| [ ] | Manager opens Customers | customer/supplier area visible |
| [ ] | User with `customers.view` opens Customers tab | customers visible |
| [ ] | User with `suppliers.view` opens Suppliers tab | suppliers visible |
| [ ] | Zero user opens Customers | blocked/redirected |
| [ ] | Create customer | customer row and A/R subaccount created atomically |
| [ ] | Create supplier | supplier row and A/P subaccount created atomically |
| [ ] | Customer detail Statement tab with permission | opens, empty-safe |
| [ ] | Customer detail Statement tab without permission | denied state |
| [ ] | Customer created account appears in CoA tree | under A/R parent |
| [ ] | Supplier created account appears in CoA tree | under A/P parent |
| [ ] | System CoA account edit/deactivate | blocked |
| [ ] | Non-system CoA account edit | allowed with permission |
| [ ] | Arabic/English switch | Phase 4 screens remain readable |
| [ ] | Mobile width | lists and forms remain usable |

### Quality Checklist

- [ ] No widget calls Supabase directly.
- [ ] No money uses `double`.
- [ ] Permission checks use `AppPermissions`.
- [ ] Customer/supplier creation uses RPCs.
- [ ] Customer/supplier `account_id` is not client-selected.
- [ ] Customer statement uses `customers.view_ledger`, not raw journal access.
- [ ] CoA system rows are protected.
- [ ] Entity-linked accounts are protected.
- [ ] Customer/supplier/CoA changes are audited where required.
- [ ] Queries are bounded or paginated.
- [ ] Arabic and English strings exist.
- [ ] File-size scan reviewed.

### Phase 4 Done Means

- Customers can be created, listed, viewed, edited, and deactivated.
- Suppliers can be created, listed, edited, and deactivated.
- Customer and supplier codes are generated consistently.
- Customer A/R and supplier A/P subaccounts are created automatically.
- CoA is visible as a tree and safe to customize.
- Customer detail is ready for contracts, invoices, vouchers, and statements.
- Ledger/statement surfaces are empty-safe before Phase 5.
- Phase 5 can build invoices/vouchers on a reliable customer/supplier/account foundation.
- Phase 6 can require customer selection confidently.
- Phase 8 can search/view customers on mobile later without redesigning the data layer.

---

## Suggested Implementation Chunks

| Chunk | Milestones | Why |
|---|---|---|
| Chunk 1 | M0 + M0.5 + M1 | establish clean baseline and accounting decisions |
| Chunk 2 | M2 | database RPCs/views/tests before Flutter UI |
| Chunk 3 | M3 + M4 | Dart data layer, routing, permissions, localization |
| Chunk 4 | M5 | customer/supplier operational UI |
| Chunk 5 | M6 | customer 360 shell and empty-safe ledger |
| Chunk 6 | M7 | chart of accounts tree and account safeguards |
| Chunk 7 | M7.5 + M8 | hardening and phase close |

Every chunk should end with:

```powershell
flutter analyze
flutter test
```

If the chunk changes Supabase:

```powershell
docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_4_customers_suppliers_coa.sql
```

---

## Why These Milestones Matter

### Why M0/M0.5?

Phase 4 changes accounting-facing data. A clean baseline and rollback point prevent us from mixing customer/account bugs with old Phase 3 state.

### Why M1 Before UI?

The hardest Phase 4 decision is not the screen. It is whether customer/supplier creation is accounting-safe. If account creation is not atomic, Phase 5 will inherit broken invoices and statements.

### Why M2 Before Flutter?

The database must own generated codes, tenant isolation, account creation, and ledger access. Flutter can validate and preview, but it should not decide accounting identity.

### Why M3?

The UI needs a clean repository/domain layer. Phase 3 already proved this pattern works.

### Why M4?

Permissions and routes must be correct before screens are useful. A screen that works only for manager is not enough.

### Why M5?

Customers and suppliers are daily operational data. Lists and forms must be efficient, searchable, and permission-aware.

### Why M6?

Customer detail is the bridge to contracts, invoices, vouchers, visits, and statements. Building the shell now prevents Phase 5/6 from inventing separate customer views.

### Why M7?

CoA is the accounting backbone. Users need visibility, but system and linked accounts must be protected.

### Why M8?

Phase close means the database rules, UI, permissions, localization, tests, and future-phase handoff are all verified.

---

## Starting Point For Next Coding Session

Start with M0.

If M0 passes, do M0.5 and M1 in the same session. Do not start customer screens until the RPC/accounting decisions in M1 are fixed and the M2 database layer is planned.

The first implementation target after this plan should be:

```text
supabase/migrations/045_customers_suppliers_coa_rpc.sql
supabase/tests/phase_4_customers_suppliers_coa.sql
```

After M2 passes, move to Dart domain/repositories and only then build UI.
