# Phase 7.5 M3 Acceptance Report

> Status: **CLOSED / ACCEPTED**
>
> Date: 2026-07-27
>
> Next milestone: **M4 — Global Search, Quick Create, and Notification Center**

## Outcome

M3 places the accepted Phase 3–7 functionality inside the product modules
introduced by M2. Existing feature-owned commands now have a consistent
in-module location, duplicate Customers/Suppliers navigation was removed, and
remaining high-use list surfaces adopted the shared filter, state, and table
patterns.

Existing URLs, guards, permissions, repositories, RPCs, posting rules, and
record lifecycles remain unchanged.

## Module Adoption

| Module | M3 result |
|--------|-----------|
| Appointments & Visits | Calendar route/create actions use the module command area on desktop; mobile retains its safe non-overlapping create entry |
| Contracts | New-contract entry moved from the global top bar to the Contracts command area; record lifecycle actions remain state- and permission-shaped |
| Customers & Suppliers | Removed the second internal tab bar; canonical `/customers` and `/suppliers` routes now select one body under the shell contextual navigation |
| Finance | Invoice and inventory-document create menus moved into module commands; voucher create was removed from the list body and placed in the same command area |
| Inventory | Adjustment and transfer commands moved out of list content; Products and Warehouses create actions use the shared module command area |
| Settings | Existing Templates, Tax, and Calendar routes remain under the permission-filtered Settings context; unavailable future settings remain hidden |

`Journal Entries / القيود اليومية` remains the accounting label inside
Finance. It is not merged with the future Daily Activity surface.

## Shared Presentation Adoption

- Voucher lists now use `AppFilterBar`, `AppStateView`, and `AppTableFrame`.
- Supplier lists use the same shared filter, state, and table boundaries as
  Customers.
- Warehouse lists use shared loading/error/empty and table patterns.
- Product empty state no longer duplicates the create action already exposed
  by the module command area.
- Inventory document cancellation is permission- and state-filtered in the
  module command area and retains its required reason dialog.
- `AppModuleCommandBar` standardizes command placement, semantics, and
  horizontal overflow without taking feature behavior away from its owner.

## Accepted Journeys

| Journey | UI entry |
|---------|----------|
| Create product | Inventory → Products → New Product command |
| Create/edit warehouse | Inventory → Warehouses → Add command / row action |
| Adjust or transfer stock | Inventory → Balances → Adjustment / Transfer commands |
| Opening, stock in/out, and count documents | Inventory → Inventory Documents → permission-shaped commands |
| Create invoices and returns | Finance → Invoices → permission-shaped create menu |
| Create receipt/payment voucher | Finance → Vouchers → permission-shaped create menu |
| Create/convert/manage contract | Contracts → New Contract command / record lifecycle actions |
| Create calendar event and open Route View | Appointments & Visits → Calendar commands |
| Create/edit customer or supplier | Customers or Suppliers destination → filter/list command and row action |
| Open Phase 3–7 lists | Sidebar module → contextual destination |

No accepted journey requires entering a URL manually.

## Acceptance Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | PASS — no issues |
| Complete Flutter suite | PASS — 1450 tests |
| Expanded affected-module regression | PASS — 156 tests |
| M3 deterministic screenshot suite | PASS — 4 tests |
| Arabic RTL and English LTR | PASS |
| Desktop and 390 px narrow command overflow | PASS |
| Permission-shaped commands and hidden future tabs | PASS |
| Existing URLs, deep links, guards, and back targets | PRESERVED |
| Database/RPC/migration/posting changes | NONE |

## Evidence

- Screenshot hashes and dimensions:
  `docs/phase_7_5/m3/M3_SCREENSHOT_MANIFEST.md`
- Durable evidence images:
  `docs/phase_7_5/m3/screenshots/`
- Shell command placement tests:
  `test/shared/widgets/app_shell_m3_module_adoption_test.dart`
- Permission regression:
  `test/shared/widgets/app_shell_permission_test.dart`
- Customers/Suppliers consolidation:
  `test/features/customers/presentation/customers_hub_screen_test.dart`
- Deterministic visual harness:
  `test/screenshots/phase_7_5_m3_module_adoption_screenshots.dart`

M3 is closed. M4 may add functional global search, quick create, and
notifications without moving feature-specific record commands back into the
global top bar.
