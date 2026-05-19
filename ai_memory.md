# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-20 (Phase 3 M1.5 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0–M8).
- **Phase 3 M0+M0.5 complete** - baseline and pre-migration backups in `supabase/.temp/` (not committed).
- **Phase 3 M1 complete** - DB helpers, inventory adjustment RPC, product_images storage, RPC-only movements, SQL verification.
- **Phase 3 M1.5 complete** - canonical inventory rules doc + comments-only migration `039`.
- Migrations `001`-`039` apply cleanly with `supabase db reset`.
- **Canonical inventory rules:** [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md) (wins over BUILD_PLAN / ad-hoc notes for inventory behavior until superseded).
- **M1/M1.5 DB:**
  - `to_primary` / `to_secondary` (035)
  - `record_inventory_adjustment` (036) — adjustment_in/out; serialized reject; WAC on stock-in
  - `product_images` storage (037)
  - RPC-only movement writes (038)
  - Business-rule PostgreSQL comments (039)
  - Test: `supabase/tests/phase_3_products_inventory.sql` (12 cases)
- `inventory_movements.create` = call approved inventory RPCs, **not** direct table INSERT (after 038).
- CLI: use `npx --yes supabase` when `supabase` is not on PATH.
- Initial route `/login`; permission-aware home routing (manager/products → dashboard, field → `/field/today`, zero → `/blocked`).

---

## Decisions Confirmed

- Access control is Manager/User only; RLS uses `user_has_permission()`.
- Inventory movements are append-only; no client INSERT/DELETE (038); corrections via reverse RPC + notes.
- Manual adjustments: `inventory_movements.create`, non-empty notes, `unit_cost` required on `adjustment_in` (0.000 allowed for free stock).
- Serialized products: bulk `record_inventory_adjustment` rejected (`serialized_adjustment_not_supported`).
- WAC: M1 uses `sum(qty_available)` only; revisit all stock buckets before Phase 5 / in M7.
- `products_safe` for users without full cost field permissions (M2 contract).
- StockEngine / CostEngine: Dart preview/validation only; DB/RPC is authority (M2).
- Storage `product_images`: INSERT only in M1; UPDATE/DELETE → M5.
- Transfers → M7E; serialized unit RPCs → M6/M7D.

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
**Task:** Phase 3 M1.5 - Inventory business rules and engine boundaries.

### What was done

- Created [`docs/PHASE_3_M1_5_INVENTORY_RULES.md`](docs/PHASE_3_M1_5_INVENTORY_RULES.md) (sections A–M; canonical inventory rules).
- Created [`supabase/migrations/039_inventory_business_rules.sql`](supabase/migrations/039_inventory_business_rules.sql) (COMMENT ON tables, columns, helpers, RPC — no behavior change).
- Cross-linked M1.5 in [`docs/PHASE_3_PRODUCTS_INVENTORY_PLAN.md`](docs/PHASE_3_PRODUCTS_INVENTORY_PLAN.md).

### Verification

```text
npx --yes supabase db reset      -> passed (migrations 001-039)
phase_1d_rls.sql                 -> phase_1d_rls_verification_passed
phase_3_products_inventory.sql   -> phase_3_products_inventory_verification_passed
```

No Dart files changed; Flutter checks not run.

### Next recommended step

- **Phase 3 M2** - Domain models and repositories (`StockEngine` / `CostEngine` per M1.5 contract).
