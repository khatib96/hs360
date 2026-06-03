# ai_memory.md - AI Collaboration Memory

> Updated 2026-06-04 (Phase 4 M7.5 CoA hierarchy + Arabic repair complete).

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0-M8).
- **Phase 3 complete** - products and inventory (M0-M8).
- **Phase 4 M0-M3 complete** - DB RPCs, domain models, validators, repositories for customers, suppliers, chart of accounts.
- **Phase 4 M4 complete** - routes, guards, AppShell navigation, AR/EN l10n, placeholder screens.
- **Phase 4 M5 complete** - customer/supplier lists, filters, and create/edit/deactivate forms.
- **Phase 4 M5.5 complete** - profile field cleanup (DB `046`), optional `create_account`, `ensure_*_account`, Kuwait location catalog, responsive sectioned forms, governorate/area filters.
- **Phase 4 M5.6 complete** - `047_customer_service_locations.sql`, composite FKs, location RPCs, customer detail **Locations** tab.
- **Phase 4 M6 complete** - Customer 360 shell at [`customer_detail_screen.dart`](lib/features/customers/presentation/customer_detail_screen.dart): Profile, Locations, Contracts/Invoices/Vouchers placeholders, Statement (`customers.view_ledger` RPCs), Timeline (local metadata only).
- **Phase 4 M7 complete** - Chart of Accounts tree at [`chart_of_accounts_screen.dart`](lib/features/accounting/presentation/chart_of_accounts_screen.dart); migration [`048`](supabase/migrations/048_chart_accounts_m7_hardening.sql); single-fetch tree, policy-driven badges/actions, setup banner, manual CRUD dialogs.
- **Phase 4 M7.5 complete** - CoA hierarchy + Arabic repair via [`049`](supabase/migrations/049_chart_accounts_hierarchy_and_arabic_repair.sql): 5 protected category roots (`1000`–`5000` incl. Equity), system leaves reparented, Arabic repaired with transport-safe `U&` escapes, duplicate-code pre-check, targeted protection-trigger disable only.
- Migrations `001`-`049` on local Postgres; `npx --yes supabase db reset` remains avoided/blocked by Supabase CLI 2.102 internal service migration duplicate.
- **Canonical inventory rules:** [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md)
- **Capability decisions:** [`docs/CAPABILITIES_DECISION_REPORT.md`](docs/CAPABILITIES_DECISION_REPORT.md) + [`docs/CANONICAL_DECISIONS.md`](docs/CANONICAL_DECISIONS.md) now fix Barcode/Serial, JSON print templates, service-location coordinates, and Phase 5 Tax Foundation placement.
- **Next:** Phase 5 or further CoA UX polish as needed.

---

## Phase 4 M7.5 - CoA Hierarchy & Arabic Repair (done)

- **Migration:** [`049_chart_accounts_hierarchy_and_arabic_repair.sql`](supabase/migrations/049_chart_accounts_hierarchy_and_arabic_repair.sql) — fail-fast `duplicate_chart_account_codes`; idempotent `unique (tenant_id, code)`; disable only `trg_enforce_chart_account_protection` (audit/FK stay live); insert roots `1000/2000/3000/4000/5000` (`is_system`); reparent `1101`–`6101`; repair `name_ar` via `U&` escapes.
- **Root cause:** flat tree = seed had no `parent_id`/category roots; Arabic `???` = PowerShell `psql <` encoding when piping UTF-8 migrations (not bad file bytes).
- **Flutter:** category roots auto-expand on first fetch in [`chart_account_list_controller.dart`](lib/features/accounting/presentation/chart_account_list_controller.dart).
- **Tests:** SQL cases 44–47 in [`phase_4_customers_suppliers_coa.sql`](supabase/tests/phase_4_customers_suppliers_coa.sql); Dart tree/protection/screen tests extended.
- **Verification:** `flutter analyze`, `flutter test` (353 tests) green; migration 049 + phase_4 SQL passed on `supabase_db_hs360`; tenant A hierarchy confirmed (`1101`→`1000`, etc.) with correct Arabic in PostgreSQL.

---

## Phase 4 M7 - Chart of Accounts Tree (done)

- **Screen:** [`chart_of_accounts_screen.dart`](lib/features/accounting/presentation/chart_of_accounts_screen.dart) replaces placeholder; route `/accounts` unchanged.
- **DB:** [`048_chart_accounts_m7_hardening.sql`](supabase/migrations/048_chart_accounts_m7_hardening.sql) — RPC rejects immutable payload keys, entity-linked parent on create, `parent_type_mismatch`, `account_has_active_children`; trigger backstop on deactivate with active children.
- **Domain:** `detectAccountingSetupIssues`, `filterAccountsForTree` (ancestors from `allAccounts`), [`chart_account_policy.dart`](lib/features/accounting/domain/chart_account_policy.dart) (`deriveAccountBadges` / `deriveAllowedActions`).
- **Controller:** `ChartAccountListController` — one `fetchChartAccounts`, local filters, `ChartAccountSubmitResult` async dialog contract; screen owns SnackBar on success.
- **UI:** expand/collapse tree, search/type/status filters, setup banner (1201/2101), manual-only create/edit/deactivate; parent dropdown excludes entity-linked accounts.
- **Tests:** SQL cases 40-43 in [`phase_4_customers_suppliers_coa.sql`](supabase/tests/phase_4_customers_suppliers_coa.sql); Dart policy/setup/tree/controller/screen tests.
- **Verification:** `flutter gen-l10n`, `build_runner`, `flutter analyze`, `flutter test` (350 tests) green. SQL `048` verified locally via Docker `psql` against `supabase_db_hs360`; [`phase_4_customers_suppliers_coa.sql`](supabase/tests/phase_4_customers_suppliers_coa.sql) passed.

---

- SKU remains in DB but becomes internal/generated/hidden from normal product UI.
- Product barcode identifies product type; unit serial identifies one physical device; asset QR payload is the serial text.
- Phase 5.0 is **Asset / Barcode / Print Foundation**: product-unit lifecycle, scan resolver everywhere, labels, and JSON print engine.
- Serialized operations must require `product_unit_id` at RPC level.
- Existing stock serial backfill must reconcile units without increasing inventory balances again.
- Document templates use structured JSON; Flutter `pdf`/`printing` renderer first, later server renderer uses the same JSON model.
- Coordinates belong on `customer_service_locations`; `google_maps_url` is a source/link, not the truth. Store source/quality metadata (`resolution_source`, `resolved_at`, `coordinate_accuracy_m`) when implementing capture.
- Tax Foundation belongs before Phase 5 invoice RPCs, not in M7: use `default_tax_rate_id`, tenant `tax_rates`, explicit product tax classes (`taxable`/`zero_rated`/`exempt`/`non_taxable`), invoice-line tax snapshots, and protected tax posting accounts when implemented.

---

## Phase 4 M5.6 - Customer Service Locations (done)

- **Model:** customer = company/account; `customer_service_locations` = branches/sites (not separate customers).
- **DB:** migration [`047`](supabase/migrations/047_customer_service_locations.sql); `ux_customers(tenant_id,id)`; locations use **composite FK only** to customers; child tables use composite FK to `(tenant_id, customer_id, service_location_id)`; contract snapshot columns added; `product_units.current_service_location_id` is **current pointer only** (not history).
- **RPCs:** `list/create/update/deactivate/set_primary_customer_service_location`; read `customers.view`, write `customers.edit`; internal helpers `generate_service_location_code`, `insert_primary_service_location_from_customer` (no public grant).
- **`create_customer`:** still `returns uuid`; creates primary location in same transaction when address/governorate/area/maps present.
- **Flutter:** domain/repository/controller; Locations tab in customer detail (M5.6); full Customer 360 shell in M6.
- **Tests:** [`phase_4_customer_service_locations.sql`](supabase/tests/phase_4_customer_service_locations.sql); Dart parsing/validator tests; `flutter test` green after M5.6.

---

## Phase 4 M6 - Customer Detail, Statement & Timeline (done)

- **Screen:** [`customer_detail_screen.dart`](lib/features/customers/presentation/customer_detail_screen.dart) replaces placeholder; route `/customers/:id` unchanged.
- **Controllers:** `CustomerDetailController` (`fetchCustomerById` only); `CustomerStatementController` (ledger RPCs; load on first Statement tab select; `load(force: true)` for retry; no auto-load in `build()`).
- **Tabs (7):** Profile (read-only + edit action), Locations (M5.6 unchanged), Contracts/Invoices/Vouchers (permission-aware empty placeholders), Statement (`customers.view_ledger` via `get_customer_balance_summary` + `get_customer_statement`), Timeline (local `createdAt`/`updatedAt`/`acquiredAt` only — no timeline controller/RPC).
- **Permissions helpers:** `canViewCustomerLedger`, `canViewContracts`, `canViewInvoices`, `canViewVouchers` in [`customer_permissions.dart`](lib/features/customers/domain/customer_permissions.dart).
- **Tests:** [`customer_detail_screen_test.dart`](test/features/customers/presentation/customer_detail_screen_test.dart), [`customer_statement_controller_test.dart`](test/features/customers/presentation/customer_statement_controller_test.dart); fakes override `customerServiceLocationRepositoryProvider`.
- **Verification:** `flutter gen-l10n`, `build_runner`, `flutter analyze`, `flutter test` (325 tests) green.

---

## Phase 4 M5.5 - Customer/Supplier Profile Cleanup (done)

- **Migration:** [`supabase/migrations/046_customer_supplier_profile_cleanup.sql`](supabase/migrations/046_customer_supplier_profile_cleanup.sql) — backfill `city`→`governorate`, `address`→`address_line`, drop removed columns, nullable `account_id`, RPC updates, `ensure_customer_account` / `ensure_supplier_account`, hardened immutable triggers, zero-safe statement/balance when no account.
- **Location catalog:** [`lib/core/location/kuwait_locations.dart`](lib/core/location/kuwait_locations.dart) + shared [`kuwait_location_fields.dart`](lib/shared/widgets/kuwait_location_fields.dart).
- **Forms:** responsive sections in [`customer_form.dart`](lib/features/customers/presentation/widgets/customer_form.dart) / [`supplier_form.dart`](lib/features/suppliers/presentation/widgets/supplier_form.dart); wide dialogs (~900-960px); `create_account` on create only; permission-gated ensure-account on edit when `account_id` is null.
- **Filters/lists:** governorate dropdown + area text on customers; operational table columns (no whatsapp/credit/payment); supplier location column.
- **Accounting:** `create_account` default false; company-only fields cleared in RPC for individuals.
- **Tests:** updated fakes/validators/form tests; SQL cases 32-39 in [`supabase/tests/phase_4_customers_suppliers_coa.sql`](supabase/tests/phase_4_customers_suppliers_coa.sql), including customer/supplier default-null accounts, ensure-account, and wrong-link trigger cases.
- **Docs:** `DATABASE_SCHEMA.md`, `PHASE_4_CUSTOMERS_SUPPLIERS_COA_PLAN.md`, `NAVIGATION_AND_MODULES_BRIEF.md`, `PAYMENT_SYSTEM.md`, `CONTRACTS_LOGIC.md`.

---

## Phase 4 M5 - Customers & Suppliers Lists & Forms

- Path helpers on [`app_routes.dart`](lib/core/routing/app_routes.dart): `customerDetailPath`, `customerEditPath`, `supplierDetailPath` (all use `Uri.encodeComponent`); route template constants unchanged.
- Controllers (`@Riverpod(keepAlive: true)`): [`customer_list_controller.dart`](lib/features/customers/presentation/customer_list_controller.dart), [`supplier_list_controller.dart`](lib/features/suppliers/presentation/supplier_list_controller.dart). Default filters are **active-only** (`isActive: true`); `clearFilters()` resets to active-only. Mutations require `canView*` **and** the action permission, return `String?` error code (`null` = success), then `refresh()`. `ensureAccount(id)` links A/R or A/P when permitted.
- Drafts validate before building form state: [`customer_form_draft.dart`](lib/features/customers/presentation/customer_form_draft.dart) (name/phone/email), [`supplier_form_draft.dart`](lib/features/suppliers/presentation/supplier_form_draft.dart) (name_ar, email format).
- Shared form widgets: [`customer_form.dart`](lib/features/customers/presentation/widgets/customer_form.dart), [`supplier_form.dart`](lib/features/suppliers/presentation/widgets/supplier_form.dart). Dialogs and `CustomerEditScreen` embed them.
- Tab bodies: [`customers_tab_body.dart`](lib/features/customers/presentation/customers_tab_body.dart), [`suppliers_tab_body.dart`](lib/features/suppliers/presentation/suppliers_tab_body.dart).
- l10n: M5.5 keys for governorate, Google Maps URL, tax, sections, accounting, location; removed obsolete credit/GPS/whatsapp keys.
- Verification: `flutter gen-l10n`, `build_runner`, `flutter analyze`, `flutter test`.

---

## Phase 4 M4 - Routes, Guards, Navigation & Localization

- Routes: `/customers`, `/customers/:id`, `/customers/:id/edit`, `/suppliers`, `/suppliers/:id`, `/accounts` in [`lib/core/routing/app_routes.dart`](lib/core/routing/app_routes.dart) + [`app_router.dart`](lib/core/routing/app_router.dart).
- Guards: strict path matchers (`isCustomerEditPath`, `isCustomerDetailPath`, `isSupplierDetailPath`) reserve `new`; inline permission checks in [`route_guards.dart`](lib/core/routing/route_guards.dart); `_officePermissionIds` adds `suppliers.view` and `chart_of_accounts.view` only.
- Permission helpers (UI/tests): [`customer_permissions.dart`](lib/features/customers/domain/customer_permissions.dart), [`supplier_permissions.dart`](lib/features/suppliers/domain/supplier_permissions.dart), [`accounting_permissions.dart`](lib/features/accounting/domain/accounting_permissions.dart).
- Presentation placeholders only: `CustomersHubScreen` (Customers/Suppliers tabs with stable Keys, zero-tab fallback), customer detail/edit placeholders, supplier detail placeholder, chart of accounts placeholder - no repository imports.
- AppShell nav: Customers (customers.view or suppliers.view), Chart of Accounts (chart_of_accounts.view).
- l10n: 16 new AR/EN keys including `moduleAccessUnavailable`, professional placeholder copy (no milestone jargon in UI).
- Tests: Phase 4 route guard cases, AppShell nav permission cases, `customers_hub_screen_test.dart`.
- Verification: `flutter gen-l10n`, `flutter analyze` (clean), `flutter test` (278 tests).

---

## Phase 3 M8 - Verification & Close

- Fixed product table scrollbar controller ownership so the desktop `Scrollbar` always attaches to the scroll view it controls.
- Fixed filtered-empty product state: group/filter selection no longer replaces the full products page with a dead-end empty state; user can clear filters.
- Added Arabic display fallback for product, warehouse, and employee names when local seed data contains `?` placeholders from terminal encoding.
- Added warehouse row stock action that opens inventory balances filtered by `warehouseId`; inventory route accepts the query parameter.
- Cleaned local optional M7.5 performance seed rows from the dev database after verification; seed remains optional and should not be present in normal UI unless manually run.
- Verification passed: `flutter pub get`, `flutter pub run build_runner build --delete-conflicting-outputs --verbose`, `flutter analyze`, `flutter test` (220 tests), `flutter test integration_test`, `phase_1d_rls.sql`, `phase_3_products_inventory.sql`, and `git diff --check`.
- `npx --yes supabase db reset` was intentionally not re-run in this pass to avoid wiping local test data; prior reset failure is a Supabase CLI 2.102 internal duplicate service migration before project migrations, not a project migration failure.
- Quality scan: no widget-level Supabase access found, no money/quantity `double` usage found, no critical TODO/FIXME blocker found. Several files are now refactor candidates after Phase 3, but not M8 blockers.
