# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-20 (Phase 3 M1 complete + RPC-only movement follow-up).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 complete** - auth, routing, permissions, locale (M0–M8).
- **Phase 3 M0+M0.5 complete** - baseline and pre-migration backups in `supabase/.temp/` (not committed).
- **Phase 3 M1 complete** - DB helpers, inventory adjustment RPC, product_images storage, SQL verification.
- Migrations `001`-`038` apply cleanly with `supabase db reset`.
- **M1 DB additions:**
  - `to_primary(uuid, numeric)` / `to_secondary(uuid, numeric)` — unit conversion helpers.
  - `record_inventory_adjustment(...)` — SECURITY DEFINER RPC for `adjustment_in` / `adjustment_out` only; rejects serialized products; WAC on stock-in; stable error messages.
  - `product_images` storage bucket + public read + authenticated insert (`products.edit`).
  - `038_inventory_movements_rpc_only.sql` drops direct client INSERT/DELETE policies for `inventory_movements`; movement writes must go through RPC.
  - Test: `supabase/tests/phase_3_products_inventory.sql` (12 cases).
- `034_seed_auth_login_fix.sql` makes seeded auth users compatible with GoTrue password login after clean reset.
- CLI: use `npx --yes supabase` when `supabase` is not on PATH.
- Initial route `/login`; authenticated users redirect to home by permissions (manager/products → dashboard, field → `/field/today`, zero → `/blocked`).
- Routing: `app_routes.dart`, `route_guards.dart`, `router_refresh_notifier.dart`.
- Locale: `locale_controller.dart`; prefs key `preferred_locale`; only `ar` / `en`.

---

## Decisions Confirmed

- Access control is Manager/User only; RLS uses `user_has_permission()`.
- Inventory movements are immutable in design; direct client INSERT/DELETE policies are dropped in migration `038`. Corrections should use controlled reverse movements/RPCs.
- Manual adjustments: `inventory_movements.create`, non-empty notes, `p_unit_cost` required on `adjustment_in` (use `0.000` for free stock).
- Serialized products cannot use bulk `record_inventory_adjustment` in M1 (`serialized_adjustment_not_supported`).
- WAC in M1 uses `sum(qty_available)` only; revisit other stock buckets in M1.5/M7.
- `products_safe` hides cost columns; repositories must not expose cost without field permissions.
- Storage `product_images`: INSERT only in M1; UPDATE/DELETE policies deferred to M5.
- Phase 3 transfers (`record_inventory_transfer`) deferred to **M7E**.

---

## Locale API (M6)

| Use | Call |
|-----|------|
| Read locale in widgets / `MaterialApp` | `ref.watch(localeProvider)` |
| Change language | `ref.read(localeControllerProvider.notifier).setLocale(locale)` |
| Text direction | `localeTextDirection(locale)` at app root |

Supported: `Locale('ar')`, `Locale('en')`. Default: `Env.defaultLocale` (`ar`).

---

## Last Session Summary

**Date:** 2026-05-20  
**Task:** Phase 3 M1 - Database gap review and inventory helpers, plus RPC-only movement follow-up.

### What was done

- Added migrations `035`–`037`: conversion helpers, `record_inventory_adjustment` RPC, `product_images` bucket/policies.
- Added `038_inventory_movements_rpc_only.sql` to block direct client movement inserts/deletes so balances cannot be bypassed.
- Added `supabase/tests/phase_3_products_inventory.sql` with conversion, tenant isolation, permissions, direct movement insert blocking, adjustments, WAC, `products_safe`, storage catalog checks.

### Verification

```text
npx --yes supabase db reset      -> passed (migrations 001-038)
phase_1d_rls.sql                 -> phase_1d_rls_verification_passed
phase_3_products_inventory.sql   -> phase_3_products_inventory_verification_passed
```

PowerShell test command:

```powershell
Get-Content supabase\tests\phase_3_products_inventory.sql | docker exec -i supabase_db_hs360 psql -U postgres -d postgres
```

### Intentional deferrals (M1)

- `record_inventory_transfer` → M7E
- `p_client_id` idempotency → M1.5
- Storage UPDATE/DELETE → M5
- Serialized unit-level adjustments → M6/M7D

### Next recommended step

- **Phase 3 M1.5** - Inventory business rules and engine boundaries, then **M2** domain/repositories.
