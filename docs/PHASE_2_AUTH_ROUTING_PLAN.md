# Phase 2 — Authentication & Routing Plan

> Purpose: turn the Phase 1 database foundation into a usable authenticated app shell.
> This phase proves that a real user can log in, receive the correct tenant/session context, and land on the correct desktop or mobile entry screen based on account type and permissions.

---

## Arabic Summary

المرحلة الثانية ليست مرحلة بناء المنتجات أو الفواتير أو العقود. هدفها الأساسي هو فتح التطبيق بطريقة صحيحة وآمنة:

- شاشة تسجيل دخول حقيقية باستخدام Supabase Auth.
- جلسة مستخدم واضحة داخل Flutter.
- قراءة بيانات المستخدم الحالي وصلاحياته من قاعدة البيانات.
- توجيه المستخدم بعد الدخول حسب نوع الحساب والصلاحيات:
  - `manager` يرى لوحة التحكم.
  - مستخدم المكتب يرى واجهة desktop placeholder.
  - المندوب الميداني يرى شاشة `Today` الخاصة بالموبايل.
  - المستخدم بدون صلاحيات لا يرى وحدات غير مسموحة.
- تبديل اللغة بين العربية والإنجليزية مع حفظ الاختيار.
- تثبيت قواعد routing وpermission guards قبل بناء Phase 3.

نعم، الأفضل تنفيذ هذه المرحلة على خطوات `M0`, `M1`, `M2`, ... لأن كل خطوة تعتمد على التي قبلها، ولأن أي خطأ في auth أو routing سيؤثر على كل المراحل القادمة.

---

## Scope

### In Scope

- Supabase client provider.
- Auth repository and session model.
- Login screen.
- Forgot password request screen.
- Logout.
- Current user/session loading.
- Permission loading through `get_my_permissions()`.
- Custom Access Token hook for `tenant_id` and `account_type` claims.
- Permission-aware GoRouter redirects.
- Desktop dashboard placeholder.
- Mobile field `Today` placeholder.
- Empty/blocked home for users with no permissions.
- Locale controller with persistence.
- Focused widget and integration tests for auth/routing/locale.

### Out of Scope

- Full products, inventory, customers, contracts, invoices, vouchers, or reports.
- User invitation UI.
- Permission management UI.
- MFA enforcement UI. Keep the auth structure ready for MFA, but do not block Phase 2 on full MFA setup unless the scope is changed.
- Offline mobile sync.
- Production deployment.
- Supabase cloud configuration.

---

## Important Project Decisions

- HS360 uses only two account types: `manager` and `user`.
- Do not introduce fixed business roles like accountant, warehouse, admin, or driver as database roles.
- Supabase's standard JWT `role` remains `authenticated`; the business claim must be named `account_type`.
- Managers have full access. In `get_my_permissions()`, managers return `is_manager=true` and `permissions=[]`; the Flutter client must treat `is_manager=true` as full access.
- Users have zero permissions by default.
- Routing can hide screens for usability, but database RLS remains the real security boundary.
- The client must not send or trust a user-supplied `tenant_id` for writes. Server functions and RLS derive tenant context from the authenticated user.

---

## Milestone Map

| Milestone | Name | Result |
|---|---|---|
| M0 | Phase 2 Baseline | Local app and Supabase baseline verified before edits |
| M1 | Supabase Client Provider | Flutter has testable Supabase providers |
| M2 | Auth Domain/Data | App has session, permissions, and auth repository |
| M3 | Database Auth Hook | JWT includes `tenant_id` and `account_type` |
| M4 | Auth UI | Login, forgot password, logout are usable |
| M5 | Routing Guards | Authenticated users route to allowed destinations |
| M6 | Locale Persistence | Arabic/English toggle survives restart |
| M7 | Placeholders & Shell | Desktop/mobile/blocked placeholders are ready |
| M8 | Verification & Phase Close | Tests and quality checklist pass |

---

## M0 — Phase 2 Baseline

### Goal

Confirm that Phase 1 is still clean before changing auth/routing.

### Work

1. Check git status:

   ```powershell
   git status --short
   ```

2. Confirm local Supabase is available:

   ```powershell
   npx supabase status
   ```

3. Reset the local database and re-apply migrations:

   ```powershell
   npx supabase db reset
   ```

4. Run the Phase 1 RLS verification:

   ```powershell
   docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_1d_rls.sql
   ```

5. Confirm seeded login users remain available:

   | User | Email | Password | Expected Type |
   |---|---|---|---|
   | Manager | `owner@hayat-secret.test` | `Password123!` | `manager` |
   | Zero permission user | `zero@hayat-secret.test` | `Password123!` | `user` |
   | Products user | `products@hayat-secret.test` | `Password123!` | `user` |
   | Field agent | `field@hayat-secret.test` | `Password123!` | `user` |
   | Tenant B manager | `owner@tenant-b.test` | `Password123!` | `manager` |

### Files Expected To Change

None.

### Acceptance

- `db reset` succeeds.
- `phase_1d_rls_verification_passed` is returned.
- No unrelated local changes are present.

---

## M1 — Supabase Client Provider

### Goal

Replace the static-only Supabase access pattern with providers that the app, repositories, and tests can consume safely.

### Current State

`lib/core/network/supabase_client.dart` initializes Supabase through `SupabaseClientProvider.initialize()`, but it does not expose a Riverpod provider. Phase 2 needs providers for routing and auth state.

### Work

1. Keep initialization in `main.dart`.
2. Add a Riverpod provider for the active client.
3. Add a provider for auth state changes.
4. Add a small typed status for missing configuration so login UI can show a useful local-dev message when `SUPABASE_ANON_KEY` is not passed.
5. Avoid direct `Supabase.instance.client` usage outside `core/network` and repositories.

### Suggested Files

```text
lib/core/network/supabase_client.dart
lib/core/network/supabase_providers.dart
```

Use one file if the implementation stays small. Split when it starts mixing initialization, providers, and error states.

### Implementation Notes

- The app should still start if the local stack is not configured, but login must show a clear disabled/error state.
- Repositories should receive `SupabaseClient` through Riverpod, not construct it.
- Do not commit service-role keys.

### Tests

- Unit/widget test for the missing anon key UI state if practical.
- Static analysis must pass.

### Acceptance

- App boots with configured local Supabase.
- App boots without anon key and shows a controlled message instead of crashing.
- Auth code can watch the current Supabase auth state.

---

## M2 — Auth Domain/Data

### Goal

Create the app's session and permission model before building routing decisions.

### Work

1. Create `AppSession`.
2. Create `AppPermissions`.
3. Create `AuthRepository`.
4. Create `AuthController`.
5. Create providers for:
   - current Supabase `Session?`
   - loaded `AppSession?`
   - auth loading/error state
   - permissions

### Suggested Files

```text
lib/features/auth/data/auth_repository.dart
lib/features/auth/domain/app_session.dart
lib/features/auth/domain/app_permissions.dart
lib/features/auth/presentation/auth_controller.dart
```

### AppSession Fields

Minimum useful shape:

```dart
class AppSession {
  const AppSession({
    required this.userId,
    required this.email,
    required this.tenantId,
    required this.tenantUserId,
    required this.accountType,
    required this.displayName,
    required this.preferredLocale,
    required this.permissions,
  });
}
```

Use a `bool get isManager => accountType == 'manager';` helper.

### AppPermissions Rules

Required helpers:

- `can(String permissionId)`.
- `hasAny(Iterable<String> permissionIds)`.
- `hasModule(String modulePrefix)`.
- `isManager`.

Manager behavior:

```dart
if (isManager) return true;
return permissions.contains(permissionId);
```

### AuthRepository Responsibilities

- `signInWithPassword(email, password)`.
- `signOut()`.
- `requestPasswordReset(email)`.
- `loadCurrentAppSession()`.
- `loadMyPermissions()` by calling RPC `get_my_permissions`.
- Query the active `tenant_users` row for display name, preferred locale, and account type.

### Data Loading Order

After Supabase reports a signed-in session:

1. Get `auth.currentUser`.
2. Read JWT claims if present.
3. Query `tenant_users` for the active row.
4. Call `get_my_permissions()`.
5. Build `AppSession`.
6. Let router redirect based on `AppSession`.

### Error Handling

Map Supabase errors to stable UI messages:

- Invalid email/password.
- Network/local Supabase unavailable.
- User exists in Auth but has no active tenant user.
- User is inactive.
- Unknown auth error.

### Tests

- `AppPermissions` unit tests:
  - manager allows everything.
  - normal user allows granted permission only.
  - zero-permission user denies everything.
- Repository tests can be deferred if no local mocking pattern exists yet, but keep repository small and testable.

### Acceptance

- App can load a manager session.
- App can load a normal user session.
- App can distinguish zero-permission, products, and field users.

---

## M3 — Database Auth Hook

### Goal

Add claims to Supabase access tokens so the client can quickly know `tenant_id` and `account_type`, while RLS remains server-enforced.

### Work

1. Add migration `032_auth_custom_access_token_hook.sql`.
2. Create a Postgres function named `public.custom_access_token_hook(event jsonb)`.
3. Add `tenant_id`, `tenant_user_id`, and `account_type` claims when the user has exactly one active tenant user row.
4. Grant only `supabase_auth_admin` the right to execute it.
5. Configure local Supabase to call the hook.
6. Restart local Supabase after config change.
7. Verify newly issued tokens contain the claims.

### Suggested Migration

Use this as implementation guidance, then adjust while testing:

```sql
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  v_tenant_id uuid;
  v_tenant_user_id uuid;
  v_account_type public.user_account_type;
begin
  claims := event->'claims';

  select tu.tenant_id, tu.id, tu.account_type
  into v_tenant_id, v_tenant_user_id, v_account_type
  from public.tenant_users tu
  where tu.user_id = (event->>'user_id')::uuid
    and tu.is_active = true
  order by tu.joined_at asc
  limit 1;

  if v_tenant_id is not null then
    claims := jsonb_set(claims, '{tenant_id}', to_jsonb(v_tenant_id::text), true);
    claims := jsonb_set(claims, '{tenant_user_id}', to_jsonb(v_tenant_user_id::text), true);
    claims := jsonb_set(claims, '{account_type}', to_jsonb(v_account_type::text), true);
  end if;

  return jsonb_build_object('claims', claims);
end;
$$;

grant usage on schema public to supabase_auth_admin;

grant execute
  on function public.custom_access_token_hook(jsonb)
  to supabase_auth_admin;

revoke execute
  on function public.custom_access_token_hook(jsonb)
  from authenticated, anon, public;

grant select on public.tenant_users to supabase_auth_admin;

create policy "tenant_users_auth_admin_select"
  on public.tenant_users
  as permissive
  for select
  to supabase_auth_admin
  using (true);
```

### Local Config

Add to `supabase/config.toml`:

```toml
[auth.hook.custom_access_token]
enabled = true
uri = "pg-functions://postgres/public/custom_access_token_hook"
```

Restart after changing config:

```powershell
npx supabase stop
npx supabase start
```

### Verification

1. Sign in as `owner@hayat-secret.test`.
2. Inspect the access token claims.
3. Confirm:
   - `tenant_id = 00000000-0000-0000-0000-000000000101`
   - `tenant_user_id = 00000000-0000-0000-0000-000000000301`
   - `account_type = manager`
4. Repeat for `field@hayat-secret.test`.

### Important Notes

- If Supabase rejects the token after the hook, confirm required standard claims still exist. Do not replace the whole claims object unless all required claims are copied.
- If the hook cannot read `tenant_users`, verify grants and RLS policy for `supabase_auth_admin`.
- The migration should be repeatable through `npx supabase db reset`.

### Acceptance

- Local auth issues tokens with HS360 custom claims.
- Existing Phase 1 RLS tests still pass.
- No client write path depends on user-supplied tenant ids.

---

## M4 — Auth UI

### Goal

Build the screens users need to enter and leave the app.

### Work

1. Add login screen.
2. Add forgot password screen or inline forgot-password mode.
3. Add logout action in authenticated shells/placeholders.
4. Add localized strings in `app_ar.arb` and `app_en.arb`.
5. Add validation:
   - email required and email-shaped.
   - password required.
   - submit disabled during loading.
6. Add error and success states.

### Suggested Files

```text
lib/features/auth/presentation/login_screen.dart
lib/features/auth/presentation/forgot_password_screen.dart
lib/shared/widgets/app_text_field.dart
lib/shared/widgets/error_banner.dart
```

Only create shared widgets if the UI pattern repeats. Otherwise keep widgets local to auth.

### UI Requirements

- Arabic-first copy.
- Clean desktop width constraint for login form.
- Works on mobile viewport.
- Uses directional padding/margins.
- Password visibility toggle.
- Keyboard submit triggers login.
- No raw Supabase error text shown to users.

### Localized Strings

Add strings for:

- login title.
- email.
- password.
- sign in.
- forgot password.
- send reset link.
- invalid credentials.
- local Supabase not configured.
- logout.
- loading.
- retry.

### Acceptance

- Invalid login shows localized error.
- Valid manager login redirects away from login.
- Forgot password request shows a controlled success message in local dev.
- Logout returns to login.

---

## M5 — Routing Guards

### Goal

Make navigation respect auth state and permissions.

### Work

1. Split route names/constants from router if `app_router.dart` grows.
2. Add route guards outside the route list.
3. Add redirect logic:
   - unauthenticated user -> `/login`
   - authenticated user visiting `/login` -> their home route
   - manager -> `/dashboard`
   - user with field permissions -> `/field/today`
   - user with office/dashboard permissions -> `/dashboard`
   - user with zero permissions -> `/blocked`
4. Prevent redirect loops.
5. Refresh router when auth/session provider changes.

### Suggested Files

```text
lib/core/routing/app_router.dart
lib/core/routing/route_names.dart
lib/core/routing/route_guards.dart
lib/core/routing/router_refresh_notifier.dart
```

Split only when useful. Keep `app_router.dart` readable.

### Route Set For Phase 2

```text
/login
/forgot-password
/dashboard
/field/today
/blocked
```

The final route map from `docs/ARCHITECTURE.md` should not be built yet. Add only the routes needed for Phase 2 acceptance.

### Home Route Decision

Suggested priority:

1. `manager` -> `/dashboard`
2. has any of:
   - `visits.view_assigned`
   - `visits.edit_assigned`
   - `visits.complete_refill`
   -> `/field/today`
3. has any office permission:
   - `dashboard.view`
   - `products.view`
   - `customers.view`
   - `contracts.view`
   - `invoices.view`
   - `vouchers.view`
   - `inventory.view`
   -> `/dashboard`
4. otherwise -> `/blocked`

### Guard Rules

- `/login` and `/forgot-password` are public-only routes.
- `/dashboard` requires manager or any office permission.
- `/field/today` requires manager or field permission.
- `/blocked` requires authenticated session.

### Acceptance

- `owner@hayat-secret.test` -> `/dashboard`.
- `field@hayat-secret.test` -> `/field/today`.
- `products@hayat-secret.test` -> `/dashboard`.
- `zero@hayat-secret.test` -> `/blocked`.
- Logged-out user cannot open `/dashboard` directly.
- Logged-in user does not stay on `/login`.

---

## M6 — Locale Persistence

### Goal

Make Arabic/English selection survive app restart and drive the whole app direction.

### Current State

`localeProvider` reads `Env.defaultLocale`, and `Directionality` is already at the app root. Persistence is missing.

### Work

1. Add `shared_preferences` to `pubspec.yaml` if it is not already present.
2. Replace the simple `StateProvider<Locale>` with a controller that:
   - loads saved locale on startup.
   - defaults to `Env.defaultLocale`.
   - saves changes.
3. Keep `localeTextDirection(Locale locale)`.
4. Use `Locale('ar')` and `Locale('en')` consistently.

### Suggested Files

```text
lib/core/localization/locale_controller.dart
```

Optional if the controller grows:

```text
lib/core/localization/locale_repository.dart
```

### Acceptance

- Switch to English -> UI becomes LTR.
- Restart app -> English is still selected.
- Switch to Arabic -> UI becomes RTL.
- Auth screens and placeholders respond to direction changes.

---

## M7 — Placeholders & Shell

### Goal

Create the minimum authenticated screens needed to prove Phase 2 routing without starting Phase 3 features.

### Work

1. Update dashboard placeholder text from Phase 0 to Phase 2.
2. Add mobile field `Today` placeholder.
3. Add blocked/no-permissions screen.
4. Add logout to authenticated screens.
5. Keep placeholders simple but polished enough to support future modules.

### Suggested Files

```text
lib/features/dashboard/presentation/dashboard_screen.dart
lib/features/field_ops/presentation/field_today_screen.dart
lib/features/auth/presentation/blocked_screen.dart
lib/shared/widgets/app_shell.dart
```

### Screen Behavior

Dashboard:

- Shows app brand.
- Shows current user display name if available.
- Shows tenant/account type summary if available.
- Includes locale menu.
- Includes logout action.

Field Today:

- Mobile-friendly layout.
- Shows "Today" placeholder.
- Mentions assigned visits are coming in Phase 8 only if needed for development clarity, not as user-facing training text.
- Includes logout action.

Blocked:

- Explains that the user has no assigned permissions.
- Tells the user to contact a manager.
- Includes logout action.

### Acceptance

- All authenticated landing routes render without data feature dependencies.
- No placeholder screen calls Supabase directly.
- UI does not overflow in Arabic or English.

---

## M8 — Verification & Phase Close

### Goal

Prove Phase 2 is complete and safe to build Phase 3 on top of it.

### Required Commands

```powershell
flutter pub get
flutter analyze
flutter test
npx supabase db reset
docker exec -i supabase_db_hs360 psql -U postgres -d postgres < supabase/tests/phase_1d_rls.sql
```

If integration tests are practical in the current local setup:

```powershell
flutter test integration_test
```

### Manual Auth Matrix

| Login | Expected Route | Expected Result |
|---|---|---|
| `owner@hayat-secret.test` | `/dashboard` | Manager dashboard placeholder |
| `products@hayat-secret.test` | `/dashboard` | Office/dashboard placeholder |
| `field@hayat-secret.test` | `/field/today` | Mobile today placeholder |
| `zero@hayat-secret.test` | `/blocked` | No-permissions screen |
| bad password | `/login` | Localized invalid login error |
| logged out direct `/dashboard` | `/login` | Protected route blocked |

### Quality Checklist

- Widgets do not call Supabase directly.
- Router logic is readable and not a single large mixed-purpose file.
- Auth repository owns auth and session queries.
- Permission checks use `AppPermissions`.
- Manager bypass is implemented once.
- No service-role secret is in Flutter.
- No hardcoded tenant access in Flutter.
- Arabic and English strings exist for user-facing text.
- File-size scan is reviewed.

### File-Size Scan

```powershell
Get-ChildItem lib,supabase -Recurse -File |
  Where-Object { $_.Extension -in '.dart','.sql' } |
  ForEach-Object {
    [pscustomobject]@{
      Lines = (Get-Content $_.FullName | Measure-Object -Line).Lines
      File = $_.FullName
    }
  } |
  Where-Object { $_.Lines -gt 250 } |
  Sort-Object Lines -Descending
```

### Phase 2 Done Means

- Real login works against local Supabase.
- Session and permissions load after login.
- Redirects are permission-aware.
- Arabic/English direction works and persists.
- Phase 1 RLS still passes.
- The app has a clean foundation for Phase 3 Products & Inventory.

---

## Suggested Execution Order

Implement in this exact order:

1. M0 baseline.
2. M1 Supabase providers.
3. M2 session and permission domain.
4. M3 auth hook.
5. M4 login/logout UI.
6. M5 routing guards.
7. M6 locale persistence.
8. M7 placeholders.
9. M8 verification.

Do not build product or inventory screens during Phase 2. The temptation to start Phase 3 early should be avoided because products need stable auth, permissions, routing, and locale behavior first.

---

## Phase 2 Implementation Notes For Future Codex Sessions

When starting actual code work, begin with M0 and keep commits or work chunks aligned to milestones.

Recommended chunking:

- Chunk 1: M1 + M2.
- Chunk 2: M3.
- Chunk 3: M4 + M5.
- Chunk 4: M6 + M7 + M8.

Each chunk should end with:

- `flutter analyze`
- relevant tests
- short note in `ai_memory.md` only if the session ends before Phase 2 is complete

