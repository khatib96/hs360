# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-19 (Phase 2 M6 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 M0 complete** - local Supabase stack, `db reset`, and RLS verification passed.
- **Phase 2 M1+M2 implemented** - Supabase providers, auth domain/data/controller, and permission tests are in place.
- **Phase 2 M3 complete** - `033_auth_custom_access_token_hook.sql` + `[auth.hook.custom_access_token]` in `config.toml`; JWTs include `tenant_id`, `tenant_user_id`, `account_type`.
- **Phase 2 M4 complete** - Login (`/login`), forgot password (`/forgot-password`), logout on dashboard; localized auth errors; `ErrorBanner` / `MessageBanner` / `AppTextField`.
- **Phase 2 M5 complete** - Permission-aware GoRouter guards; routes `/login`, `/forgot-password`, `/dashboard`, `/field/today`, `/blocked`; `RouterRefreshNotifier` on auth/session changes.
- **Phase 2 M6 complete** - Locale persistence via `shared_preferences`; `LocaleController` loads/saves `preferred_locale`; `localeProvider` sync alias for `app.dart`.
- Migrations `001`-`034` apply cleanly with `supabase db reset`.
- `034_seed_auth_login_fix.sql` makes seeded auth users compatible with GoTrue password login after clean reset.
- CLI: use `npx --yes supabase` when `supabase` is not on PATH; `status -o env` returns `ANON_KEY` and `API_URL`.
- Initial route `/login`; authenticated users redirect to home by permissions (manager/products → dashboard, field → `/field/today`, zero → `/blocked`).
- `AuthRepository.loadCurrentAppSession()` uses DB `tenant_users` as authoritative; JWT decode remains best-effort.
- Routing: `app_routes.dart`, `route_guards.dart` (`guardRedirectForPath` pure + `guardRedirect` wrapper with `ref.read`), `router_refresh_notifier.dart`.

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

**Date:** 2026-05-19
**Task:** Phase 2 M6 — Locale Persistence.

What was done:

- `shared_preferences` in pubspec; `locale_controller.dart` refactored with `@Riverpod`, `LocaleRepository`, `LocaleController.setLocale`, `localeProvider` alias.
- `_defaultLocale()` / `normalizeLocale` / `localeFromCode` — strict `ar`/`en`, no recursion.
- Dashboard language menu uses `localeControllerProvider.notifier.setLocale`.
- `test/core/localization/locale_controller_test.dart` — 15 tests.

Verification:

- `flutter pub get`, `build_runner`, `dart format .`, `flutter analyze` (clean), `flutter test` 46/46 passed.

Next recommended step:

- Phase 2 M7 placeholders & shell polish.
