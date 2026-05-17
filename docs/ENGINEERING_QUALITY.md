# ENGINEERING_QUALITY.md — Maintainability Rules

> Keep the codebase easy to change. Review this at the end of every phase.

---

## Why This Exists

Large mixed-purpose files become hard to test, review, and safely change. HS360 should stay modular from the start, especially before UI and routing work begins in Phase 2.

---

## File Size Guidelines

| Size | Action |
|------|--------|
| Under 250 lines | Usually fine |
| 250–350 lines | Review for extraction |
| 350–500 lines | Split unless there is a clear reason |
| Over 500 lines | Must be explained in the phase summary |

These are guidelines, not blind rules. A generated localization file can be large. A hand-written screen/controller should not become a dumping ground.

---

## Responsibility Boundaries

- **Screens/widgets:** render UI and call controllers.
- **Controllers/providers:** manage UI state, loading, errors, and orchestration.
- **Repositories:** own Supabase queries and RPC calls.
- **Domain services:** own business rules, calculations, and validation.
- **Shared widgets:** hold reusable UI components.

Avoid files that mix UI layout, routing, permissions, database calls, and business logic.

---

## Feature Structure

Use this shape for app features:

```text
lib/features/<feature>/
  data/
  domain/
  presentation/
```

Example for Phase 2 auth work:

```text
lib/features/auth/
  data/
    auth_repository.dart
  domain/
    app_session.dart
    app_permissions.dart
  presentation/
    login_screen.dart
    auth_controller.dart
    permission_controller.dart
```

Only create folders that contain real files. Avoid empty architecture just for appearance.

---

## Routing Rules

Do not let routing become one large unreadable file.

Start simple, then split when needed:

```text
lib/core/routing/
  app_router.dart
  route_names.dart
  route_guards.dart
```

`app_router.dart` should compose routing. Guards and permission logic should live outside it once they become non-trivial.

---

## UI Component Reuse

Move repeated UI into focused widgets:

- primary/secondary buttons
- loading states
- empty states
- error banners
- text fields
- dashboard stat cards
- permission-gated wrappers

Use `lib/shared/widgets/` for components reused across features. Keep feature-specific widgets inside the feature.

---

## Phase-End Checklist

Before marking any phase complete:

- Run the file-size scan.
- Review files over 250 lines.
- Split files over 350 lines unless justified.
- Confirm widgets do not call Supabase directly.
- Confirm business rules are not inside UI widgets.
- Check for duplicated widgets, queries, and permission logic.
- Document any intentional exception in the phase summary.

PowerShell scan:

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

---

## Acceptable Large Files

Some files may be large by nature:

- generated localization files
- generated platform files
- long SQL migrations for RLS/seed
- documentation files

Even then, prefer clear section comments and stable organization.

---

## Default Decision

When unsure, split by responsibility. The goal is not many tiny files; the goal is files that can be understood and changed safely.
