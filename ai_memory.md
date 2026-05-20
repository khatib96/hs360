# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-21 (Phase 3 M5 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0-M8).
- **Phase 3 M0–M4 complete** - DB, domain/data, routes, product list.
- **Phase 3 M5 complete** - product detail, 5-step create/edit wizard, primary image upload.
- Migrations `001`-`039` apply cleanly with `supabase db reset`.
- **Canonical inventory rules:** [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md)
- **Next:** Phase 3 M6 - Product Units Management.

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

- **Phase 3 M6** - Product Units Management (serial units inside product detail).
