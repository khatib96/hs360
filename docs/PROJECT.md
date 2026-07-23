# PROJECT.md — Vision & Scope

> Updated 2026-07-24 with the owner-approved Phase 7.5 product structure,
> adaptive mobile, employee/request, and record-correction direction.
> Operational job names/work profiles are descriptive presentation inputs only.
> Access control remains Manager/User + explicit permissions.

## 1. Vision

A custom ERP built around the **rental-of-asset + monthly-consumable** model — purpose-built for fragrance device rental companies, designed as multi-tenant SaaS, sellable across the GCC and beyond.

The system must:
- Replace manual Google Sheets workflows
- Eliminate the asset-vs-consumable accounting gap that off-the-shelf ERPs cannot solve
- Give the owner per-contract profitability in real time
- Enforce field-agent discipline via GPS + live-photo proof
- Run as multi-tenant SaaS so additional companies can be onboarded with zero code changes

---

## 2. Business Context

### 2.1 First Tenant: Hayat Secret
- **Location:** Kuwait
- **Active rental contracts:** ~115
- **Products:** fragrance diffusers, scented oils, perfumes
- **Default currency example:** KWD (3 decimal places — fils). Runtime currency comes from the tenant's `currencies` row.
- **Languages:** Arabic primary, English secondary

### 2.2 Current Pain Points
1. Everything tracked in Google Sheets — manual, error-prone, no audit trail
2. Cannot answer "is contract X profitable?" without manual calculation
3. Cannot detect underpriced contracts before they're signed
4. No control over field agents' refill schedules
5. Cannot prove that a refill visit actually happened
6. Customer debt aging is invisible until too late
7. Switching oil types mid-contract is undocumented
8. A flat list of screens hides the business workflow and makes related
   inventory, finance, customer, and operations tasks feel disconnected
9. Employee requests and management approvals have no controlled shared trail

### 2.3 Operational Roles
- **Owner / Admin** — sees everything, sets policies, owns financial visibility
- **Sales agents** — close new contracts, may also sell devices/oils
- **Refill technicians** — service existing contracts monthly
- **Hybrid agents** — do both
- **Accountant** — manages invoices, vouchers, statements
- **Warehouse keeper** — manages stock, van assignments, transfers

An employee may have an administrative, field, or hybrid work profile for
default desktop/mobile presentation. This is not an authorization role;
explicit permissions remain final.

---

## 3. Scope

### 3.1 In Scope

**Multi-Tenancy**
- Single shared database with `tenant_id` on every row
- RLS isolation between tenants
- Per-tenant settings (currency, locale, fiscal year, branding)
- User invitations limited to tenant scope

**Product Structure & Navigation**
- Module-based desktop shell, in order: Dashboard, Daily Activity,
  Appointments & Visits, Contracts, Customers & Suppliers, Finance, Inventory,
  POS, and HR
- Global top bar with bounded permission-safe search, quick create, functional
  in-app notifications, locale, and contextual navigation inside the active
  module
- Permission-gated Audit, Settings, and signed-in user profile in the lower
  system area
- Dashboard v1 uses four fixed priority slots whose KPIs drill into authorized
  source records
- Daily Activity is a selected-date operational timeline and is distinct from
  accounting journal/day-book views

**Product Management**
- Product groups (hierarchical)
- Three product types: `sale_only`, `asset_rental`, `consumable_rental`
- Serialized units for rentable assets (each device has unique S/N + barcode)
- Product pricing: sale price and purchase/WAC cost. No product-level rental price.
- Auto-computed weighted average cost (WAC) from purchase invoices
- Maintenance tracking flag

**Contracts (Core)**
- Two types: `trial` (free, time-boxed) and `rental` (paid, recurring)
- One monthly value entered manually (not per-line)
- System auto-computes profitability snapshot at creation
- Tenant-wide minimum-profit threshold enforced at save
- Contract is linked to one customer account and one customer service location/branch/site
- Tracks oil-type changes over contract lifetime
- Open-ended or fixed-term contracts
- Trial conversion workflow

**Calendar & Scheduling**
- Unified calendar view: refills due, contract endings, trial expiries, follow-ups
- Filterable by agent, customer, service location, date range, status
- Daily/weekly/monthly views
- Reminders (push + email + WhatsApp)
- Initial refill due date comes from the contract cadence. A missed refill stays
  pending/overdue; later refills are anchored to trusted actual completion and
  confirmed coverage rather than blindly repeating the old planned day.

**Field Operations (Mobile)**
- Permission-shaped administrative/field/hybrid mobile shell
- Daily visit schedule per agent
- Visit address/map/GPS comes from the customer service location tied to the contract/visit
- Live-camera-only photo proof (gallery uploads blocked)
- GPS check-in/check-out with distance verification
- Van stock (each agent = sub-warehouse)
- Daily reconciliation
- On-the-spot oil-type swap with reason capture
- Mobile receipt voucher issuance with auto-send to customer
- Authorized unplanned visits with reason, outcome, evidence rules, follow-up,
  and optional linked trial/rental contract
- Employee Requests surface and approval status; field-critical requests include
  visit reschedule/delegation and van-stock refill/transfer

**Accounting**
- Full chart of accounts (double-entry)
- Receipt vouchers, payment vouchers, journal entries
- Sales/purchase invoices, returns, opening balance
- Inventory adjustments
- Customer/supplier statements
- Debt aging reports (30/60/90/120+)
- General Ledger, accounting day book, trial balance, P&L, balance sheet,
  cash flow, budgets/budget-versus-actual, inventory-to-GL reconciliation,
  fiscal periods, and controlled year-end close
- Lifecycle-safe correction: drafts may be edited/discarded; posted documents
  use permissioned, reason-required cancellation/reversal and are never erased

**Customers & Service Locations**
- Customer is the main company/account and is counted once.
- Customer service locations model branches, offices, warehouses, homes, or installation sites.
- Contracts, visits, calendar events, and rented devices can point to a service location under the customer.

**Collections (Separate from Visits)**
- A refill creates a charge; payment is separate
- Customers can pay months in advance or in arrears
- Single voucher can settle multiple invoices (FIFO or manual allocation)
- Auto-generated receipt PDF sent via WhatsApp + email

**Inventory & Maintenance**
- Per-warehouse balances
- Serialized asset tracking (where is each device, in what state)
- Maintenance workflow: pickup → repair → return-to-stock or write-off
- Per-unit maintenance history
- Damaged / lost asset accounting

**Reporting**
- P&L with rental depreciation factored in later if the accounting scope is accepted
- Per-contract profitability (uses snapshot, not current prices)
- Debt aging
- Field agent performance (visits, collections, contracts)
- Inventory valuation
- Trial expiry watch
- Active contracts dashboard

**HR**
- Employee records with automatic tenant-scoped employee code
- Personal/contact, nationality, birth/join/end, passport, residency,
  sponsorship, employment-contract, temporary-assignment, and document data
- Optional tenant-user link; employees without program access remain valid
- Administrative/field/hybrid work profile for presentation only
- Requests and approvals: leave, advances, visit changes, delegation, official
  letters/certificates, and other accepted types with immutable decision history
- Salaries via vouchers
- Advances with auto-deduction
- Commission engine (per-role configurable)

**POS**
- Walk-in sales screen
- Barcode scan
- Cash / KNET / transfer
- Receipt print

**Communication**
- Automated emails (Resend)
- WhatsApp messages (Meta Cloud API)
- Templates per event: contract created, refill receipt, payment received, debt reminder
- In-app notifications

### 3.2 Out of Scope (v1)
- Tax authority integration
- Multi-currency per tenant (each tenant has one currency)
- Multi-branch operating structure for the tenant itself (customer service locations are in v1)
- Customer self-service portal
- Loyalty program
- E-commerce storefront

### 3.3 Future
- Per-tenant white-labeling
- Subscription billing for the SaaS itself
- Advanced analytics & forecasting
- Franchise/master-tenant hierarchy

---

## 4. Core Business Rules

### 4.1 Product Types

| Type | Stock Behavior | Pricing | Examples |
|------|----------------|---------|----------|
| `sale_only` | Decremented permanently on sale | Sale price only | Perfumes, gift sets |
| `asset_rental` | Tracked per-unit by S/N when available; returns on contract end | Contract basis comes from tenant settings; default is selected unit cost / lifespan basis | Diffuser devices |
| `consumable_rental` | Decremented on confirmed refill/replacement; never returns | Contract basis comes from tenant settings; default is sale price converted by unit/quantity | Oils |

### 4.2 Contract Pricing Rule

**The owner's rule, encoded:**

> The agent enters only the monthly rental value of the contract.
> The system computes the underlying cost from the selected products' current cost data.
> The system computes the expected monthly profit = rental − cost.
> If profit < tenant's minimum-profit threshold, the system rejects the save.
> Admin can override with a reason, logged in audit.

This gives the owner one knob to turn — the minimum profit per contract per month — and the system handles everything else.

### 4.3 Snapshot Principle

When a contract is saved, the system stores a **frozen snapshot** of:
- Device monthly basis for pricing/profit, not accounting depreciation
- Rental-consumable cost per refill/replacement (qty × configured basis at that moment)
- Total monthly cost

These snapshots are what profitability reports use. They do **not** change when prices change later. This is correct accounting behavior.

Accounting depreciation and deep asset-consumption adjustments are deferred
beyond Phase 6. Device usage should be based on real activity when implemented,
not merely on elapsed idle time.

### 4.4 Oil-Type Tracking

The oil a contract uses is **a time-bounded record**, not a fixed column. A contract can switch oils any number of times. Each switch creates a new record with `effective_from` set. Visits look up "current oil" by finding the row where `effective_to is null`. Reports can reconstruct what oil was used in any past month.

### 4.5 The Hard Rules

1. **No price below threshold** — system blocks save; Manager/approver override logged.
2. **Live capture only** — refill photos from camera, never gallery; enforced at OS level.
3. **GPS must match** — within `gps_accuracy_threshold_m` (tenant setting, default 200m) of the service location, falling back to the contract snapshot when needed.
4. **Costs are permission-only** — RLS and safe views enforce it at the database level.
5. **Money is exact** — `numeric(15,3)` and `Decimal`, never `float` or `double`.
6. **Plans are not execution** — appointments/assignment/reschedule never prove
   a visit; GPS/photo/quantity/outcome belong to trusted execution.
7. **History is not deleted** — posted financial records and used contracts are
   corrected through lifecycle/reversal paths with permission, reason, and
   immutable audit.

---

## 5. Success Criteria

The system is successful when:

- [ ] All 115 active contracts migrated from Sheets, tracked live
- [ ] Owner answers "is contract X profitable?" in <5 seconds
- [ ] 100% of refills have GPS + photo + agent identity recorded
- [ ] Monthly P&L generates in <30 seconds
- [ ] A user finds every daily task through a coherent module in <5 clicks
- [ ] Every sensitive edit/cancellation/approval is attributable with a reason
- [ ] No data entry happens in Sheets anymore
- [ ] A second tenant can be onboarded by Admin without code changes

---

## 6. Constraints

- **Solo development with Cursor AI** — owner is a beginner programmer
- **Lean on managed services** — Supabase, Resend, Meta WhatsApp; no self-hosted backend
- **Arabic-first** with English toggle — RTL is the default
- **Must work offline on mobile** during field visits, syncing when online
- **Budget conscious** — only Supabase Pro tier and per-message WhatsApp costs
