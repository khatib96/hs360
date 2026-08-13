# Phase 7.5 M6 Acceptance Report

> Status: **CLOSED / ACCEPTED**
>
> Date: 2026-08-09
>
> Next milestone: **M7 — Finance, Inventory, and Cross-Module Integrity Gate**

## Outcome

Sensitive record corrections now use a consistent bilingual confirmation,
consequence, and reason pattern, while every mutation remains governed by its
existing trusted backend. A basic Audit Log is available as a permission-gated
system destination without exposing raw audit payloads or granting implicit
access to source modules.

## Delivered Product

| Area | Accepted result |
|------|-----------------|
| Lifecycle dialog | Shared responsive confirmation with consequence panel, optional/required trimmed reason, validation, and safe cancel/confirm behavior |
| Financial actions | Invoice, voucher, and inventory-document cancellation use the shared pattern; backend eligibility and rejection rules remain authoritative |
| Draft safety | Purchase invoice draft discard requires explicit confirmation |
| Master data | Customer, supplier, warehouse, chart-account, product-group, and customer-location deactivation use explicit confirmation |
| Existing structured flows | Contract lifecycle dialogs remain specialized because they collect trusted dates and structured consequences |
| Audit destination | Permission-gated lower system navigation and guarded `/audit` route, including Audit-only landing behavior |
| Audit filters | Tenant-local date range, module, action, bounded search, refresh, and stable load-more cursor |
| Safe source access | Source summaries and local routes appear only after the source permission succeeds |
| Responsive/localized UI | Arabic RTL and English LTR loading, empty, error, redacted, filter, and detail states |

## Database Boundary

Migration `107_phase_7_5_m6_audit_review.sql` adds the authenticated-only
`list_phase_7_5_audit_log` RPC, bounded tenant/time indexes, and API-revoked
internal projection helpers. The RPC requires `audit_log.view`, derives the
tenant from the current session, applies tenant business-timezone date bounds,
and rechecks the source permission for every row.

Raw before/after JSON, reason, IP address, and user agent are not directly
selectable by API roles. Source-visible summaries are reconstructed from a
strict safe whitelist; audit-only viewers receive redacted rows with no snapshot, reason,
changed-field list, or source route, and cannot search protected reasons. Audit
rows remain immutable.

No posting formula, journal balance rule, WAC calculation, stock mutation,
contract lifecycle rule, period-lock rule, or audit trigger payload was changed.

## Acceptance Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | PASS — no issues |
| Complete Flutter suite | PASS — 1469 tests |
| Focused lifecycle/audit/navigation suite | PASS — 96 tests |
| Focused M6 SQL ACL/redaction/isolation/paging suite | PASS |
| Full SQL/concurrency/performance runner | PASS |
| Final baseline/calendar pollution gates | PASS |
| Protected audit-column ACL | PASS |
| Audit-only redaction and per-source permission shaping | PASS |
| Tenant isolation and tenant-local date filtering | PASS |
| Stable cursor paging and safe local source routes | PASS |
| Lifecycle narrow-layout and reason validation | PASS |

## Evidence

- Migration: `supabase/migrations/107_phase_7_5_m6_audit_review.sql`
- SQL acceptance: `supabase/tests/phase_7_5_m6_audit_review.sql`
- Audit repository: `test/features/audit/data/audit_log_repository_test.dart`
- Audit surface: `test/features/audit/presentation/audit_log_screen_test.dart`
- Lifecycle dialog: `test/shared/widgets/app_lifecycle_action_dialog_test.dart`
- Navigation/guard regression: `test/core/routing/app_navigation_test.dart`,
  `test/core/routing/route_guards_test.dart`, and
  `test/shared/widgets/app_shell_m2_accessibility_test.dart`
- Checksum: `docs/phase_7_5/m6/M6_MIGRATION_CHECKSUMS.txt`

M6 is closed. M7 may now run the finance, inventory, and cross-module
reconciliation gate against the accepted M4–M6 read projections and lifecycle
presentation without reopening their contracts.
