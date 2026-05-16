# ai_memory.md — AI Collaboration Memory

> Updated 2026-05-16 (Phase 1B complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0 complete** — Flutter scaffold on `main`.
- **Phase 1A complete** — local Supabase + migrations `001`–`005`.
- **Phase 1B complete** — migrations `006`–`026`; **35 public tables** (5 foundation + 30 business).
- CLI: `npx supabase` when `supabase` is not on PATH.
- **26 public enums** unchanged (`user_account_type` in 002 + 25 in 003).
- **12 deferred FKs** added via `ALTER` in 016/019/020/021/022 (not `032_late_fks.sql`).
- **No RLS** (Phase 1C). **No seed** (Phase 1D). **No 027+** migrations yet.
- Flutter: `SUPABASE_ANON_KEY` empty default; `scripts/run-local.ps1`.
- Runbooks: `docs/PHASE_0_SETUP.md`, `docs/PHASE_1A_SETUP.md`.

---

## Decisions Confirmed

- Access control is Manager/User only.
- Users have zero permissions by default.
- RLS uses `user_has_permission()`.
- No hardcoded tenant access roles.
- Currencies are dynamic.
- v1 has one default currency per tenant.
- KWD is the Hayat Secret example, not a hardcoded system currency.
- Field-level hiding uses `security_invoker = true` safe views or permission-shaped RPCs.
- Contract snapshots are frozen forever.
- Mobile offline sync is out of v1.
- Van Stock Alerts are explicitly not needed.
- Approved product-improvement ideas should be placed by phase in `docs/BUILD_PLAN.md`.

---

## Last Session Summary

**Date:** 2026-05-16  
**Task:** Phase 1B — core business schema (`006`–`026`).

What was done:

- 21 migrations from `DATABASE_SCHEMA.md` sections 3–18.
- Forward-reference FKs via named `ALTER` constraints (016, 019, 020, 021, 022).
- `npx supabase db reset` succeeded; verified 35 tables, 26 enums, 12 deferred FKs, 0 RLS.
- `BUILD_PLAN.md` Phase 1B marked complete.

Not done (by design):

- `027`–`031` (functions, views, triggers, RLS, seed), `032_late_fks.sql`, Flutter changes.

Next recommended step:

- **Phase 1C** — `027_functions.sql`, `028_views.sql`, `029_triggers.sql`, `030_rls_policies.sql`.
