# ai_memory.md — AI Collaboration Memory

> Updated 2026-05-16 (Phase 1A complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0 complete** — Flutter scaffold on `main`.
- **Phase 1A complete** — local Supabase via Docker + migrations `001`–`005`.
- CLI: use `npx supabase` when `supabase` is not on PATH.
- Local stack: `npx supabase start` / `db reset` / `status -o env`.
- Foundation tables: `tenants`, `tenant_users`, `permissions`, `user_permissions`, `currencies`.
- Helper functions: `current_tenant_id`, `current_account_type`, `is_manager`, `user_has_permission`, `tenant_default_currency`.
- **26 public enums** (`user_account_type` in 002 + 25 in 003).
- **No RLS yet** (Phase 1C). **No seed** (Phase 1D). **No 006+ tables** (Phase 1B).
- Flutter: `SUPABASE_ANON_KEY` default is empty; use `scripts/run-local.ps1` or `--dart-define`.
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
**Task:** Phase 1A — local Supabase foundation only.

What was done:

- `npx supabase init`; `config.toml` committed.
- Migrations `001_extensions` through `005_currencies` from `DATABASE_SCHEMA.md`.
- `npx supabase start` + `db reset` succeeded; enum count verified = 26.
- `env.dart` anon default cleared; `supabase_client.dart` warns when key missing.
- `scripts/run-local.ps1` reads keys from `supabase status -o env` at runtime.
- `docs/PHASE_1A_SETUP.md`; `BUILD_PLAN.md` Phase 1A marked complete.

Not done (by design):

- Phase 1B+ migrations, RLS (1C), seed (1D), cloud/VPS, functions implementation.

Next recommended step:

- **Phase 1B — Core business schema:** migrations `006`–`026`.
