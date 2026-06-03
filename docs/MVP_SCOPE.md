# MVP_SCOPE.md — Strict v1 Scope

> Updated 2026-05-16 to resolve conflicts before Phase 0.
> This file defines the first shippable version. Do not add Phase 2 work unless the scope is explicitly changed.

---

## In v1

### Auth + Permissions

- Supabase email/password auth.
- Tenant resolution from authenticated user.
- Manager/User account model.
- Permission catalog and explicit `user_permissions`.
- `PermissionGate` in Flutter.
- RLS policies based on `user_has_permission()`.

### Products

- Product groups.
- Products with dual units: primary, secondary, conversion factor.
- Serialized product units for rental assets.
- Product-level barcode and unit-level serial number.
- Internal generated SKU hidden from normal product UI.
- Basic QR/asset tag printing for serialized rental units.
- Basic inventory balances by warehouse.

### Customers

- Customer CRUD.
- Customer account link in chart of accounts.
- Customer service locations for branches/sites/addresses under one customer account.
- Basic customer detail with profile, locations, balance, contracts, invoices, and vouchers.

### Contracts

- Rental contracts only.
- One monthly rental value.
- Cost snapshot at creation.
- Customer + service location selection.
- Minimum-profit validation.
- Asset assignment and consumable line setup.
- Contract list and contract detail.

### Invoices

- Automatic monthly rental invoice.
- Manual sales invoice.
- Manual purchase invoice.
- Confirm/cancel lifecycle.
- Journal entries created by RPCs.
- Basic JSON-template PDF/print output.

### Vouchers

- Receipt voucher.
- Payment voucher.
- FIFO allocation for receipts.
- Journal entries created by RPCs.
- Basic JSON-template PDF/print output.

### Mobile Refill Flow

- Today's assigned refill visits.
- Visit address/map/GPS from the tied service location.
- GPS check-in.
- GPS mismatch proceeds only with reason and is flagged for review.
- Camera-only photo.
- Refill quantity and oil product.
- Optional receipt voucher if payment is collected.
- No offline sync in v1.

### Calendar

- Calendar view only.
- Generated refill events.
- Calendar events carry service location when generated from contracts.
- Basic reassignment can be manual in the database or Manager screen if time allows.

### Reports

- Customer balance.
- Contract list.
- Basic overdue invoices list.

---

## Out of v1 (Phase 2+)

- POS.
- Full HR: salaries, advances, commissions.
- WhatsApp campaigns and two-way conversation inbox.
- Maintenance module.
- Quotations.
- Trial contracts.
- Offline mobile sync.
- Visual document template editor.
- Internal operations map with clustering.
- Full P&L reports.
- Contract profitability dashboard beyond stored snapshots.
- Certificate pinning.
- Multi-currency invoices and exchange rates.
- Tenant onboarding automation.

---

## v1 Acceptance

v1 is acceptable when:

- A Manager can configure products, customers, users, and permissions.
- A User sees only granted modules and actions.
- A customer can have multiple service locations without being counted as multiple customers.
- A rental contract can be created with correct snapshots and minimum-profit validation.
- Monthly rental invoices and receipt vouchers post balanced journal entries.
- A field user can complete a refill with GPS and camera proof.
- Customer balance is answerable without Google Sheets.
