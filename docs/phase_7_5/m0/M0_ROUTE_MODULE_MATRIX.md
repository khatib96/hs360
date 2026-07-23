# Phase 7.5 M0 — Canonical Route, Module, and Back-Target Matrix

> Status: **ACCEPTED / M0 CONTRACT** (2026-07-24).
>
> This matrix fixes product placement and deterministic back behavior before
> the shell is rebuilt. Existing paths remain valid. M2 may add typed module
> metadata or module landing behavior, but it must not silently break an
> existing URL or deep link.

## Contract Rules

1. The sidebar points to modules, not implementation pages or create actions.
2. A module opens its first authorized implemented contextual surface.
3. Detail, edit, convert, return, preview, and document-form routes retain a
   deterministic parent even when browser history is empty.
4. Permission denial continues to fail closed through the route guard.
5. Query parameters that carry a supported filter or date remain intact.
6. New Phase 7.5 route paths are chosen in M2/M5 and added as typed route
   constants; this document does not invent paths before implementation.

## Current Route Placement

| Current route or family | Canonical product placement | Contextual surface | Accepted parent/back target | Phase 7.5 treatment |
|---|---|---|---|---|
| `/dashboard` | Dashboard | Dashboard | User's authorized home | Keep path; replace placeholder content in M5 |
| `/field/today` | Appointments & Visits | Today Agenda | Appointments & Visits landing, falling back to authorized home | Keep path and assigned-field behavior |
| `/calendar` | Appointments & Visits | Calendar | Appointments & Visits landing | Keep query filters for customer, contract, and date |
| `/calendar/route` | Appointments & Visits | Route View | `/calendar` with relevant date context | Keep as display/directions view; it is not the future Operations Map |
| `/contracts` | Contracts | Overview/List | Contracts landing | Primary implemented Contracts surface |
| `/contracts/new` | Contracts | Create command | `/contracts` | Quick-create/in-module command; never a sidebar row |
| `/contracts/:id` | Contracts | Contract detail | `/contracts` | Canonical contract destination |
| `/contracts/:id/convert` | Contracts | Convert trial | `/contracts/:id` | Return to the source contract when history is absent |
| `/customers` | Customers & Suppliers | Customers | Module landing/Customers tab | Keep current hub |
| `/customers/:id` | Customers & Suppliers | Customer detail | `/customers` | Detail owns its related customer surfaces |
| `/customers/:id/edit` | Customers & Suppliers | Edit customer | `/customers/:id` | Return to the edited record when history is absent |
| `/suppliers` | Customers & Suppliers | Suppliers | Module landing/Suppliers tab | Keep current hub tab |
| `/suppliers/:id` | Customers & Suppliers | Supplier detail | `/suppliers` | Preserve supplier accounting semantics |
| `/invoices` | Finance | Invoices | Finance landing/Invoices tab | Keep route and invoice-type filtering |
| `/invoices/new/sales` | Finance | Create sales invoice | `/invoices` | Quick-create/in-module command |
| `/invoices/new/purchase` | Finance | Create/edit purchase draft | `/invoices` | Preserve `draftId` behavior |
| `/invoices/new/sales-return` | Finance | Create sales return | `/invoices` | Separate return document, not cancellation |
| `/invoices/new/purchase-return` | Finance | Create purchase return | `/invoices` | Separate return document, not cancellation |
| `/invoices/:id` | Finance | Invoice detail | `/invoices` | Preserve type-aware visibility |
| `/invoices/:id/return` | Finance | Return against invoice | `/invoices/:id` | Return to the source invoice when history is absent |
| `/vouchers` | Finance | Vouchers | Finance landing/Vouchers tab | Keep route |
| `/vouchers/new/receipt` | Finance | Create receipt voucher | `/vouchers` | Quick-create/in-module command |
| `/vouchers/new/payment` | Finance | Create payment voucher | `/vouchers` | Quick-create/in-module command |
| `/vouchers/:id` | Finance | Voucher detail | `/vouchers` | Canonical voucher destination |
| `/cash-bank` | Finance | Cash & Bank | Finance landing/Cash & Bank tab | Keep route |
| `/accounts` | Finance | Chart of Accounts | Finance landing/Chart of Accounts tab | Keep route |
| `/journal` | Finance | Journal Entries | Finance landing/Journal Entries tab | Label is `Journal Entries / القيود اليومية` |
| `/journal/:id` | Finance | Journal entry detail | `/journal` | Posted entry remains immutable |
| `/products` | Inventory | Products | Inventory landing/Products tab | Keep route |
| `/products/new` | Inventory | Create product | `/products` | Quick-create/in-module command; remove from sidebar |
| `/products/:id` | Inventory | Product detail | `/products` | Canonical product destination |
| `/products/:id/edit` | Inventory | Edit product | `/products/:id` when resolvable, otherwise `/products` | Preserve current URL |
| `/product-units/:id` | Inventory | Serialized unit detail | Source product when available, otherwise `/products` | Keep path; do not expose protected cost fields |
| `/warehouses` | Inventory | Warehouses | Inventory landing/Warehouses tab | Keep route |
| `/inventory` | Inventory | Overview/Balances | Inventory landing | Preserve optional warehouse context |
| `/inventory/movements` | Inventory | Movements | Inventory landing/Movements tab | Immutable stock history |
| `/inventory/transfers` | Inventory | Transfer command | Inventory landing | Command surface; never a primary sidebar row |
| `/inventory/documents` | Inventory | Inventory Documents | Inventory landing/Documents tab | Keep list route |
| `/inventory/documents/opening-stock` | Inventory | Opening Stock command | `/inventory/documents` | Permission-filtered command |
| `/inventory/documents/stock-in` | Inventory | Stock In command | `/inventory/documents` | Permission-filtered command |
| `/inventory/documents/stock-out` | Inventory | Stock Out command | `/inventory/documents` | Permission-filtered command |
| `/inventory/documents/stock-count` | Inventory | Stock Count command | `/inventory/documents` | Permission-filtered command |
| `/inventory/documents/:id` | Inventory | Inventory document detail | `/inventory/documents` | Confirmed document lifecycle rules apply |
| `/settings/templates` | Settings | Documents/Templates | First authorized Settings surface | Lower system area, not primary business navigation |
| `/settings/tax` | Settings | Finance/Tax | First authorized Settings surface | Keep path |
| `/settings/calendar` | Settings | Calendar | First authorized Settings surface | Keep path |
| `/documents/preview` | Owning source module | Document preview | Validated source route; otherwise its authorized source list/home | Preserve kind/entity query and fail closed on invalid kind |

## System Routes

| Route | Placement | Contract |
|---|---|---|
| `/login` | Outside authenticated shell | Public authentication route |
| `/forgot-password` | Outside authenticated shell | Public recovery route |
| `/blocked` | Outside business modules | Safe destination for an authenticated user with no accessible home |
| `/` | Resolver only | Redirect to the permission-derived authorized home |

## New Phase 7.5 Surfaces

The following surfaces are accepted, but their exact path constants are
deliberately deferred to their implementation milestone:

| Surface | Placement | Owning milestone | Back contract |
|---|---|---|---|
| Daily Activity | Primary module | M5 | Authorized home |
| Audit Log | Lower system area | M6 | Previous authorized route, otherwise home |
| Global search palette | Global top bar overlay | M4 | Closes back to invoking route |
| Quick-create menu | Global top bar overlay | M4 | Created record or invoking route according to the accepted workflow |
| Notification center | Global top bar panel/full narrow surface | M4 | Safe source deep-link or invoking route |

## M2/M0.5 Verification Obligations

- M0.5 records the exact pre-change route inventory and automated baseline.
- M2 proves every route above remains reachable for its existing authorized
  user profiles.
- Direct entry, refresh, empty browser history, and locale direction are tested.
- Any improved parent listed here that differs from the current generic shell
  fallback receives a focused route/back test.
- No module label, tab, unavailable count, or error may reveal a route the user
  cannot access.
