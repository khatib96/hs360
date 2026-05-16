# ai_memory.md — AI Collaboration Memory

> Updated 2026-05-16 to document cross-tool AI context.
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- Workspace currently contains documentation only. No Flutter app, Supabase migrations, tests, or Git repository yet.
- Canonical decisions are now tracked in `docs/CANONICAL_DECISIONS.md`.
- Strict v1 scope is now tracked in `docs/MVP_SCOPE.md`.
- Required stored function contracts are now tracked in `docs/RPC_SPEC.md`.

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

Requested task:

- Resolve critical conflicts in project documentation before implementation.
- Add canonical decision, MVP scope, and RPC spec documents.
- Add AI memory file for future AI-tool handoff.

Files changed or added:

- `README.md`
- `docs/DATABASE_SCHEMA.md`
- `docs/SECURITY.md`
- `docs/ARCHITECTURE.md`
- `docs/DESIGN_SYSTEM.md`
- `docs/PRODUCTS_DETAIL.md`
- `docs/CONTRACTS_LOGIC.md`
- `docs/PAYMENT_SYSTEM.md`
- `docs/CUSTOMER_LEDGER.md`
- `docs/FIELD_OPS.md`
- `docs/PROJECT.md`
- `docs/CANONICAL_DECISIONS.md`
- `docs/MVP_SCOPE.md`
- `docs/RPC_SPEC.md`
- `ai_memory.md`

Next recommended step:

- Start Phase 0 scaffolding after reviewing the updated phased roadmap.
