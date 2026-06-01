# ai_memory.md - AI Collaboration Memory

> Updated 2026-06-01 (Phase 4 M5.5 complete; next is M6 Customer Detail, Statement & Timeline).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0-M8).
- **Phase 3 complete** - products and inventory (M0-M8).
- **Phase 4 M0-M3 complete** - DB RPCs, domain models, validators, repositories for customers, suppliers, chart of accounts.
- **Phase 4 M4 complete** - routes, guards, AppShell navigation, AR/EN l10n, placeholder screens.
- **Phase 4 M5 complete** - customer/supplier lists, filters, and create/edit/deactivate forms.
- **Phase 4 M5.5 complete** - profile field cleanup (DB `046`), optional `create_account`, `ensure_*_account`, Kuwait location catalog, responsive sectioned forms, governorate/area filters.
- Migrations `001`-`046` apply when applied directly; `phase_4_customers_suppliers_coa.sql` passed after applying `046` to local Postgres on 2026-06-01. `npx --yes supabase db reset` remains avoided/blocked by Supabase CLI 2.102 internal service migration duplicate.
- **Canonical inventory rules:** [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md)
- **Next:** Phase 4 M6 - Customer Detail, Statement & Timeline.

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
