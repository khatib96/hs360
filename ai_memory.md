# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-20 (Phase 3 M4 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0-M8).
- **Phase 3 M0–M3 complete** - DB, domain/data, routes, placeholders.
- **Phase 3 M4 complete** - product list screen, group tree, filters, permission-aware columns, AR/EN l10n.
- Migrations `001`-`039` apply cleanly with `supabase db reset`.
- **Canonical inventory rules:** [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md)
- **Next:** Phase 3 M5 - Product Detail, Edit & Wizard.

---

## Phase 3 M4 - Product Groups & Product List

- `/products` → real `ProductListScreen` (M2 repositories; no new migrations).
- Search + type/active/stock filters; UI-local search debounce.
- Group panel (~240px wide) when `product_groups.view`; simple create/edit/deactivate via `product_groups.create` / `edit` (deactivate = `is_active=false`, not `delete`).
- Stock column always visible; values only with `inventory.view`; stock filter hidden without it; product list never fails on stock errors.
- Group column always visible; unavailable label without `product_groups.view` (never raw UUID).
- Cost columns only when `canViewFullProductCosts`; `ProductTable` receives `canViewCosts` bool from screen.
- Rental price column always visible; `—` when `rentalPriceMonthly` null.
- `/products/new` and `/products/:id` still placeholders.
- Tests: tree, controller (fake repos), table/empty/error widgets.

**No DB migrations in M4.**

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
**Task:** Phase 3 M4 - Product Groups & Product List.

### Verification

```text
dart run build_runner build --delete-conflicting-outputs
flutter analyze  -> No issues found
flutter test     -> All tests passed (107)
```

No `supabase db reset` (no SQL changes in M4).
Post-review hardening: product list scroll behavior, secondary group/stock load handling,
hidden permission filters, and product-group tree safety were tightened.

### Next Recommended Step

- **Phase 3 M5** - Product Detail, Edit & Add Product Wizard.
