# ai_memory.md - AI Collaboration Memory

> Updated 2026-05-19 (Phase 3 M0+M0.5 complete).
> Keep this file short. It is for continuity between AI tools, not full project documentation.

---

## Current Project State

- **Phase 0-1D complete** - local Supabase database foundation is verified.
- **Phase 2 M0 complete** - local Supabase stack, `db reset`, and RLS verification passed.
- **Phase 2 M1+M2 implemented** - Supabase providers, auth domain/data/controller, and permission tests are in place.
- **Phase 2 M3 complete** - `033_auth_custom_access_token_hook.sql` + `[auth.hook.custom_access_token]` in `config.toml`; JWTs include `tenant_id`, `tenant_user_id`, `account_type`.
- **Phase 2 M4 complete** - Login (`/login`), forgot password (`/forgot-password`), logout on authenticated shells; localized auth errors; `ErrorBanner` / `MessageBanner` / `AppTextField`.
- **Phase 2 M5 complete** - Permission-aware GoRouter guards; routes `/login`, `/forgot-password`, `/dashboard`, `/field/today`, `/blocked`; `RouterRefreshNotifier` on auth/session changes.
- **Phase 2 M6 complete** - Locale persistence via `shared_preferences`; `LocaleController` loads/saves `preferred_locale`; `localeProvider` sync alias for `app.dart`.
- **Phase 2 M7 complete** - Phase 2 placeholders on dashboard, field today, blocked; auth widgets `SignOutIconButton`, `AuthenticatedUserSummary` under `features/auth/presentation/widgets/` (not `shared/`).
- **Phase 2 M8 complete** - Phase close verification passed: Flutter analyze/tests, integration placeholder, Supabase reset, Phase 1D RLS verification, file-size/security scan review.
- **Phase 3 M0+M0.5 complete** - baseline checks passed and pre-migration local backups/snapshots were created under `supabase/.temp/` (not committed).
- Migrations `001`-`034` apply cleanly with `supabase db reset`.
- `034_seed_auth_login_fix.sql` makes seeded auth users compatible with GoTrue password login after clean reset.
- CLI: use `npx --yes supabase` when `supabase` is not on PATH; `status -o env` returns `ANON_KEY` and `API_URL`.
- Initial route `/login`; authenticated users redirect to home by permissions (manager/products → dashboard, field → `/field/today`, zero → `/blocked`).
- `AuthRepository.loadCurrentAppSession()` uses DB `tenant_users` as authoritative; JWT decode remains best-effort.
- Routing: `app_routes.dart`, `route_guards.dart` (`guardRedirectForPath` pure + `guardRedirect` wrapper with `ref.read`), `router_refresh_notifier.dart`.
- Locale: `locale_controller.dart` + generated `locale_controller.g.dart`; prefs key `preferred_locale`; only `ar` / `en`.

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
- Locale: `_defaultLocale()` does not call `normalizeLocale()` (no recursion). Invalid saved codes fall back to `ar`. `setLocale` updates UI optimistically then saves; no `AsyncError` on prefs write failure in M6.
- Locale startup: brief flash of default `ar` while async load is acceptable in M6; session-aware loading gate deferred.
- Auth-specific UI (`SignOutIconButton`, `AuthenticatedUserSummary`) lives under `features/auth/presentation/widgets/`, not `shared/widgets`, so shared never depends on auth.

---

## Locale API (M6)

| Use | Call |
|-----|------|
| Read locale in widgets / `MaterialApp` | `ref.watch(localeProvider)` |
| Change language | `ref.read(localeControllerProvider.notifier).setLocale(locale)` |
| Text direction | `localeTextDirection(locale)` at app root (unchanged) |

Supported: `Locale('ar')`, `Locale('en')`. Default when unset: `Env.defaultLocale` (`ar`).

---

## Last Session Summary

**Date:** 2026-05-19  
**Task:** Phase 3 M0+M0.5 - Baseline and safety snapshot.

### What was done

- Ran Phase 3 baseline verification before product/inventory work.
- Confirmed local Supabase is running, `db reset` applies migrations `001`-`034`, Flutter analyze/tests pass, and Phase 1D RLS still passes.
- Created pre-migration safety files in `supabase/.temp/`: schema dump, data dump, and full `pg_dump`.

### Verification

```text
flutter pub get
flutter analyze                  -> no issues
flutter test                     -> 48/48 passed
npx --yes supabase db reset      -> passed
phase_1d_rls.sql                 -> phase_1d_rls_verification_passed
supabase/.temp backups           -> created, not tracked by git
```

### Manual acceptance

Manual UI routing smoke was not repeated in-browser during M0; command-level baseline passed.

### Next recommended step

- **Phase 3 M1** - Database gap review and inventory helpers.
