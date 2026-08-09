# Phase 7.5 M5 Acceptance Report

> Status: **CLOSED / ACCEPTED**
>
> Date: 2026-08-05
>
> Next milestone: **M6 — Record Lifecycle Actions and Basic Audit Review**

## Outcome

The Phase 2 placeholder Dashboard is replaced by a trusted operational home,
and Daily Activity is now a separate permission-shaped primary module. Both
surfaces use the tenant's business date and show only records already visible
to the signed-in user.

## Delivered Product

| Area | Accepted result |
|------|-----------------|
| Dashboard slot 1 | Today's visible schedule: total, completed, and remaining |
| Dashboard slot 2 | Visible overdue pending work |
| Dashboard slot 3 | Active contracts split into trials/rentals, plus asset condition when permitted |
| Dashboard slot 4 | Month-to-date collections and outstanding receivables when permitted |
| Drill-down | Every KPI opens the exact paginated source rows used by its summary |
| Daily Activity | Selected-date calendar, visit, contract, finance, cash/bank, and inventory projections |
| Responsive UI | Four-slot desktop grid and compact/narrow flow with loading, empty, error, retry, and paging states |
| Localization | Arabic RTL and English LTR labels, dates, numbers, status presentation, and source actions |

## Database Boundary

Migration `106_phase_7_5_m5_dashboard_daily_activity.sql` adds three
authenticated read RPCs and one API-revoked internal canonical Dashboard row
source. It also adds bounded read indexes for contract, invoice, voucher,
visit, and posted-journal date paths.

No posting mutation, valuation formula, contract lifecycle mutation, calendar
generation rule, or audit payload was changed. Daily Activity reads safe
projections from accepted sources and uses current server-side permission,
tenant, assignment, and business-date checks.

## Acceptance Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | PASS — no issues |
| Complete Flutter suite | PASS — 1461 tests |
| Focused M5/navigation/shell suite | PASS — 40 tests |
| M5 SQL ACL/isolation/reconciliation suite | PASS |
| Full SQL/concurrency/performance runner | PASS |
| Final baseline/calendar pollution gates | PASS |
| KPI-to-drill-down reconciliation | PASS |
| Zero-permission and assigned-only shaping | PASS |
| Cash/bank-only Daily Activity scope | PASS |
| Tenant isolation | PASS |
| Tenant-local business date and displayed time | PASS |

## Evidence

- Migration: `supabase/migrations/106_phase_7_5_m5_dashboard_daily_activity.sql`
- SQL acceptance: `supabase/tests/phase_7_5_m5_dashboard_daily_activity.sql`
- Flutter contracts: `test/features/dashboard/data/dashboard_repository_test.dart`
- Flutter surfaces: `test/features/dashboard/presentation/dashboard_m5_screen_test.dart`
- Navigation/shell regression: `test/core/routing/app_navigation_test.dart` and
  `test/shared/widgets/app_shell_permission_test.dart`
- Checksum: `docs/phase_7_5/m5/M5_MIGRATION_CHECKSUMS.txt`

M5 is closed. M6 may now standardize lifecycle correction actions and expose
the basic redacted Audit Review surface without changing these read contracts.
