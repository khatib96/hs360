# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-20 (Phase 3 M2 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0–M8).
- **Phase 3 M0+M0.5 complete** - baseline and pre-migration backups in `supabase/.temp/` (not committed).
- **Phase 3 M1 complete** - DB helpers, inventory adjustment RPC, product_images storage, RPC-only movements, SQL verification.
- **Phase 3 M1.5 complete** - canonical inventory rules doc + comments-only migration `039`.
- **Phase 3 M2 complete** - Dart domain/data layer for products and inventory (no UI, no new migrations).
- Migrations `001`-`039` apply cleanly with `supabase db reset`.
- **Canonical inventory rules:** [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md)
- **Next:** Phase 3 M3 — routes, permissions, and navigation.

---

## Phase 3 M2 — Dart files created

### Core

- `lib/core/utils/decimal_parser.dart`
- `lib/core/utils/money_formatter.dart`
- `lib/core/utils/quantity_formatter.dart`
- `lib/core/errors/inventory_exception.dart`
- `lib/core/errors/products_exception.dart`

### Domain (shared)

- `lib/domain/validators/validation_result.dart`
- `lib/domain/validators/product_validator.dart`
- `lib/domain/validators/inventory_adjustment_validator.dart`
- `lib/domain/services/unit_conversion_service.dart`
- `lib/domain/services/stock_engine.dart`
- `lib/domain/services/cost_engine.dart`

### Products feature

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

### Inventory feature

- `lib/features/inventory/domain/warehouse_type.dart`
- `lib/features/inventory/domain/movement_type.dart`
- `lib/features/inventory/domain/warehouse.dart`
- `lib/features/inventory/domain/inventory_balance.dart`
- `lib/features/inventory/domain/inventory_movement.dart`
- `lib/features/inventory/domain/inventory_adjustment_form_state.dart`
- `lib/features/inventory/data/warehouse_repository.dart` + `.g.dart`
- `lib/features/inventory/data/inventory_repository.dart` + `.g.dart`

### Tests (M2)

- `test/core/utils/decimal_parser_test.dart`
- `test/features/products/domain/enums_test.dart`
- `test/features/products/domain/product_cost_access_test.dart`
- `test/features/products/domain/product_cost_write_policy_test.dart`
- `test/domain/services/unit_conversion_service_test.dart`
- `test/domain/services/stock_engine_test.dart`
- `test/domain/services/cost_engine_test.dart`
- `test/domain/validators/inventory_adjustment_validator_test.dart`

**No DB migrations added in M2.**

---

## Decisions Confirmed

- Access control is Manager/User only; RLS uses `user_has_permission()`.
- Inventory movements are append-only; stock changes via `record_inventory_adjustment` RPC only.
- `canViewFullProductCosts` uses `session.permissions.isManager` only (not dual `session.isManager`).
- Cost writes: no silent strip; unauthorized non-null cost fields → `permission_denied`; `minRentalPrice != null` → `field_not_supported` until DB column exists.
- `products_safe` for reads without all four cost field permissions.
- StockEngine / CostEngine: Dart preview/validation only; DB/RPC is authority.
- `WarehouseRepository` owns warehouses; `InventoryRepository` owns balances, movements, adjustment RPC only.
- All money/qty in M2 models use `Decimal`, not `double`.

---

## Locale API (M6)

| Use | Call |
|-----|------|
| Read locale | `ref.watch(localeProvider)` |
| Change language | `ref.read(localeControllerProvider.notifier).setLocale(locale)` |
| Text direction | `localeTextDirection(locale)` at app root |

Supported: `ar`, `en`. Default: `ar`.

---

## Last Session Summary

**Date:** 2026-05-20  
**Task:** Phase 3 M2 — Domain models and repositories.

### Verification

```text
dart run build_runner build --delete-conflicting-outputs  -> passed
flutter analyze                                            -> No issues found
flutter test                                               -> All tests passed
```

No `supabase db reset` (no SQL changes in M2).

### Next recommended step

- **Phase 3 M3** — Routes, permissions, and navigation for products/inventory modules.
