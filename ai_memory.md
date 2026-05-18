# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-17 (Phase 2 M1+M2 implemented; one pre-M3 fix pending).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 M0 complete** - local Supabase stack, `db reset`, and RLS verification passed.
- **Phase 2 M1+M2 implemented** - Supabase providers, auth domain/data/controller, and permission tests are in place.
- Migrations `001`-`032` apply cleanly with `supabase db reset`; `032_tenant_users_self_select.sql` allows authenticated users to read only their own `tenant_users` row for session bootstrap.
- **Phase 1C complete** - `027_functions`, `028_views`, `029_triggers`, `030_rls_policies`; verified with local `db reset`.
- **Phase 1D complete** - `031_seed.sql` + `supabase/tests/phase_1d_rls.sql`.
- CLI: use `npx supabase` or the cached Supabase CLI binary when `supabase` is not on PATH.
- **RLS:** enabled on all 35 public tables in `030_rls_policies.sql` (115 policies before 032 self-select).
- **Safe views:** `products_safe`, `contracts_safe` (`security_invoker = true`).
- **Helpers (027):** `current_tenant_user_id`, `current_employee_id`, `get_my_permissions`, `touch_updated_at`.
- **Triggers (029):** `audit_log_row` (narrow WHEN clauses), `user_permissions` insert/delete audit, `vouchers` insert/delete only, journal balance, last-manager + self-mod guards, `touch_updated_at` on 6 tables.
- **Seed:** Hayat Secret tenant, Tenant B isolation tenant, 5 test users, 103 permissions, KWD currencies, CoA, warehouses, product groups, employees, products.
- `get_my_permissions`: managers return `permissions: []`; clients must treat `is_manager=true` as full access.
- Review fix complete: `AuthRepository.loadCurrentAppSession()` now uses DB `tenant_users` profile as authoritative for `tenantId`, `tenantUserId`, and `accountType`; JWT decode remains best-effort only.

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
- `tenant_users_select_self` is only for session bootstrap; it is not a replacement for `settings.users.view`.

---

## Last Session Summary

**Date:** 2026-05-17
**Task:** Phase 2 M0, M1, and M2 auth foundation review.

What was done:

- M0 re-run after Docker restart: `supabase status`, `supabase db reset`, and Phase 1D RLS verification passed.
- Cursor implemented M1+M2:
  - `lib/core/network/supabase_providers.dart` + generated provider file.
  - `lib/core/errors/app_exception.dart` and `auth_exception.dart`.
  - Auth domain/data/controller files under `lib/features/auth/`.
  - `test/core/network/supabase_config_status_test.dart`.
  - `test/features/auth/domain/app_permissions_test.dart`.
  - `supabase/migrations/032_tenant_users_self_select.sql`.
- `032_tenant_users_self_select.sql` was added because existing `tenant_users_select` requires `settings.users.view`; normal users need self-read access to build `AppSession`.

Verification:

- `flutter analyze` passed with no issues.
- `flutter test` passed: 9/9 tests.
- `supabase db reset` succeeded through `032_tenant_users_self_select.sql`.
- `supabase/tests/phase_1d_rls.sql` returned `phase_1d_rls_verification_passed`.
- Manual RLS spot check: `field@hayat-secret.test` can select only its own `tenant_users` row.

Next recommended step:

- Continue Phase 2 with M3 JWT hook or M4 auth UI, depending on chosen chunk order.
