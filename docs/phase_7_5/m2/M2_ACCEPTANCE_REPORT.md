# Phase 7.5 M2 Acceptance Report

> Status: **CLOSED / ACCEPTED**
>
> Date: 2026-07-25
>
> Next milestone: **M3 — Module Consolidation and Existing Screen Adoption**

## Outcome

M2 replaces the flat implementation-level navigation with the accepted
Option C product shell. Desktop navigation is now organized by business
module, can expand or collapse, and moves to an accessible drawer on narrow
screens. The shell owns the global title/context, locale control, contextual
navigation, user identity, settings area, and deterministic back behavior.

Existing URLs, route guards, permissions, feature screens, and business
behavior remain intact. No RPC, migration, database contract, or posting logic
was changed.

## Typed Navigation Contract

Navigation metadata is defined once in:

- `lib/core/routing/app_navigation_models.dart`;
- `lib/core/routing/app_navigation_catalog.dart`;
- `lib/core/routing/app_navigation.dart`.

The same typed contract drives module ordering, destination visibility,
contextual tabs, active-route resolution, global-action anchor visibility, and
back targets. Destinations and modules with no authorized implemented surface
are omitted rather than displayed as disabled or leaking labels.

`Daily Activity`, Audit, POS, and HR remain hidden because their Phase 7.5 or
future implementation has not landed. The existing `/field/today` route is
correctly retained as Today Agenda inside Appointments & Visits.

## Shell Structure

The former monolithic `app_shell.dart` is now a small orchestrator with focused
components:

| Responsibility | Implementation |
|----------------|----------------|
| Shell composition and responsive boundary | `AppShell` |
| Expanded, collapsed, and narrow navigation | `AppSidebar` |
| Global context and action anchors | `AppTopBar` |
| Permission-filtered in-module destinations | `AppContextualNavigation` |
| Signed-in identity and sign-out | `AppUserCard` |
| Brand treatments | `AppBrandMark`, `AppSidebarBrand` |
| Persisted shell collapse state | `appSidebarCollapsedProvider` |

Search, quick create, and notifications have permission-shaped top-bar
anchors, but remain deliberately disabled until their functional M4
implementation. This avoids presenting a false completed workflow.

## Navigation Safety

- Every implemented pre-M2 destination remains reachable under the same URL.
- Existing guards remain the authority for direct/deep-link access.
- Back targets preserve calendar dates and return edit/convert/preview flows to
  their deterministic source records or module parents.
- Dashboard, Today Agenda, and blocked screens no longer duplicate controls
  that the shell now owns.
- The permission-denied placeholder avoids rendering a second back button
  inside the content area.

## Acceptance Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | PASS — no issues |
| Complete Flutter suite | PASS — 1446 tests |
| Focused route/navigation/shell/accessibility suite | PASS — 111 tests |
| M2 deterministic screenshot suite | PASS — 6 tests |
| Prior invoice/contract/calendar screenshot gate | PASS — 21 tests |
| Expanded/collapsed desktop, AR RTL and EN LTR | PASS |
| Narrow drawer, AR RTL and EN LTR | PASS |
| RTL/LTR at 200% text scale | PASS |
| Keyboard traversal and semantic labels | PASS |
| Permission-label and count non-leakage | PASS |
| Existing route/deep-link/guard contract | PASS |
| Database/RPC/migration changes | NONE |

## Evidence

- Screenshot hashes and dimensions:
  `docs/phase_7_5/m2/M2_SCREENSHOT_MANIFEST.md`
- Durable evidence images:
  `docs/phase_7_5/m2/screenshots/`
- Typed navigation tests:
  `test/core/routing/app_navigation_test.dart`
- Permission and responsive shell tests:
  `test/shared/widgets/app_shell_permission_test.dart`
- Accessibility, direction, and text-scale tests:
  `test/shared/widgets/app_shell_m2_accessibility_test.dart`
- Deterministic screenshot harness:
  `test/screenshots/phase_7_5_m2_shell_screenshots.dart`

M2 is closed. M3 may consolidate existing screens inside these module
boundaries while keeping feature entities, permissions, and posting semantics
separate.
