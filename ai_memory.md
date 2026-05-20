# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-20 (Phase 3 M3 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0-M8).
- **Phase 3 M0+M0.5 complete** - baseline and pre-migration backups in `supabase/.temp/` (not committed).
- **Phase 3 M1 complete** - DB helpers, inventory adjustment RPC, product_images storage, RPC-only movements, SQL verification.
- **Phase 3 M1.5 complete** - canonical inventory rules doc + comments-only migration `039`.
- **Phase 3 M2 complete** - Dart domain/data layer for products and inventory (no UI, no new migrations).
- **Phase 3 M3 complete** - routes, permission guards, navigation, l10n, and lightweight placeholders.
- Migrations `001`-`039` apply cleanly with `supabase db reset`.
- **Canonical inventory rules:** [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md)
- **Next:** Phase 3 M4 - Product Groups & Product List.

---

## Phase 3 M2 - Dart Files Created

### Core

- `lib/core/utils/decimal_parser.dart`
- `lib/core/utils/money_formatter.dart`
- `lib/core/utils/quantity_formatter.dart`
- `lib/core/errors/inventory_exception.dart`
- `lib/core/errors/products_exception.dart`

### Domain

- `lib/domain/validators/validation_result.dart`
- `lib/domain/validators/product_validator.dart`
- `lib/domain/validators/inventory_adjustment_validator.dart`
- `lib/domain/services/unit_conversion_service.dart`
- `lib/domain/services/stock_engine.dart`
- `lib/domain/services/cost_engine.dart`

### Products

- `lib/features/products/domain/product_type.dart`
- `lib/features/products/domain/unit_of_measure.dart`
- `lib/features/products/domain/unit_status.dart`
- `lib/features/products/domain/product.dart`
- `lib/features/products/domain/product_group.dart`
- `lib/features/products/domain/product_filters.dart`
- `lib/features/products/domain/product_form_state.dart`
- `lib/features/products/domain/product_stock_summary.dart`
- `lib/features/products/domain/product_cost_access.dart`
- `lib/features/products/data/product_repository.dart` + `.g.dart`
- `lib/features/products/data/product_group_repository.dart` + `.g.dart`

### Inventory

- `lib/features/inventory/domain/warehouse_type.dart`
- `lib/features/inventory/domain/movement_type.dart`
- `lib/features/inventory/domain/warehouse.dart`
- `lib/features/inventory/domain/inventory_balance.dart`
- `lib/features/inventory/domain/inventory_movement.dart`
- `lib/features/inventory/domain/inventory_adjustment_form_state.dart`
- `lib/features/inventory/data/warehouse_repository.dart` + `.g.dart`
- `lib/features/inventory/data/inventory_repository.dart` + `.g.dart`

---

## Phase 3 M3 - Routing, Permissions, and Navigation

- Added `/products`, `/products/new`, `/products/:id`, `/warehouses`, `/inventory`, `/inventory/movements`, and `/inventory/transfers`.
- Added exact route permission guards for Phase 3 paths.
- Added permission-aware AppShell navigation for desktop sidebar and mobile drawer.
- Sidebar is light/white with subtle gold background accents; active items use brand gold with white text.
- Added lightweight product and inventory placeholder screens.
- Added localized module labels in Arabic and English.
- Added route guard and navigation permission tests.

**No DB migrations added in M3.**

---

## Decisions Confirmed

- Access control is Manager/User only; RLS uses `user_has_permission()`.
- Inventory movements are append-only; stock changes via `record_inventory_adjustment` RPC only.
- `canViewFullProductCosts` uses `session.permissions.isManager` only (not dual `session.isManager`).
- Cost writes: no silent strip; unauthorized non-null cost fields -> `permission_denied`; `minRentalPrice != null` -> `field_not_supported` until DB column exists.
- `products_safe` for reads without all four cost field permissions.
- StockEngine / CostEngine: Dart preview/validation only; DB/RPC is authority.
- `WarehouseRepository` owns warehouses; `InventoryRepository` owns balances, movements, adjustment RPC only.
- All money/qty in M2 models use `Decimal`, not `double`.

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

**Date:** 2026-05-20  
**Task:** Phase 3 M3 - Routes, permissions, and navigation.

### Verification

```text
flutter analyze  -> No issues found
flutter test     -> All tests passed
```

No `supabase db reset` (no SQL changes in M3).

### Next Recommended Step

- **Phase 3 M4** - Product Groups & Product List.
