# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-18 (Phase 2 M3 complete; seed login fix added).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 M0 complete** - local Supabase stack, `db reset`, and RLS verification passed.
- **Phase 2 M1+M2 implemented** - Supabase providers, auth domain/data/controller, and permission tests are in place.
- **Phase 2 M3 complete** - `033_auth_custom_access_token_hook.sql` + `[auth.hook.custom_access_token]` in `config.toml`; JWTs include `tenant_id`, `tenant_user_id`, `account_type` from first active `tenant_users` row (`order by joined_at`).
- Migrations `001`-`034` apply cleanly with `supabase db reset`.
- `032_tenant_users_self_select.sql` allows authenticated users to read only their own `tenant_users` row for session bootstrap.
- **Phase 1C complete** - `027_functions`, `028_views`, `029_triggers`, `030_rls_policies`; verified with local `db reset`.
- **Phase 1D complete** - `031_seed.sql` + `supabase/tests/phase_1d_rls.sql`.
- CLI: use `npx --yes supabase` when `supabase` is not on PATH; `status -o env` returns `ANON_KEY` and `API_URL`.
- **RLS:** enabled on all 35 public tables in `030_rls_policies.sql` (115 policies before 032 self-select).
- **Safe views:** `products_safe`, `contracts_safe` (`security_invoker = true`).
- **Helpers (027):** `current_tenant_user_id`, `current_employee_id`, `get_my_permissions`, `touch_updated_at`.
- **Triggers (029):** `audit_log_row` (narrow WHEN clauses), `user_permissions` insert/delete audit, `vouchers` insert/delete only, journal balance, last-manager + self-mod guards, `touch_updated_at` on 6 tables.
- **Seed:** Hayat Secret tenant, Tenant B isolation tenant, 5 test users, 103 permissions, KWD currencies, CoA, warehouses, product groups, employees, products.
- `034_seed_auth_login_fix.sql` makes seeded auth users compatible with GoTrue password login after clean reset (`instance_id` + token defaults).
- `get_my_permissions`: managers return `permissions: []`; clients must treat `is_manager=true` as full access.
- `AuthRepository.loadCurrentAppSession()` uses DB `tenant_users` as authoritative; JWT decode remains best-effort.

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
- Custom access token hook: execute granted only to `supabase_auth_admin`; `tenant_users_auth_admin_select` policy for hook reads.

---

## Last Session Summary

**Date:** 2026-05-18
**Task:** Phase 2 M3 — Database Auth Hook.

What was done:

- Added `supabase/migrations/033_auth_custom_access_token_hook.sql` (`custom_access_token_hook`, grants/revokes, `tenant_users_auth_admin_select`).
- Enabled `[auth.hook.custom_access_token]` in `supabase/config.toml`.
- Restarted local Supabase (`stop` / `start`) after config change; `db reset` through `033`.
- Added `034_seed_auth_login_fix.sql` after review found clean-reset password login returned `invalid_credentials` for seeded users.

Verification:

- `phase_1d_rls_verification_passed` after reset through `034`.
- Owner JWT: `tenant_id=...0101`, `tenant_user_id=...0301`, `account_type=manager`.
- Field JWT: `tenant_id=...0101`, `tenant_user_id=...0305`, `account_type=user`.
- Hook runs on login (auth logs: `Hook ran successfully`).

Next recommended step:

- Phase 2 M4 auth UI (login, forgot password, logout).
