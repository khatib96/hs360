# Phase 7.5 M0 — Permission and Visibility Matrix

> Status: **ACCEPTED / M0 CONTRACT** (2026-07-24).
>
> Managers retain the existing permission bypass. For other users, navigation
> visibility is derived from implemented child permissions; a visible module
> never grants access by itself, and the server remains authoritative.

## Visibility Principles

1. Do not introduce one broad UI-only permission that bypasses existing
   feature permissions.
2. A module appears when at least one implemented child surface is authorized.
3. Unauthorized tabs, commands, labels, counts, search groups, and notification
   source text are omitted, not merely disabled.
4. A composite read model filters every projection by its source permission.
5. Field-sensitive values keep their field permissions after navigation is
   consolidated.
6. POS and HR remain hidden until their accepted implementation phases even if
   seed permissions already exist.
7. UI checks improve usability; route guards, RLS, and RPC checks remain the
   security boundary.

## Module and System Visibility

| Surface | Visible to a non-manager when | Additional contract |
|---|---|---|
| Dashboard | `dashboard.view`, or any currently supported office permission needed to preserve the authorized home behavior | Each widget independently requires its source read permission |
| Daily Activity | At least one accepted source projection is viewable | Each row is filtered again by its own source permission |
| Appointments & Visits | `calendar.view` or `calendar.view_assigned`; Today Agenda also supports the existing assigned-field permission set | Tenant-wide and assigned-only scopes must not be mixed |
| Contracts | `contracts.view` | Create/convert/lifecycle commands require their exact action permission |
| Customers & Suppliers | `customers.view` or `suppliers.view` | Tabs remain independently filtered |
| Finance | At least one implemented Finance read permission: invoice view family, `vouchers.view`, `cash_bank.view`, `chart_of_accounts.view`, or `journal.view` | No financial count/value appears without the corresponding source permission |
| Inventory | At least one implemented Inventory read permission: `inventory.view`, `products.view`, `product_units.view`, `warehouses.view`, `inventory_movements.view`, or `inventory_documents.view` | Protected costs retain field-level gates |
| Audit Log | `audit_log.view` | Safe summaries are still redacted by source/field access |
| Settings | At least one implemented settings view/edit permission | Only authorized settings tabs appear |
| Point of Sale | Never in Phase 7.5 | Hidden until Phase 9 implementation and accepted permissions exist |
| Human Resources | Never in Phase 7.5 | Hidden until Phase 9 implementation and accepted permissions exist |
| User identity/profile/footer | Every authenticated user | Shows identity and sign-out; never implies a business permission |

## Contextual Tab Visibility

| Module | Tab/surface | Required permission |
|---|---|---|
| Appointments & Visits | Calendar / Route View | `calendar.view` or `calendar.view_assigned`, preserving scope |
| Appointments & Visits | Today Agenda | Existing field access: manager or any of `visits.view_assigned`, `visits.edit_assigned`, `visits.complete_refill`, `calendar.view_assigned` |
| Appointments & Visits | Visits / Follow-up | Hidden until Phase 8 provides the surface and accepted source contract |
| Contracts | List/detail | `contracts.view` |
| Customers & Suppliers | Customers | `customers.view` |
| Customers & Suppliers | Suppliers | `suppliers.view` |
| Finance | Invoices | `invoices.view`, `invoices.view_sales`, `invoices.view_purchase`, or `invoices.view_returns` as applicable |
| Finance | Vouchers | `vouchers.view` |
| Finance | Cash & Bank | `cash_bank.view` |
| Finance | Chart of Accounts | `chart_of_accounts.view` |
| Finance | Journal Entries | `journal.view` |
| Finance | General Ledger / Reports / Period Close | Hidden until Phase 10 implementation |
| Inventory | Overview/Balances | `inventory.view` |
| Inventory | Products | `products.view` |
| Inventory | Serialized Units | `product_units.view` |
| Inventory | Warehouses | `warehouses.view` |
| Inventory | Movements | `inventory_movements.view` |
| Inventory | Transfers | `inventory_movements.create` |
| Inventory | Inventory Documents | `inventory_documents.view` |
| Settings | Documents/Templates | `settings.templates.view` or `settings.templates.edit` |
| Settings | Finance/Tax | `settings.tax.view` or `settings.tax.edit` |
| Settings | Calendar | `settings.calendar.view` or `settings.calendar.edit` |
| Settings | Company / Users & Permissions / Field Operations / Localization | Hidden until an implemented route and explicit accepted permission contract exist |

## Global Search

| Result group | Required source permission | Destination |
|---|---|---|
| Customers | `customers.view` | Canonical customer detail |
| Suppliers | `suppliers.view` | Canonical supplier detail |
| Contracts | `contracts.view` | Canonical contract detail |
| Sales invoices | `invoices.view` or `invoices.view_sales` | Type-aware invoice detail |
| Purchase invoices | `invoices.view` or `invoices.view_purchase` | Type-aware invoice detail |
| Returns | `invoices.view` or `invoices.view_returns` | Type-aware invoice detail |
| Products | `products.view` | Product detail |
| Serialized units | `product_units.view` | Unit detail |
| Supported document identifiers | The same view/preview permission required by the document kind | Canonical source detail or safe preview |

Search results are tenant-scoped, capped, grouped, and server-filtered. Hidden
groups do not expose a zero count, timing distinction, protected field, or
record label.

## Quick Create and Lifecycle Commands

| Command | Required permission |
|---|---|
| Customer | `customers.create` |
| Supplier | `suppliers.create` |
| Product | `products.create` |
| Warehouse | `warehouses.create` |
| Sales invoice | `invoices.create_sales` |
| Purchase invoice | `invoices.create_purchase` |
| Sales return | `invoices.create_sales_return` |
| Purchase return | `invoices.create_purchase_return` |
| Receipt voucher | `vouchers.create_receipt` |
| Payment voucher | `vouchers.create_payment` |
| Contract | `contracts.create` |
| Calendar event | `calendar.create` |
| Inventory transfer | `inventory_movements.create` |
| Opening stock | `inventory_documents.create_opening` |
| Stock in/out adjustment | `inventory_documents.create_adjustment` |
| Stock count | `inventory_documents.create_stock_count` |

Edit, cancel, reverse, convert, close, deactivate, print, and field-sensitive
actions continue to use their exact existing action/field permission and record
state. Presence in quick create does not relax backend validation.

## Dashboard v1

| Priority slot | Minimum visibility contract |
|---|---|
| Today's appointments/visits | `calendar.view` for tenant scope or assigned calendar/visit permission for assigned scope |
| Overdue operational items | At least one authorized contributing source; each count and drill-down uses the same filter and scope |
| Active/trial/rental contracts and asset condition | `contracts.view`; protected cost/profit values also require their existing field permissions |
| Current-month collections and outstanding amount | Corresponding invoice/voucher/customer-ledger read permissions for every represented value |

If a trusted permission-safe read contract is unavailable, the slot is omitted
or shows a truthful unavailable state. It must never estimate from a broader
dataset than the user can drill into.

## Notifications, Drill-Down, and Audit

| Surface/action | Permission contract |
|---|---|
| Notification bell/list | `notifications.view`, recipient-scoped |
| Notification source label/deep-link | Bell permission plus current source-record permission |
| Mark read/unread | Recipient-scoped accepted notification contract; idempotent |
| Dashboard/Daily Activity drill-down | Same source permission, scope, date, and filter as the displayed value |
| Audit list | `audit_log.view` |
| Audit source link and before/after summary | Audit permission plus source and field visibility; otherwise redact or omit |

## Required Acceptance Profiles

M0.5, M2, M4, M5, M6, and M8 must cover:

- Manager;
- authenticated zero-permission user;
- assigned-only field user;
- single-module office user;
- mixed-permission user;
- settings-only user;
- audit-only user with no protected source-field access.

For every profile, sidebar modules, contextual tabs, quick create, search,
notifications, Dashboard, Daily Activity, Audit, direct routes, and back
targets must agree.
