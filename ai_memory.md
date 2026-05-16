# ai_memory.md — AI Collaboration Memory

> Updated 2026-05-16 (Phase 0 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0 complete** — Flutter app scaffold, Git repo, local dev placeholders only.
- Repo: `https://github.com/khatib96/hs360.git` on branch `main` (commit `f6d51ef`).
- App runs on Windows; Android platform scaffolded. `flutter analyze` clean; `flutter test` passes.
- Supabase Flutter client wired to local placeholders (`127.0.0.1:54321`); init is non-fatal if stack is down.
- **Supabase CLI not installed** — `supabase/migrations/` and `supabase/functions/` exist with `.gitkeep` only; no `config.toml`, no real migrations yet.
- **Not started:** auth, RLS, migrations, Drift/offline, paid services, VPS, cloud Supabase.
- Canonical docs: `docs/CANONICAL_DECISIONS.md`, `docs/MVP_SCOPE.md`, `docs/RPC_SPEC.md`.
- Phase 0 runbook: `docs/PHASE_0_SETUP.md`.

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
**Task:** Phase 0 — local project setup only (no paid services, no cloud, no VPS).

What was done:

- Environment verified: Flutter 3.41.6, Dart 3.11.4, Docker, Git; Supabase CLI absent.
- `git init` on `main`, remote `origin` → GitHub; commit + push `Phase 0 project setup`.
- `flutter create --org com.hs360 --platforms windows,android .` in repo root (docs preserved).
- Dependencies per Phase 0 spec (no Drift/offline).
- Folder structure under `lib/`, `supabase/`, `test/`, `integration_test/`.
- Core app: Riverpod, GoRouter, theme (DESIGN_SYSTEM colors), ARB l10n (ar/en, RTL/LTR), dashboard placeholder, Supabase client placeholders.
- `docs/PHASE_0_SETUP.md` added.
- Verified: `pub get`, `dart format`, `analyze` (0 issues), `test` (1 passed), `build windows` succeeded.

Deferred intentionally (documented in `PHASE_0_SETUP.md`):

- Supabase Cloud, VPS, domain, Resend, WhatsApp, store developer accounts, real auth/migrations, Drift, GitHub Actions CI.

Next recommended step:

- **Phase 1 — Local database foundations:** install Supabase CLI, `supabase init` + local Docker stack, first migrations + RLS, connect app with `--dart-define` for local keys.
