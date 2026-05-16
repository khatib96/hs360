# Phase 1A — Local Supabase Foundation

> Completed after Phase 0. Local Docker stack + foundation migrations `001`–`005` only.

---

## Prerequisites

- Docker Desktop running
- Supabase CLI (this repo uses `npx supabase` if the CLI is not on PATH)
- Flutter SDK (Phase 0)

Install CLI (choose one; requires approval if changing global toolchain):

- Scoop: `scoop install supabase`
- Manual: [Supabase CLI releases](https://github.com/supabase/cli/releases)

---

## Start local stack

```powershell
cd c:\Users\alkat\Searches\hs360
npx supabase start
```

Apply / re-apply migrations:

```powershell
npx supabase db reset
```

Check services and keys (do **not** commit output):

```powershell
npx supabase status
npx supabase status -o env
```

Expected API URL: `http://127.0.0.1:54321`

---

## Migrations in this phase

| File | Contents |
|------|----------|
| `001_extensions.sql` | `pgcrypto` |
| `002_tenants.sql` | `tenants`, `tenant_users`, `user_account_type`, tenant helper functions |
| `003_enums.sql` | 25 business enums (26 total with `user_account_type`) |
| `004_permissions.sql` | `permissions`, `user_permissions`, `user_has_permission` |
| `005_currencies.sql` | `currencies`, tenant default currency FK |

Verify enum count (expect **26** in `public`):

```powershell
npx supabase db query "select count(*) as enum_count from pg_type t join pg_namespace n on n.oid = t.typnamespace where t.typtype = 'e' and n.nspname = 'public';"
```

---

## Run Flutter against local Supabase

`lib/core/config/env.dart` uses an empty default for `SUPABASE_ANON_KEY`. Pass the key at runtime.

**Option A — script (recommended):**

```powershell
.\scripts\run-local.ps1
```

**Option B — manual dart-define:**

```powershell
# Replace <anon-key> with ANON_KEY from: npx supabase status -o env
flutter run -d windows `
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 `
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

---

## Security note (Phase 1A)

RLS is **not** enabled yet. Foundation tables are not protected by tenant policies until Phase 1C (`030_rls_policies.sql`). Do not expose these tables through real app flows until then.

The `permissions` catalog is **empty** until Phase 1D seed (`031_seed.sql`).

---

## Not in Phase 1A

- Migrations `006`–`026` (Phase 1B)
- RLS, functions, views, triggers (Phase 1C)
- Seed data (Phase 1D)
- Cloud Supabase, VPS, paid services
- `supabase/functions/` implementation

---

## Next step

**Phase 1B — Core business schema:** migrations `006`–`026` per `docs/DATABASE_SCHEMA.md` section 21.
