# Phase 7.5 M0.5 — Route Baseline and Zero-Loss Checklist

> Status: **BASELINE RECORDED**
>
> Snapshot date: **2026-07-24**
>
> Source files: `app_routes.dart`, `app_router.dart`, `route_guards.dart`, and
> `app_shell.dart`.

## Baseline Rules

- The router currently registers the root resolver plus all **50** path
  constants in `AppRoutes`.
- Public routes are `/login` and `/forgot-password`; every other route requires
  an authenticated session.
- A manager passes all inner route checks. Permission notes below describe the
  non-manager rule.
- “Menu” describes the pre-M2 flat shell exactly as it exists now. A route not
  shown in the menu remains reachable by its direct URL or an in-screen action.
- On denied access, the guard redirects to the user's permission-derived home.
- Query strings used by calendar, invoice detail/drafts, document preview, and
  route-day links are part of the preserved deep-link contract.

## Exact Pre-Change Route Inventory

| # | Route | Current menu | Non-manager guard | Current empty-history back |
|---:|---|---|---|---|
| 0 | `/` | No; resolver | Authenticated | Permission-derived home |
| 1 | `/login` | Outside shell | Public | Not applicable |
| 2 | `/forgot-password` | Outside shell | Public | Not applicable |
| 3 | `/dashboard` | Yes | Any office permission | Permission-derived home |
| 4 | `/field/today` | Yes | Any field permission | Permission-derived home |
| 5 | `/calendar` | Yes | `calendar.view` or `calendar.view_assigned` | Permission-derived home |
| 6 | `/calendar/route` | No; calendar action | Same as Calendar | `/calendar` when entered from the shell; otherwise home |
| 7 | `/blocked` | Outside business modules | Authenticated | Not applicable |
| 8 | `/products` | Yes | `products.view` | Permission-derived home |
| 9 | `/products/new` | Yes, incorrectly flat | `products.create` | `/products` |
| 10 | `/products/:id/edit` | No | `products.view` + `products.edit` | `/products` |
| 11 | `/products/:id` | No | `products.view` | `/products` |
| 12 | `/product-units/:id` | No | `product_units.view` | `/products` |
| 13 | `/warehouses` | Yes | `warehouses.view` | Permission-derived home |
| 14 | `/inventory` | Yes | `inventory.view` | Permission-derived home |
| 15 | `/inventory/movements` | Yes | `inventory_movements.view` | `/inventory` when shell matching resolves it; otherwise home |
| 16 | `/inventory/transfers` | Yes, incorrectly flat | `inventory_movements.create` | `/inventory` |
| 17 | `/customers` | Yes | `customers.view` or `suppliers.view` | Permission-derived home |
| 18 | `/customers/:id/edit` | No | `customers.view` + `customers.edit` | `/customers` |
| 19 | `/customers/:id` | No | `customers.view` | `/customers` |
| 20 | `/suppliers` | No direct menu row | `suppliers.view` | Permission-derived home |
| 21 | `/suppliers/:id` | No | `suppliers.view` | `/suppliers` |
| 22 | `/accounts` | Yes | `chart_of_accounts.view` | Permission-derived home |
| 23 | `/settings/templates` | Yes | `settings.templates.view` or `.edit` | Permission-derived home |
| 24 | `/settings/tax` | No direct menu row | `settings.tax.view` or `.edit` | Permission-derived home |
| 25 | `/settings/calendar` | Yes | `settings.calendar.view` or `.edit` | Permission-derived home |
| 26 | `/documents/preview` | No; source action | Valid `kind` plus kind-specific view/print permission | Permission-derived home |
| 27 | `/invoices` | Yes | Any accepted invoice-view permission | Permission-derived home |
| 28 | `/invoices/new/sales` | No | `invoices.create_sales` | `/invoices` |
| 29 | `/invoices/new/purchase` | No | `invoices.create_purchase`; `invoices.edit_draft` when `draftId` is present | `/invoices` |
| 30 | `/invoices/new/sales-return` | No | `invoices.create_sales_return` | `/invoices` |
| 31 | `/invoices/new/purchase-return` | No | `invoices.create_purchase_return` | `/invoices` |
| 32 | `/invoices/:id` | No | Type-aware invoice view; generic view when type is absent/invalid | `/invoices` |
| 33 | `/invoices/:id/return` | No | Either accepted return-create permission | `/invoices` |
| 34 | `/vouchers` | Yes | `vouchers.view` | Permission-derived home |
| 35 | `/vouchers/new/receipt` | No | `vouchers.create_receipt` | `/vouchers` |
| 36 | `/vouchers/new/payment` | No | `vouchers.create_payment` | `/vouchers` |
| 37 | `/vouchers/:id` | No | `vouchers.view` | `/vouchers` |
| 38 | `/contracts` | Yes | `contracts.view` | Permission-derived home |
| 39 | `/contracts/new` | No | `contracts.create` | `/contracts` |
| 40 | `/contracts/:id` | No | `contracts.view` | `/contracts` |
| 41 | `/contracts/:id/convert` | No | `contracts.convert_trial` | `/contracts` |
| 42 | `/journal` | Yes | `journal.view` | Permission-derived home |
| 43 | `/journal/:id` | No | `journal.view` | `/journal` |
| 44 | `/cash-bank` | Yes | `cash_bank.view` | Permission-derived home |
| 45 | `/inventory/documents` | No direct menu row | `inventory_documents.view` | Permission-derived home |
| 46 | `/inventory/documents/opening-stock` | No | `inventory_documents.create_opening` | `/inventory` |
| 47 | `/inventory/documents/stock-in` | No | `inventory_documents.create_adjustment` | `/inventory` |
| 48 | `/inventory/documents/stock-out` | No | `inventory_documents.create_adjustment` | `/inventory` |
| 49 | `/inventory/documents/stock-count` | No | `inventory_documents.create_stock_count` | `/inventory` |
| 50 | `/inventory/documents/:id` | No | `inventory_documents.view` | `/inventory` |

## Deep-Link Contracts That Must Survive M2

| Contract | Preserved shape |
|---|---|
| Calendar scope | `/calendar?customerId=…&contractId=…&date=YYYY-MM-DD` |
| Route day | `/calendar/route?date=YYYY-MM-DD` |
| Invoice type | `/invoices/:id?type=…` |
| Purchase draft | `/invoices/new/purchase?draftId=…` |
| Document preview | `/documents/preview?kind=…&entityId=…` plus supported date/type fields |
| Entity detail helpers | Encoded customer, supplier, contract, invoice, voucher, journal, product-unit, and inventory-document IDs |

## Current Menu Snapshot

The flat shell exposes **19** rows: Dashboard, Today, Calendar, Products,
Add Product, Customers, Contracts, Invoices, Vouchers, Journal, Cash & Bank,
Chart of Accounts, Warehouses, Inventory, Movements, Transfers, Template
Settings, and Calendar Settings. Visibility is permission-filtered.

M2 must remove action/settings leakage from the primary module list without
removing the routes themselves.

## Zero-Loss Gate

- [x] Root resolver inventoried.
- [x] All 50 `AppRoutes` path constants inventoried.
- [x] Public/authenticated behavior recorded.
- [x] Every non-manager guard recorded.
- [x] Every current visible menu entry recorded.
- [x] Current deterministic/fallback back behavior recorded.
- [x] Supported query/deep-link shapes recorded.
- [x] M0 accepted future parent targets remain in `M0_ROUTE_MODULE_MATRIX.md`.
- [x] Analyzer and complete Flutter suite passed against this route set.
- [x] Focused route-guard and shell-permission tests passed.

This checklist is the pre-change comparison source for M2. M2 may improve
parent targets to the accepted M0 contract, but it may not delete, rename, or
weaken any route/guard silently.
