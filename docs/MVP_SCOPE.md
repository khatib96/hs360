# MVP_SCOPE.md — Strict v1 Scope

> Updated 2026-07-22 after the owner-approved Phase 7.5 roadmap correction.
> This file defines the first shippable version. Later accepted ideas belong in
> their assigned roadmap phase unless explicitly promoted here.

---

## In v1

### Auth + Permissions

- Supabase email/password auth.
- Tenant resolution from authenticated user.
- Manager/User account model.
- Permission catalog and explicit `user_permissions`.
- `PermissionGate` in Flutter.
- RLS policies based on `user_has_permission()`.

### Product Structure and Safe Navigation

- Module-based desktop navigation rather than a flat list of pages/actions.
- Primary modules: Dashboard, Daily Activity, Customers & Suppliers, Contracts,
  Appointments & Visits, Inventory, and Finance; later POS/HR modules remain
  hidden until implemented.
- Lower system area for permission-gated Audit, Settings, and user profile.
- Global top bar utilities plus contextual navigation inside the active module.
- Dashboard v1 with permission-shaped operational widgets and drill-down.
- Daily Activity / `ملخص اليوم` as a selected-date operational timeline,
  distinct from accounting Journal Entries / `القيود اليومية`.
- Consistent draft/edit/cancel/reverse/deactivate commands matching backend
  safety rules; posted financial records are never hard-deleted.
- Basic permission-gated Audit Log review.

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

- Trial contracts and rental contracts.
- One monthly rental value.
- Cost snapshot at creation.
- Customer + service location selection.
- Minimum-profit validation.
- Asset assignment and rental-consumable line setup.
- Basic trial lifecycle: convert to rental, return, or extend with reason.
- Contract list and contract detail.

### Invoices

- Automatic monthly rental invoice.
- Manual sales invoice.
- Manual purchase invoice.
- Sales return linked to the original sales invoice.
- Purchase return linked to the original purchase invoice.
- Confirm/cancel lifecycle.
- Journal entries created by RPCs.
- Basic JSON-template PDF/print output.

### Inventory Accounting

- Opening-stock document with an opening-equity journal.
- Financial stock-in and stock-out with controlled reason/account mapping.
- Stock-count adjustment document that posts quantity and value differences.
- Warehouse transfers remain non-financial because total owned inventory value
  does not change.

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

### Calendar and Company Appointments

> Implementation status (2026-07-22): Phase 7 M0-M12 is CLOSED / ACCEPTED
> through migration `104`. Assignment/reschedule, assigned mobile calendar,
> route view/native directions, and the accepted verification gates are closed.
> Physical Android smoke remains a pre-production obligation.

- Hybrid company calendar with an upper calendar and lower selected-day agenda:
  contract-generated/untimed events are date-based, while manual appointments
  may optionally have an explicit same-day time window.
- Owner-configured seven-day working schedule and IANA timezone; no inferred
  weekend, hours, or timezone.
- Generated refill events, overdue visibility, customer visits, internal
  meetings, tasks/reminders, activities/training, and custom manual events.
- Calendar events carry service location when generated from contracts.
- Manual meeting/activity participants remain separate from the assigned or
  responsible employee.
- Holidays, company closures, and exceptional working days are managed as
  date-specific working-calendar exceptions.
- Assignment and audited date rescheduling through permission-gated RPCs.
- In-app reminder foundations anchored to enabled working-day policies.
- Assigned mobile calendar plus display-only route view/native directions.
- Actual refill completion, delivered quantity, coverage, stock, GPS/photo, and
  next-due confirmation remain in the Mobile Refill Flow/Phase 8.

### Reports

- Customer balance.
- Contract list.
- Basic overdue invoices list.

---

## Out of v1 (Later Roadmap Phases)

- POS.
- Full employee personal/passport/residency/employment-document records.
- Full HR: leave/letter requests, salaries, advances, commissions, and payroll.
- Administrative/field/hybrid adaptive mobile beyond the minimum v1 field
  workflow and the complete generic request/approval catalog.
- WhatsApp campaigns and two-way conversation inbox.
- Maintenance module.
- Quotations.
- Offline mobile sync.
- Visual document template editor.
- Internal operations map with clustering.
- Full P&L reports.
- Full General Ledger UI, accounting day book, trial balance, balance sheet,
  inventory-to-GL reconciliation, and financial close.
- Advanced owner Dashboard and Audit Review Dashboard.
- Fiscal-period management and year-end closing workflow (Phase 10).
- Contract profitability dashboard beyond stored snapshots.
- Certificate pinning.
- Multi-currency invoices and exchange rates.
- Tenant onboarding automation.

---

## v1 Acceptance

v1 is acceptable when:

- A Manager can configure products, customers, users, and permissions.
- A User sees only granted modules and actions.
- Navigation groups screens into coherent modules and does not leak hidden
  counts through Dashboard, Daily Activity, search, or notifications.
- A customer can have multiple service locations without being counted as multiple customers.
- A rental contract can be created with correct snapshots and minimum-profit validation.
- Monthly rental invoices and receipt vouchers post balanced journal entries.
- Confirmed financial records cannot be hard-deleted; accepted cancellation
  paths reverse their effects safely and preserve audit history.
- A field user can complete a refill with GPS and camera proof.
- Customer balance is answerable without Google Sheets.
