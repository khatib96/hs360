# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-27 (Phase 3 M7D complete; M7.5 cleanup notes recorded).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0-M8).
- **Phase 3 M0–M4 complete** - DB, domain/data, routes, product list.
- **Phase 3 M5 complete** - product detail, 5-step create/edit wizard, primary image upload.
- **Phase 3 M6 complete** - serialized product units in product detail Units tab.
- **Phase 3 M6.5 complete** - product sale/rental modes split before M7.
- **Phase 3 M7A complete** - warehouse CRUD screen, van rules, assignable employees RPC.
- **Phase 3 M7B complete** - inventory balances screen, product detail stock card, partial hydration failures.
- **Phase 3 M7C complete** - read-only movements log at `/inventory/movements`.
- **Phase 3 M7D complete** - manual stock-in/out dialog on `/inventory`; migration `043` cost gate on `adjustment_in`.
- Migrations `001`-`043` apply cleanly with `supabase db reset`.
- **Canonical inventory rules:** [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md)
- **Next:** Phase 3 M7E - Transfers.
- **Before M8:** Phase 3 M7.5 cleanup/hardening pass.

---

## Phase 3 M7.5 - Cleanup Before M8

- Split `inventory_adjustment_dialog.dart` (currently large) by extracting product search / selection into a focused widget.
- Add direct dialog widget tests for M7D cost gates:
  - stock-in type hidden without `canWriteProductCosts`.
  - unit cost field absent without `canWriteProductCosts`.
  - WAC preview absent without `canViewFullProductCosts`.
- Revisit M7B low-stock filter semantics: currently evaluates after active UI filters; decide whether low-stock should use product total across all warehouses independent of search/warehouse filters.
- Run full verification before M8: `flutter analyze`, `flutter test`, `supabase db reset`, and `phase_3_products_inventory.sql`.

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
