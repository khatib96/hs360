# Phase 0 — Local Project Scaffold

> Completed: 2026-05-16  
> Scope: Flutter app shell, folder structure, dev placeholders only. No features, no cloud, no paid services.

---

## What Was Done

- Flutter project created in repo root (`com.hs360`, Windows + Android).
- Core architecture folders under `lib/` (core, data, domain, features, shared).
- Riverpod + GoRouter + theme + bilingual ARB localization (ar default, RTL/LTR).
- Dashboard placeholder screen with HS360 branding colors from `DESIGN_SYSTEM.md`.
- Supabase Flutter client wired to **local placeholder** env (`127.0.0.1:54321`); init is non-fatal if local stack is down.
- `supabase/migrations/` and `supabase/functions/` scaffolded (`.gitkeep` only).
- Git repository initialized on `main` with remote `https://github.com/khatib96/hs360.git`.
- Dependencies added per Phase 0 spec (no Drift/offline yet).

---

## Run The App

```powershell
cd c:\Users\alkat\Searches\hs360
flutter pub get
flutter run -d windows
```

Optional Android:

```powershell
flutter run -d android
```

---

## Verify Environment

```powershell
flutter doctor -v
flutter --version
dart --version
git --version
docker --version
docker compose version
```

Expected on this machine (2026-05-16): Flutter 3.41.6, Dart 3.11.4, Docker available. Supabase CLI was **not** installed — local `config.toml` was not generated; install CLI later when starting Phase 1 database work.

---

## Quality Checks

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
```

---

## Local Supabase (Later)

Phase 0 does **not** require a running database. When ready (Phase 1+):

1. Install [Supabase CLI](https://supabase.com/docs/guides/cli) locally.
2. Run `supabase init` if needed and `supabase start` against Docker (self-hosted dev only).
3. Pass real local keys via `--dart-define`:

```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 `
  --dart-define=SUPABASE_ANON_KEY=<local-anon-key>
```

Default placeholders live in `lib/core/config/env.dart`.

---

## Intentionally Not Done (Phase 0)

| Item | Reason |
|------|--------|
| Domain / DNS | Deferred until product value is proven |
| VPS / production hosting | Per-tenant self-host comes after local dev |
| Supabase Cloud (paid) | Local/self-hosted only for now |
| Resend / WhatsApp APIs | Notifications in later phases |
| Apple / Google developer accounts | Store builds deferred |
| Real auth / RLS / migrations | Phase 1+ |
| Drift / offline sync | Out of v1 scope |
| Real Edge Functions | Phase 1+ |

Subscriptions, deployment, and paid third-party services are postponed until the application proves its value in local development.

---

## Project Layout (Phase 0)

```
lib/
  main.dart, app.dart
  core/          config, theme, routing, network, localization, errors, utils
  data/          models, repositories (empty)
  domain/        services, validators (empty)
  features/      auth/, dashboard/
  shared/        widgets, dialogs
  l10n/          app_en.arb, app_ar.arb
supabase/
  migrations/    .gitkeep
  functions/     .gitkeep
test/
integration_test/
```

---

## Next Step

**Phase 1 — Local database foundations:** install Supabase CLI, add `supabase/config.toml`, first migrations, and connect the app to a local Docker-backed stack (still no cloud production).
