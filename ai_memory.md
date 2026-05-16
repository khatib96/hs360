# ai_memory.md — AI Collaboration Memory

> Updated 2026-05-16 (Phase 1 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0–1D complete** — local Supabase database foundation is verified.
- Migrations `001`–`031` apply cleanly with `supabase db reset`; 35 public tables; 26 enums.
- **Phase 1C complete** — `027_functions`, `028_views`, `029_triggers`, `030_rls_policies`; verified with local `db reset`.
- **Phase 1D complete** — `031_seed.sql` + `supabase/tests/phase_1d_rls.sql`.
- CLI: `npx supabase` when `supabase` is not on PATH.
- **RLS:** enabled on all 35 public tables in `030_rls_policies.sql` (115 policies).
- **Safe views:** `products_safe`, `contracts_safe` (`security_invoker = true`).
- **Helpers (027):** `current_tenant_user_id`, `current_employee_id`, `get_my_permissions`, `touch_updated_at`.
- **Triggers (029):** `audit_log_row` (narrow WHEN clauses), `user_permissions` insert/delete audit, `vouchers` insert/delete only, journal balance, last-manager + self-mod guards, `touch_updated_at` on 6 tables.
- **Seed:** Hayat Secret tenant, Tenant B isolation tenant, 5 test users, 103 permissions, KWD currencies, CoA, warehouses, product groups, employees, products.
- **No 032.**
- `get_my_permissions`: managers return `permissions: []` — clients must treat `is_manager=true` as full access.

---

## Decisions Confirmed

- Access control is Manager/User only.
- Users have zero permissions by default.
- RLS uses `user_has_permission()`.
- No hardcoded tenant access roles.
- Currencies are dynamic.
- v1 has one default currency per tenant.
- Field-level hiding uses `security_invoker` safe views or permission-shaped RPCs.
- Contract snapshots are frozen forever.
- Mobile offline sync is out of v1.
- `permissions` table: RLS read-only for authenticated; seed via service role in 1D.

---

## Last Session Summary

**Date:** 2026-05-16  
**Task:** Phase 1D — seed and RLS verification.

What was done:

- `031_seed.sql` — repeatable local seed for Hayat Secret and a second tenant.
- `supabase/tests/phase_1d_rls.sql` — behavioral RLS checks using `anon` / `authenticated` roles and JWT subject claims.

Verification:

- `supabase db reset` succeeded through `031_seed.sql`.
- Seed counts: 2 tenants, 5 tenant users, 103 permissions, 2 currencies, 9 CoA rows, 2 warehouses, 4 product groups, 3 employees, 2 products.
- RLS verification passed: anon sees no tenant data; zero-permission user sees no products; products user sees only tenant A and can insert products; field user is blocked from direct journal inserts; manager permission bypass works.

Next recommended step:

- **Phase 2 — Authentication & Routing.**
