# Phase 7.5 M1 Acceptance Report

> Status: **CLOSED / ACCEPTED**
>
> Date: 2026-07-24
>
> Next milestone: **M2 — Desktop Shell and Typed Navigation**

## Outcome

M1 turns the accepted Option C direction into a reusable light-theme
foundation. It separates decorative brand gold from accessible action/focus
gold, introduces semantic success/warning/error/info pairs, retains the bundled
Noto families, and centralizes spacing, radii, control sizes, component states,
and warm stone/cream surfaces.

No dark mode, font-family replacement, RPC, migration, database contract, or
business workflow was introduced.

## Shared Foundation

| Need | Shared implementation |
|------|-----------------------|
| Page context, title, subtitle, and actions | `AppPageHeader` |
| Search/filter surface and compact density | `AppFilterBar` |
| Loading, error, and empty states | `AppStateView` |
| Accessible semantic labels | `AppStatusBadge` |
| List/table boundary | `AppTableFrame` |
| Detail sections and responsive rows | `AppDetailSection`, `AppInfoRow` |
| Sensitive/destructive confirmation | `AppSensitiveActionDialog` |
| Localized currency and tabular figures | `MoneyDisplay` |

The primitives are intentionally focused. Feature-owned queries, permissions,
columns, and domain behavior remain in their existing features; no configurable
mega-table was introduced.

## Representative Adoption

- Inventory list: shared compact filter, state, and table frame.
- Finance invoice list/detail: shared filter, state, table, and detail section
  patterns; money keeps tenant currency formatting.
- Contracts list/detail/closure: shared list/detail/status/sensitive-action
  patterns.
- Customers list/detail: shared filter, state, table, and status patterns.

The previously recorded contract-detail overflow at 390 px is resolved through
responsive shared label/value rows in Arabic and English. Contract behavior was
not changed.

## Acceptance Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | PASS — no issues |
| Complete Flutter suite | PASS — 1431 tests |
| New M1 foundation suite | PASS — 7 tests |
| Representative Inventory/Finance/Contracts/Customers suite | PASS — 38 tests |
| Contract regression captures | PASS — 4 Arabic/English desktop/narrow cases |
| Invoice regression captures | PASS — 6 Arabic/English representative cases |
| M1 foundation captures | PASS — 4 Arabic/English desktop/narrow cases |
| WCAG AA text-pair checks | PASS — all locked pairs at least 4.5:1 |
| Keyboard focus order | PASS |
| RTL/LTR at 200% text scale | PASS |
| Destructive dialog state | PASS |

The locked headline contrast pairs are White/Action Gold 4.83:1,
White/Action Hover 6.97:1, and Charcoal/Brand Gold 7.73:1.

## Evidence

- Screenshot hashes and dimensions:
  `docs/phase_7_5/m1/M1_SCREENSHOT_MANIFEST.md`
- Durable evidence images:
  `docs/phase_7_5/m1/screenshots/`
- Automated foundation tests:
  `test/shared/widgets/app_ui_foundation_test.dart`
- Deterministic M1 gallery:
  `test/screenshots/phase_7_5_m1_foundation_screenshots.dart`

M1 is closed. M2 may start from this foundation while preserving the M0
route/module/permission contracts and the M0.5 regression baseline.
