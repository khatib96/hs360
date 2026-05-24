# PROJECT.md — Vision & Scope

> Updated 2026-05-16 to resolve conflicts: operational job names are examples only. Access control is Manager/User + explicit permissions. KWD is the first tenant's default currency, not a hardcoded system rule.

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

### 2.3 Operational Roles
- **Owner / Admin** — sees everything, sets policies, owns financial visibility
- **Sales agents** — close new contracts, may also sell devices/oils
- **Refill technicians** — service existing contracts monthly
- **Hybrid agents** — do both
- **Accountant** — manages invoices, vouchers, statements
- **Warehouse keeper** — manages stock, van assignments, transfers

---

## 3. Scope

### 3.1 In Scope

**Multi-Tenancy**
- Single shared database with `tenant_id` on every row
- RLS isolation between tenants
- Per-tenant settings (currency, locale, fiscal year, branding)
- User invitations limited to tenant scope

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
- Tracks oil-type changes over contract lifetime
- Open-ended or fixed-term contracts
- Trial conversion workflow

**Calendar & Scheduling**
- Unified calendar view: refills due, contract endings, trial expiries, follow-ups
- Filterable by agent, date range, status
- Daily/weekly/monthly views
- Reminders (push + email + WhatsApp)
- Auto-generated refill schedule based on each contract's `refill_day`

**Field Operations (Mobile)**
- Daily visit schedule per agent
- Live-camera-only photo proof (gallery uploads blocked)
- GPS check-in/check-out with distance verification
- Van stock (each agent = sub-warehouse)
- Daily reconciliation
- On-the-spot oil-type swap with reason capture
- Mobile receipt voucher issuance with auto-send to customer

**Accounting**
- Full chart of accounts (double-entry)
- Receipt vouchers, payment vouchers, journal entries
- Sales/purchase invoices, returns, opening balance
- Inventory adjustments
- Customer/supplier statements
- Debt aging reports (30/60/90/120+)

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
- P&L with rental depreciation factored in
- Per-contract profitability (uses snapshot, not current prices)
- Debt aging
- Field agent performance (visits, collections, contracts)
- Inventory valuation
- Trial expiry watch
- Active contracts dashboard

**HR**
- Employee records
- Role assignment
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
- Multi-branch within a tenant (single branch first)
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
| `asset_rental` | Tracked per-unit by S/N when available; returns on contract end | Sale price; contract basis = sale price / lifespan | Diffuser devices |
| `consumable_rental` | Decremented on refill; never returns | Sale price converted by unit/quantity | Oils |

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
- Device monthly depreciation (cost ÷ lifespan)
- Oil cost per refill (qty × unit cost at that moment)
- Total monthly cost

These snapshots are what profitability reports use. They do **not** change when prices change later. This is correct accounting behavior.

### 4.4 Oil-Type Tracking

The oil a contract uses is **a time-bounded record**, not a fixed column. A contract can switch oils any number of times. Each switch creates a new record with `effective_from` set. Visits look up "current oil" by finding the row where `effective_to is null`. Reports can reconstruct what oil was used in any past month.

### 4.5 The Five Hard Rules

1. **No price below threshold** — system blocks save; Manager/approver override logged.
2. **Live capture only** — refill photos from camera, never gallery; enforced at OS level.
3. **GPS must match** — within `gps_accuracy_threshold_m` (tenant setting, default 200m) of contract location.
4. **Costs are permission-only** — RLS and safe views enforce it at the database level.
5. **Money is exact** — `numeric(15,3)` and `Decimal`, never `float` or `double`.

---

## 5. Success Criteria

The system is successful when:

- [ ] All 115 active contracts migrated from Sheets, tracked live
- [ ] Owner answers "is contract X profitable?" in <5 seconds
- [ ] 100% of refills have GPS + photo + agent identity recorded
- [ ] Monthly P&L generates in <30 seconds
- [ ] No data entry happens in Sheets anymore
- [ ] A second tenant can be onboarded by Admin without code changes

---

## 6. Constraints

- **Solo development with Cursor AI** — owner is a beginner programmer
- **Lean on managed services** — Supabase, Resend, Meta WhatsApp; no self-hosted backend
- **Arabic-first** with English toggle — RTL is the default
- **Must work offline on mobile** during field visits, syncing when online
- **Budget conscious** — only Supabase Pro tier and per-message WhatsApp costs
