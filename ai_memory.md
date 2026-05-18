# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-18 (Phase 2 M4 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 M0 complete** - local Supabase stack, `db reset`, and RLS verification passed.
- **Phase 2 M1+M2 implemented** - Supabase providers, auth domain/data/controller, and permission tests are in place.
- **Phase 2 M3 complete** - `033_auth_custom_access_token_hook.sql` + `[auth.hook.custom_access_token]` in `config.toml`; JWTs include `tenant_id`, `tenant_user_id`, `account_type`.
- **Phase 2 M4 complete** - Login (`/login`), forgot password (`/forgot-password`), logout on dashboard; localized auth errors; `ErrorBanner` / `MessageBanner` / `AppTextField`.
- Migrations `001`-`034` apply cleanly with `supabase db reset`.
- `034_seed_auth_login_fix.sql` makes seeded auth users compatible with GoTrue password login after clean reset.
- CLI: use `npx --yes supabase` when `supabase` is not on PATH; `status -o env` returns `ANON_KEY` and `API_URL`.
- Initial route is `/login` (M4); M5 will add auth/permission redirect guards.
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
- `ErrorBanner` is errors-only; success uses `MessageBanner` success variant.

---

## Last Session Summary

**Date:** 2026-05-18
**Task:** Phase 2 M4 — Auth UI.

What was done:

- `login_screen.dart`, `forgot_password_screen.dart`, `auth_error_messages.dart`.
- Shared: `error_banner.dart`, `message_banner.dart`, `app_text_field.dart`; `AppBrandMark(required title)`.
- `app_router.dart`: initial `/login`, routes `/forgot-password`, `/dashboard`, `/` redirect to login.
- Dashboard logout via `AuthController.signOut()`; navigates to login only when `!authState.hasError`.
- Auth ARB strings (ar/en); `SocketException` → `networkUnavailable` in `auth_exception.dart`.
- Tests: `widget_test` expects login on boot; `login_screen_test` for missing anon key + validation with config override.

Verification:

- `dart format .`, `flutter gen-l10n`, `flutter analyze` (clean after redirect lint fix), `flutter test` 11/11 passed.

Next recommended step:

- Phase 2 M5 routing guards (unauthenticated redirect, permission-aware home).
