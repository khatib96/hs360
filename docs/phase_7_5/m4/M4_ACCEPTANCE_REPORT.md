# Phase 7.5 M4 Acceptance Report

> Status: **CLOSED / ACCEPTED**
>
> Date: 2026-07-27
>
> Next milestone: **M5 — Dashboard v1 and Daily Activity**

## Outcome

The three global action anchors introduced in M2 are now functional. Global
search, quick create, and the notification center are available from every
module only when the current session has a relevant permission. Desktop and
compact shell variants provide the same actions.

## Delivered Contracts

| Area | Accepted result |
|------|-----------------|
| Global search | Two-character minimum, 80-character input cap, 1–10 rows per visible category, server-side permission shaping, safe labels/identifiers only |
| Search interaction | Grouped results, pointer selection, Up/Down keyboard movement, Enter open, Escape close, canonical existing detail routes |
| Quick create | Existing customer, supplier, product, warehouse, invoice/return, voucher, contract, calendar, transfer, and inventory-document flows only |
| Notifications | Current recipient's in-app rows only, unread badge/count, refresh, empty/error states, read/unread transition |
| Source links | Calendar links only after current event visibility recheck; stale, unknown, or unauthorized sources are omitted |
| Responsive/localized UI | Desktop and narrow top-bar behavior in Arabic RTL and English LTR |

## Database Boundary

Migration `105_phase_7_5_m4_global_tools.sql` adds:

- `notifications.read_at`;
- `global_navigation_search(text, integer)`;
- `list_my_in_app_notifications(integer, timestamptz)`;
- `set_my_in_app_notification_read(uuid, boolean)`;
- an own-recipient in-app notification index.

The functions derive tenant/user identity from the authenticated session.
`PUBLIC`/`anon` execution is revoked and only `authenticated` receives execute
permission. No posting, inventory valuation, contract lifecycle, calendar
scheduling, or financial document behavior changed.

## Acceptance Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | PASS — no issues |
| Complete Flutter suite | PASS — 1455 tests |
| Focused M4 interaction suite | PASS — 5 tests |
| Existing shell permission regression | PASS — included in full suite |
| M4 SQL isolation/ACL suite | PASS |
| Full SQL/concurrency/performance runner | PASS |
| Final baseline and calendar pollution gates | PASS |
| Zero-permission search category leakage | PASS |
| Recipient and tenant notification isolation | PASS |
| Idempotent read transition | PASS |
| Pointer canonical deep-link | PASS |
| Keyboard movement | PASS |
| Arabic narrow RTL / English desktop LTR | PASS |

## Evidence

- Flutter interaction tests:
  `test/features/global_tools/presentation/global_tools_test.dart`
- SQL contract tests:
  `supabase/tests/phase_7_5_m4_global_tools.sql`
- Migration checksum:
  `docs/phase_7_5/m4/M4_MIGRATION_CHECKSUMS.txt`
- Full SQL runner includes the M4 suite before the final pollution gates.

M4 is closed. M5 may build Dashboard v1 and Daily Activity on top of the same
permission-shaped navigation and source-link rules.
