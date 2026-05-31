# ai_memory.md - AI Collaboration Memory

> Updated 2026-06-01 (Phase 4 M5 complete; next is M5.5 customer/supplier profile cleanup before GitHub/M6).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0-M8).
- **Phase 3 complete** - products and inventory (M0-M8).
- **Phase 4 M0-M3 complete** - DB RPCs, domain models, validators, repositories for customers, suppliers, chart of accounts.
- **Phase 4 M4 complete** - routes, guards, AppShell navigation, AR/EN l10n, placeholder screens (no CRUD/repository imports in presentation).
- **Phase 4 M5 complete** - customer/supplier lists, filters, and create/edit/deactivate forms wired through Riverpod controllers + existing repositories.
- **Phase 4 M5.5 planned before M6** - clean customer/supplier profile fields, DB schema/RPCs, and forms before publishing/continuing.
- Migrations `001`-`044` apply cleanly when applied directly; `npx --yes supabase db reset` is currently blocked by a Supabase CLI 2.102 internal service migration duplicate before project migrations.
- **Canonical inventory rules:** [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md)
- **Next:** Phase 4 M5.5 - Customer/Supplier Profile Cleanup (then M6 Customer Detail, Statement & Timeline).

---

## Phase 4 M5.5 - Customer/Supplier Profile Cleanup Plan

Goal: fix the M5 profile UX/data model before GitHub/M6. M5 works technically, but the create/edit forms currently expose too many low-value fields and the DB still contains fields the business does not want to keep.

- **DB cleanup:** add a new migration (likely `046_customer_supplier_profile_cleanup.sql`) and update RPCs/domain/tests. Remove from `customers`: `phone_secondary`, `whatsapp`, `contact_person_title`, `gps_lat`, `gps_lng`, `payment_terms_days`, `credit_limit`. These must disappear from both app and DB, not just be hidden.
- **Customer fields:** individual customers should only capture name, phone, optional email, country, governorate, area, address details, Google Maps URL, notes, and VIP flag. Company customers should capture company Arabic name, optional English name, phone, optional email, optional tax number, optional contact person name, optional contact person phone, address fields, Google Maps URL, notes, and VIP flag.
- **Supplier fields:** keep supplier profiles similarly clean: name, phone, optional email, optional tax number, country/governorate/area/address details, Google Maps URL, notes. Avoid generic/ambiguous address-only storage if the customer schema is structured.
- **Accounting account decision:** current M2 RPCs always create linked A/R or A/P accounts and `account_id` is required. M5.5 should change this to an explicit `create_account` choice (recommended default `false`) and make `account_id` nullable where needed, so POS/one-time customers are not forced into the chart of accounts. If `create_account = true`, keep the atomic subaccount generation rules.
- **Form redesign:** widen customer/supplier dialogs (around 900-1000px desktop), replace long single-column forms with grouped rows/sections, and conditionally show company-only fields only when customer type is company. Do not show empty/irrelevant fields for individuals.
- **Location UX:** replace GPS latitude/longitude with a simple Google Maps URL field. Add a local Kuwait location catalog (country -> governorate -> areas) from the user's table image; first row is governorate names and each column contains its areas. Use dropdowns for country/governorate/area, then free-text address details.
- **Filters/list toolbar:** keep filters in one compact toolbar row where desktop space allows; make the Add Customer/Supplier action compact and aligned with filters. Allow wrapping only on smaller widths.
- **Out of scope:** payment terms, credit limits, visit schedules, oil replacement/service dates, and contract-specific cadence belong to contracts/accounting/visits, not the customer creation card.
- **Verification:** update fake repositories, validators, l10n, route/list/form tests; run migration checks as applicable plus `flutter gen-l10n`, `flutter analyze`, `flutter test`, and `git diff --check`. Update this memory when M5.5 is complete.

---

## Phase 4 M5 - Customers & Suppliers Lists & Forms

- Path helpers on [`app_routes.dart`](lib/core/routing/app_routes.dart): `customerDetailPath`, `customerEditPath`, `supplierDetailPath` (all use `Uri.encodeComponent`); route template constants unchanged.
- Controllers (`@Riverpod(keepAlive: true)`): [`customer_list_controller.dart`](lib/features/customers/presentation/customer_list_controller.dart), [`supplier_list_controller.dart`](lib/features/suppliers/presentation/supplier_list_controller.dart). Default filters are **active-only** (`isActive: true`); `clearFilters()` resets to active-only. Mutations require `canView*` **and** the action permission, return `String?` error code (`null` = success), read repository directly (work before list loads), then `refresh()`. Catch `CustomerException`/`SupplierException`, else `unknown`.
- Drafts validate before building form state (no silent numeric coercion): [`customer_form_draft.dart`](lib/features/customers/presentation/customer_form_draft.dart) (UI-only `invalid_decimal`/`invalid_integer`, GPS pair, negative credit/payment), [`supplier_form_draft.dart`](lib/features/suppliers/presentation/supplier_form_draft.dart) (name_ar required, email format). `credit_limit`/GPS are `Decimal`; `payment_terms_days` is `int`.
- Shared form widgets are the single source of fields: [`customer_form.dart`](lib/features/customers/presentation/widgets/customer_form.dart), [`supplier_form.dart`](lib/features/suppliers/presentation/widgets/supplier_form.dart). Dialogs and `CustomerEditScreen` are shells embedding them; dialogs close on success + SnackBar, stay open on error. `CustomerEditScreen` prefills via `fetchCustomerById` but saves via `CustomerListController.updateCustomer`.
- Tab bodies replace M4 placeholders: [`customers_tab_body.dart`](lib/features/customers/presentation/customers_tab_body.dart), [`suppliers_tab_body.dart`](lib/features/suppliers/presentation/suppliers_tab_body.dart) (keys `customers-tab-body` / `suppliers-tab-body`). Desktop `DataTable` uses owned scroll controllers + `Scrollbar`; mobile uses cards. Search is `onSubmitted` + clear (no debounce). Removed `customer_edit_placeholder_screen.dart`.
- Post-review UX fix: empty-state copy now uses `hasNonDefaultFilters` so the M5 default active-only view is not treated as a user-applied filter; covered by customer/supplier filter tests.
- l10n: added customer/supplier list/filter/table/form/validation AR+EN keys; kept unused M4 `customersListUnavailable`/`suppliersListUnavailable` keys.
- No statement/balance/timeline/CoA/migrations. Tests use local fakes (`super(null)`, no Supabase) and assert statement/balance call counts stay 0.
- Verification: `build_runner`, `flutter gen-l10n`, `flutter analyze` (clean), `flutter test` (313 tests after post-review filter tests).

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

---

## Phase 3 M7.5 - Cleanup Before M8

- Extracted product search / selection from `inventory_adjustment_dialog.dart` into `InventoryAdjustmentProductPicker`.
- Added direct dialog widget tests for M7D cost gates:
  - stock-in type hidden without `canWriteProductCosts`.
  - unit cost field absent without `canWriteProductCosts`.
  - WAC preview absent without `canViewFullProductCosts`.
- Low-stock filter now calculates product totals from all balance rows before warehouse/search filters, so a low single warehouse does not mark a product low when total stock is healthy.
- Added optional local performance seed: [`supabase/tests/phase_3_inventory_performance_seed.sql`](supabase/tests/phase_3_inventory_performance_seed.sql) creates 100 products, 3 warehouses, 1,000 movements, and 300 balances.
- Index review: required M7.5 indexes already exist in `015_inventory.sql`; no extra composite indexes added because the seed-size query plan did not justify them.
- Verification: `flutter analyze`, `flutter test` (220 tests), `phase_1d_rls.sql`, `phase_3_products_inventory.sql`, and M7.5 performance seed all passed. Official `npx --yes supabase db reset` is blocked by Supabase CLI 2.102 internal duplicate migration; local DB was restored by applying migrations `001`-`044` directly via `psql`.

---

## Phase 3 M7D - Manual Adjustments

- Entry: `/inventory` → **Manual adjustment** (`FilledButton`); requires `inventory.view` + `inventory_movements.create`.
- `adjustment_in` also requires full cost permissions (DB `user_has_full_product_cost_access()` + repo `canWriteProductCosts` + UI).
- `recordInventoryAdjustment(AppSession, formState)` only path; permission gates before validator.
- Dialog: warehouse/product/qty/notes; signed delta preview (`+`/`-`); optional WAC preview when `canViewFullProductCosts`; serialized products blocked.
- Success: dialog closes + SnackBar; refreshes balances + best-effort movements log when `inventory_movements.view`.
- Migration [`043_inventory_adjustment_cost_permission.sql`](supabase/migrations/043_inventory_adjustment_cost_permission.sql).
- SQL tests 23–24 (cost permission fixtures); test 4 updated with cost grants for `adjustment_in`.
- Tests: 197 `flutter test`; `flutter analyze` clean; `phase_3_products_inventory.sql` passed.

**Deferred:** M7E transfers UI/RPC; M7.5 dialog cleanup + cost-gate widget tests; serialized unit-level warehouse changes; adjustments without `inventory.view` route.

---

## Phase 3 M7C - Movements Log

- `/inventory/movements` → `InventoryMovementsScreen` (router only; `inventory_placeholder_screen.dart` unchanged; transfers placeholder unchanged).
- `InventoryMovementsController` loads `fetchInventoryMovements` only (never balances); filters: warehouse, movement type, local date range (exclusive `occurredBefore` in repo), page size, product search.
- Product search with `products.view`: `searchProductIdsForInventoryMovements` (no `is_active`, no limit); zero IDs → empty list without movements query.
- Without `products.view`: client-side search on movement fields; ARB hint for name/SKU limitation.
- `unit_cost` column/card only when `canViewFullProductCosts`; wide table truncates notes + tooltip.
- Inverted date pick clears the other endpoint (no error banner).
- Tests: 188 `flutter test`; `flutter analyze` clean; `phase_3_products_inventory.sql` passed.

---

## Phase 3 M7B - Stock Balances

- `/inventory` → `InventoryScreen`.
- `InventoryBalancesController` coordinates `InventoryRepository.fetchInventoryBalances` + label hydration via `ProductRepository.fetchProductsByIdsForStockLabels` and `WarehouseRepository.fetchWarehouses`.
- Partial failure: balances error = full error state; product/warehouse hydration failure = rows with fallback labels + non-blocking banners.
- `productStockLabelColumnsForSession` in `product_cost_access.dart` — minimal non-cost columns only.
- Product detail Inventory tab: `ProductStockSummaryCard` (per-warehouse buckets, low-stock warning, warehouse fallback).
- M7A cleanup: `employeeLookupErrorCode` on warehouses screen; non-van `agentId` normalized before validation.
- **Deferred to M7.5 (important):** low-stock filter currently evaluates after active UI filters; revisit whether low-stock must always use product total across all warehouses, independent of warehouse/search filters.
- Tests: 171 `flutter test`; `flutter analyze` clean; `phase_3_products_inventory.sql` passed.

---

## Phase 3 M7A - Warehouses

- Migration [`042_warehouse_van_rules.sql`](supabase/migrations/042_warehouse_van_rules.sql): `ux_warehouses_active_van_agent` partial unique index, `warehouses_van_requires_agent` CHECK, `list_warehouse_assignable_employees()` RPC.
- Flutter: `WarehousesScreen`, form dialog, table, `WarehousesController`, `WarehouseValidator`, extended `WarehouseRepository` (CRUD + employees RPC).
- Van rules: employee required; one active van per employee; inactive warehouses excluded via `fetchWarehouses(activeOnly: true)`.
- Employee labels: `{code} - {name}`; RPC returns all tenant employees with `is_active`; dropdown filters active only.
- Permissions: `warehouses.view/create/edit`; deactivate via `is_active=false` (not hard delete).
- SQL tests 20–22 in `phase_3_products_inventory.sql`.
- Tests: 154 `flutter test`; `flutter analyze` clean.

---

## Phase 3 M6.5 - Product Sale/Rental Modes

- Migration [`041_product_sale_rental_modes.sql`](supabase/migrations/041_product_sale_rental_modes.sql): adds `products.can_be_sold`, `products.can_be_rented`, compatibility trigger, constraints, and refreshed `products_safe`.
- `product_type` remains the rental kind/legacy enum: `sale_only`, `asset_rental`, `consumable_rental`.
- UI now models sale and rental as independent checkboxes; when rental is enabled, user chooses rental type (`asset` or `consumable`).
- Asset rental shows per-product expected lifespan months. Serialized is allowed but not required because old non-serialized devices may exist.
- Contract implication: asset rental leaves/returns as company asset; consumable rental is consumed from stock during refill visits.
- Products do **not** have a rental price. Contract monthly value is entered on contracts; product sale price and expected lifespan/unit conversion provide the internal basis for minimum-profit validation.
- UI rule: filled gold buttons use white text/icons.

---

## Phase 3 M6 - Product Units Management

- Migration [`040_product_units_rpc.sql`](supabase/migrations/040_product_units_rpc.sql): `create_product_units`, `update_product_unit_safe`, `user_has_full_product_cost_access`, `ux_product_units_tenant_serial_ci`; dropped `product_units` insert/update/delete RLS policies.
- Unit create atomically: `product_units` + `adjustment_in` movement + `inventory_balances`; WAC/`last_purchase_cost` updated.
- Safe edit RPC only: `barcode`, `notes`, `health_status` (no warehouse change in M6 — defer to M7E).
- Flutter: `ProductUnitRepository`, Units tab table, Add/Bulk/Edit dialogs, `ProductUnitBulkParser`.
- Permissions: `product_units.view/create/edit`; `purchase_cost` gated by `canViewFullProductCosts` in columns and JSON anti-tamper in RPC.
- Tests: 141 `flutter test`; SQL tests 13–19 in `phase_3_products_inventory.sql` pass after `db reset`.

---

## Phase 3 M5 - Product Detail, Edit & Wizard

- Routes (order matters): `/products/new` → `/products/:id/edit` → `/products/:id`.
- `ProductDetailScreen` - tabs: Overview, Pricing, Units, Inventory, Audit; cost fields gated by `canViewFullProductCosts`.
- `ProductWizardScreen` - 5 steps; shared `ProductFormController` + `ProductFormDraft`.
- Edit without `product_groups.view`: keeps existing `groupId`; group shown as unavailable (no UUID).
- Create without `product_groups.view`: submit blocked with localized message.
- Image upload on detail only (`canEditProduct`); versioned path `{tenant}/products/{id}/primary-{ms}.{ext}`; MIME+ext whitelist; 5MB max; `uploadBinary` + `getPublicUrl`.
- `updateProductImageUrl` in repository (domain `canEditProduct` gate).
- `product_permissions.dart` in domain (not presentation); M3/M4 uses `session.isManager` for module gates.
- `ProductValidator` specific codes + `validation_failed` fallback; rental/serialized/negative price rules.
- Removed `products_placeholder_screen.dart`.
- Tests: validator, image validation, route guards (`isProductEditPath`), form controller, fakes extended.

**No DB migrations in M5.**

---

## Decisions Confirmed

- Access control is Manager/User only; RLS uses `user_has_permission()`.
- Inventory movements are append-only; stock changes via `record_inventory_adjustment` RPC only.
- `canViewFullProductCosts` uses `session.permissions.isManager` only (not dual `session.isManager`).
- Cost writes: no silent strip; unauthorized non-null cost fields -> `permission_denied`.
- `products_safe` for reads without all four cost field permissions.
- StockEngine / CostEngine: Dart preview/validation only; DB/RPC is authority.
- `WarehouseRepository` owns warehouses; `InventoryRepository` owns balances, movements, adjustment RPC only.
- All money/qty in M2 models use `Decimal`, not `double`.
- Old product image cleanup in storage: deferred (versioned INSERT-only paths).

---

## Locale API

| Use | Call |
|-----|------|
| Read locale | `ref.watch(localeProvider)` |
| Change language | `ref.read(localeControllerProvider.notifier).setLocale(locale)` |
| Text direction | `localeTextDirection(locale)` at app root |

Supported: `ar`, `en`. Default: `ar`.

---

## Last Session Summary

**Date:** 2026-05-21
**Task:** Phase 3 M5 - Product Detail, Edit & Add Product Wizard.

### Verification

```text
dart run build_runner build --delete-conflicting-outputs
flutter pub run build_runner build --delete-conflicting-outputs -> Built
flutter analyze -> No issues found
flutter test -> All tests passed (127)
```

No `supabase db reset` (no SQL changes in M5).

### Next Recommended Step

- **Phase 3 M7D** - Manual stock adjustments UI (`record_inventory_adjustment`).
