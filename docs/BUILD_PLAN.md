# BUILD_PLAN.md — Phased Implementation Roadmap

> A step-by-step plan to go from empty Supabase project to a running, production-grade ERP.
> Designed for solo development with Cursor AI.

---

## How to Use This Document

Each phase has:
- **Goal** — what success looks like
- **Tasks** — concrete steps in dependency order
- **Deliverables** — what should exist at the end
- **Acceptance** — how you know you can move to the next phase

Don't skip ahead. The order matters. Each phase builds on the previous.

---

## Phase 0 — Project Setup (≈ 1 week)

### Goal
Have a working Flutter project, a Supabase project, and a basic CI workflow.

### Tasks
1. Create the Flutter project: `flutter create --org com.hayatsecret --platforms windows,macos,android,ios hayat_secret`
2. Set up project structure per `ARCHITECTURE.md` section 3
3. Add dependencies to `pubspec.yaml`:
   - `supabase_flutter`
   - `flutter_riverpod`, `riverpod_annotation`
   - `riverpod_generator`, `build_runner` (dev)
   - `go_router`
   - `decimal`
   - `intl`
   - `image_picker`
   - `geolocator`
   - `mobile_scanner`
   - `drift`, `drift_flutter` (mobile cache)
   - `logger`
   - `lucide_icons`
   - `printing`, `pdf`
4. Create Supabase project (Pro tier for production, Free for dev)
5. Configure environments: `.env.dev`, `.env.staging`, `.env.prod`
6. Set up GitHub repo with two branches: `main`, `dev`
7. Configure GitHub Actions: lint + format + test on PR

### Deliverables
- Empty Flutter app that opens to a blank screen on Windows, Android, iOS
- Supabase project accessible via dashboard
- Cursor opens project and `.cursorrules` is in place

### Acceptance
- `flutter run -d windows` opens the app
- `flutter run -d android` opens on emulator
- `flutter analyze` passes with zero warnings

---

## Phase 1 — Database Foundations (≈ 2 weeks)

### Goal
All tables exist in Supabase with correct types, RLS, and a working test tenant.

### Tasks

**1.1 Migrations 001–015**
Create migrations in `supabase/migrations/` per the order in `DATABASE_SCHEMA.md` section 21.

For each migration:
- Write SQL
- Test locally with `supabase db reset`
- Push to dev Supabase
- Verify in dashboard

**1.2 RLS Policies (migration 028)**
Implement policies per `SECURITY.md` role matrix.

**1.3 Test Tenant Seed**
A SQL script that creates:
- One tenant "Hayat Secret"
- Owner user with email
- Sample chart of accounts (full template)
- One main warehouse
- A few product groups (Devices, Oils, Perfumes)
- Sample employee records

**1.4 RLS Verification Script**
Write a SQL test script:
- Log in as tenant A user → query products → only A's products
- Log in as tenant B user → query → only B's
- Log in as field agent → try to insert into `journal_entries` → blocked
- Log in as a User with `audit_log.view` → try to read `audit_log` → success
- etc.

### Deliverables
- All tables created
- RLS policies in place
- Test tenant working
- Cursor can run any query through the Supabase JS client

### Acceptance
- A SQL query through `supabase.from('products').select()` returns only test tenant data
- Trying as an unauthenticated user returns 0 rows
- RLS verification script passes all checks

---

## Phase 2 — Authentication & Routing (≈ 1 week)

### Goal
Login screen works. After login, user is routed to the right place based on role.

### Tasks
1. Build `core/network/supabase_client.dart` with the client wrapped in a provider
2. Build `core/routing/app_router.dart` with GoRouter and permission-aware redirects
3. Build the auth feature:
   - Login screen (email + password)
   - Forgot password flow
   - Logout
4. Build the JWT hook in Supabase to add `tenant_id` and `role` to claims
5. Build permission-based redirect logic:
   - Manager or office permissions → desktop home
   - users with field permissions → mobile Today screen
6. Build the bilingual scaffold:
   - Initialize `intl` with ar and en
   - Locale toggle in settings (saved in shared_preferences)
   - `Directionality` widget at app root

### Deliverables
- Login screen in Arabic and English
- Successful login routes to role-appropriate screen
- Locale toggle works

### Acceptance
- Manager logs in → sees dashboard placeholder
- Field agent user logs in → sees mobile Today screen placeholder
- Switching locale flips the entire UI to RTL/LTR

---

## Phase 3 — Products & Inventory (≈ 2 weeks)

### Goal
Admin can manage products, units, and warehouses. Stock balances are visible.

### Tasks

**3.1 Models & Repositories**
- `Product` model, `ProductGroup` model, `ProductUnit` model
- `ProductRepository`, `ProductGroupRepository`, `ProductUnitRepository`
- All using Riverpod-generated providers

**3.2 Product List Screen (Desktop)**
- Tab bar: by group
- Search field
- Filter chips: type (sale/asset_rental/consumable_rental), active/inactive
- Data table with: SKU | Name | Group | Type | Sale Price | Cost (requires cost field permission) | Stock
- Click row → product detail

**3.3 Product Detail Screen (Desktop)**
- Form with all product fields
- Image upload
- Pricing block: sale_price, rental_price_monthly, min prices
- Cost block (requires cost field permissions): avg_cost, last_purchase_cost
- Stock block: balances per warehouse
- For asset_rental: list of `product_units` with statuses

**3.4 Add Product Wizard**
- Step 1: name + group + type
- Step 2: unit of measure + pricing
- Step 3: rental specifics (if rental type)
- Step 4: serial-tracked? barcode? maintenance-trackable?
- Save → fires INSERT

**3.5 Product Units Management**
- Add unit: serial number + barcode + initial cost
- Bulk add: paste a CSV of serial numbers
- Each unit shows its history (which contracts it's been on)

**3.6 Warehouses Screen**
- List + add warehouse
- For van warehouses, link to an employee

**3.7 Inventory Movements Log**
- Filterable table of all movements
- Adjustments: manual stock-in / stock-out with reason

### Deliverables
- Admin can fully manage products
- Stock balances update correctly
- Field agents see `products_safe` view (no costs)

### Acceptance
- Create a product → it appears in list
- Add 10 product units → they appear in unit list
- Manual stock-in → balance increases
- Sample purchase invoice → balance increases + WAC updates

---

## Phase 4 — Customers, Suppliers & Chart of Accounts (≈ 1 week)

### Goal
Customer and supplier management fully working. CoA visible and customizable.

### Tasks
1. Customer CRUD screens (desktop + mobile)
2. Auto-generate customer code (CUST-0001)
3. Auto-create A/R subaccount when customer is created
4. Customer detail tabs: Profile | Contracts | Invoices | Vouchers | Statement
5. Customer 360 Timeline: chronological stream of contracts, visits, invoices, vouchers, messages, notes
6. Supplier CRUD
7. CoA tree view (requires `chart_of_accounts.view`)
8. CoA: add/edit non-system accounts

### Deliverables
- Customers and suppliers fully managed
- Chart of accounts visible and editable
- Customer 360 Timeline gives a single operational history per customer

### Acceptance
- Create a customer → A/R subaccount auto-created
- View customer statement (initially empty) without error
- Customer timeline shows new invoice/payment/contract events in order

---

## Phase 5 — Invoices, Vouchers & Journal (≈ 3 weeks)

### Goal
Full accounting cycle works. Purchase → Sale → Receipt → P&L.

### Tasks

**5.1 Stored Functions**
Implement all RPCs per `DATABASE_SCHEMA.md` section 19:
- `record_purchase_invoice`
- `record_sales_invoice`
- `recalculate_wac` (called by the above)
- Each must create the journal entries

**5.2 Invoice Screens (Desktop)**
- Invoices list (filterable by type, status, customer)
- New sales invoice form
- New purchase invoice form
- Invoice detail with lines, payment history, journal entry view
- Confirm / cancel actions
- PDF preview & generate

**5.3 Voucher Screens (Desktop)**
- Vouchers list
- New receipt voucher (with invoice allocation UI)
- New payment voucher
- Voucher detail
- Receipt PDF & generate

**5.4 Quotations**
- Quotation list + new
- Convert to invoice button
- PDF generation

**5.5 Cash & Bank Reconciliation View**
- Per cash account: list of vouchers in date range
- Running balance

**5.6 Customer Statement**
- Date range filter
- Opening balance + transactions + closing balance
- Export as PDF

### Deliverables
- A full purchase → sale → payment cycle works
- Journal entries auto-generated and balanced
- PDFs printable

### Acceptance
- Record a purchase of 100 oil units → balance + WAC update
- Record a sale → A/R increases, inventory decreases
- Record a receipt voucher → A/R clears
- Print invoice PDF in Arabic and English

---

## Phase 6 — Contracts (the Big One) (≈ 4 weeks)

### Goal
The core of the system: contracts can be created, billed, refilled, and closed.

### Tasks

**6.1 Stored Functions**
- `create_rental_contract` (atomic, per `CONTRACTS_LOGIC.md` section 7)
- `close_contract`
- `contract_profitability`

**6.2 Contracts List Screen (Desktop)**
- Filter chips per `CONTRACTS_LOGIC.md` section 11.1
- Search by contract #, customer, phone

**6.3 New Contract Form (Desktop)**
- Multi-step wizard per `CONTRACTS_LOGIC.md` section 11.2
- Live profitability preview (requires `contracts.field.snapshot_profit`)
- Min-profit enforcement

**6.4 Contract Detail Screen (Desktop)**
- Tabs per `CONTRACTS_LOGIC.md` section 11.3
- Close contract button (requires `contracts.close`)
- Switch oil button (requires `contracts.oil_change`)

**6.5 Oil Switching**
- UI to change `contract_oil_changes`
- Effective date picker

**6.6 Monthly Billing Job**
- Edge Function scheduled daily
- For each tenant: identify contracts billing today, generate invoices

**6.7 Trial Workflow**
- Trial expiry calendar event (auto-generated)
- "Convert to rental" button
- "Mark as returned" button

### Deliverables
- Contracts can be created, viewed, modified, closed
- Monthly invoices generate on schedule
- Trial contracts handled properly

### Acceptance
- Create a contract with profit just above min → saves
- Create with profit below min → rejected (or override flow if user has `contracts.approve_override`)
- Wait for billing day → invoice appears (or trigger manually for test)
- Close a contract → device returns to inventory

---

## Phase 7 — Calendar & Scheduling (≈ 2 weeks)

### Goal
A unified calendar showing all date-bound events, with reminders.

### Tasks
1. `calendar_events` table + RLS
2. `daily_calendar_seed_job` — generates next-30-days events for active contracts
3. `reminders_job` — runs every 15 minutes
4. Calendar screen (desktop): Day / Week / Month views
5. Calendar screen (mobile): same views, touch-optimized
6. Manual event creation (follow-ups, custom)
7. Drag-and-drop rescheduling (desktop)
8. Agent assignment / reassignment
9. Route View: map of a user's daily visits by area and time, display-only in v1 planning
10. Filters

### Deliverables
- Calendar shows real upcoming events
- Reminders fire on schedule
- Agents see their assignments
- Daily route map helps the office review workload geographically

### Acceptance
- Active contracts produce calendar events for next 30 days
- An event 1 hour from now triggers a notification
- A day's visits can be viewed on a map without route optimization

---

## Phase 8 — Mobile Field Operations (≈ 4 weeks)

### Goal
Field agents can do their full daily workflow on the mobile app, online and offline.

### Tasks

**8.1 Mobile Shell**
- Bottom nav (5 tabs)
- Today screen (default home)
- Calendar screen (mobile version)
- Customers screen
- Van Stock screen
- More screen

**8.2 Refill Flow**
- Visit detail → Begin Visit → Refill form → Complete
- Per `FIELD_OPS.md` section 4
- Photo via camera only
- GPS check-in

**8.3 New Contract on Mobile**
- Multi-step flow optimized for phone
- Barcode scan for device picking
- Signature capture

**8.4 Collection Flow**
- Visit type = collection
- Quick-allocate to invoices
- Auto-send receipt

**8.5 Van Stock**
- Current balances view
- Request refill
- End-of-day reconciliation

**8.6 Offline Mode**
- Drift schema for local cache
- Sync engine
- Idempotent RPCs (use `client_id`)
- "Pending sync" badges

**8.7 EXIF Validation Edge Function**
- Triggered on photo upload
- Reads EXIF
- Flags visits with mismatched timestamps

**8.8 Visit Risk Flags**
- Store GPS mismatch, missing EXIF, stale photo timestamp, and manual proceed reasons
- Feed these flags into the Phase 10 Suspicious Visits Report

### Deliverables
- Field agent does full day's work on mobile
- Offline visits sync when online
- Photos verified via EXIF
- Visit risk flags are stored consistently for reporting

### Acceptance
- Complete 5 refills offline → all sync correctly when online
- Take a 3-day-old photo → visit flagged in Manager report
- GPS 1km from contract location → visit flagged

---

## Phase 9 — POS, Maintenance & HR (≈ 3 weeks)

### Goal
Add-on modules that round out the system.

### Tasks

**9.1 POS Screen**
- Walk-in sale
- Barcode scan
- Cart
- Payment selection
- Print receipt

**9.2 Maintenance Module**
- Maintenance records list
- Add maintenance from field visit
- Status workflow: reported → in_progress → completed / unrepairable
- Per-unit maintenance history

**9.3 HR**
- Employee CRUD
- Commission rules per role/employee
- Monthly salary generation
- Advances tracking & auto-deduction
- Salary voucher creation

### Deliverables
- POS works for cash sales
- Maintenance workflow tracks device repairs
- Salaries generate monthly

### Acceptance
- Sell a perfume at POS → inventory drops, cash receipt generated
- Mark a device as broken → unit status changes, maintenance record created
- Generate January salaries → vouchers created

---

## Phase 10 — Reports & Dashboards (≈ 2 weeks)

### Goal
All key reports work. Managers can answer business questions in under a minute.

### Tasks
1. P&L report (date range)
2. Debt aging report
3. Contract profitability report (uses snapshots)
4. Agent performance report
5. Inventory valuation report
6. Trial expiry watch
7. Sales summary (by product, by customer, by period)
8. Owner dashboard (key KPIs at a glance)
9. Contract Health Score: combines profit, overdue balance, missed visits, GPS/photo flags, and renewal risk
10. Debt Priority List: ranks customers by overdue amount, age, last payment, and active contract value
11. Suspicious Visits Report: GPS mismatch, stale/missing EXIF, unusual timing, repeated manual proceed reasons
12. Price Review Assistant: identifies contracts near/below target profit when current oil/device costs change
13. Renewal / Increase Suggestions: flags old contracts that may need price review before renewal
14. Audit Review Dashboard: sensitive changes, overrides, cancellations, permission changes
15. Data Quality Warnings: missing GPS, products without cost, contracts without refill day, duplicate phone numbers

### Deliverables
- All reports per `PROJECT.md` 3.1 working
- Each exportable to PDF and CSV
- Smart operational dashboards are available to Managers

### Acceptance
- Generate P&L for last month in <30 seconds
- "Is contract X profitable?" answerable in <5 clicks
- Contract Health Score identifies at-risk contracts without manual spreadsheet work
- Debt Priority List gives a ranked collection queue
- Suspicious Visits Report shows all flagged visits with supporting evidence

---

## Phase 11 — Communications (≈ 2 weeks)

### Goal
Automated email + WhatsApp working.

### Tasks
1. Resend integration (Edge Function)
2. Meta WhatsApp Cloud API integration (Edge Function)
3. Notification templates per event:
   - Contract created
   - Refill receipt
   - Payment received
   - Debt reminder
   - Refill reminder to customer
4. Template editor in settings (requires `settings.templates.edit`)
5. Notification queue worker
6. Customer notification preferences (opt-in/out per channel)

### Deliverables
- Send a receipt → customer gets it via WhatsApp and email
- Refill reminder fires 1 day before scheduled visit

### Acceptance
- Test customer receives all template types
- Failed sends retry up to 3 times then mark `failed`

---

## Phase 12 — Polish, Testing & Production (≈ 3 weeks)

### Goal
Production-ready system.

### Tasks
1. End-to-end tests for critical flows:
   - Create customer + contract + first refill + payment
   - Purchase → WAC update → sale → profit recognized
2. Migrate live data from existing Google Sheets (one-time script)
3. Production Supabase setup (Pro tier)
4. Signed installer builds:
   - Windows MSIX
   - macOS DMG (notarized)
5. Mobile builds:
   - Android (Play Console internal track)
   - iOS (TestFlight)
6. Sentry integration for production error tracking
7. Documentation for the owner (admin manual)
8. User training (the team)
9. Soft launch with parallel running (Sheets + new system) for 1 month
10. Cutover

### Deliverables
- Production system live
- All 115 contracts migrated
- Team trained
- Sheets retired

### Acceptance
- One full month with zero data entry in Sheets
- No data loss
- No critical bugs in 30 days

---

## Phase 13+ — Future Work

These are out of v1 scope but worth noting for the roadmap:

- **Multi-tenant onboarding UI** — admin tool to provision new tenants without DB scripts
- **Tenant subscription billing** — bill tenants for SaaS usage
- **Customer portal** — let customers view their own contracts, balances, request refills
- **Advanced analytics** — forecasting, trend analysis, customer churn prediction
- **Mobile for Manager account type** — full Manager features on phone (currently desktop-only)
- **Multi-branch support** — within a single tenant
- **Multi-currency** — for tenants in other GCC countries
- **API for third-party integrations**

### Explicitly Not Planned

- **Van Stock Alerts** — automatic low-stock alerts before visits are not needed for this business workflow.

---

## Estimated Timeline (Solo, with AI Assistance)

| Phase | Duration | Cumulative |
|-------|----------|------------|
| 0 — Setup | 1 wk | 1 wk |
| 1 — DB | 2 wk | 3 wk |
| 2 — Auth | 1 wk | 4 wk |
| 3 — Products | 2 wk | 6 wk |
| 4 — Customers | 1 wk | 7 wk |
| 5 — Invoices & Vouchers | 3 wk | 10 wk |
| 6 — Contracts | 4 wk | 14 wk |
| 7 — Calendar | 2 wk | 16 wk |
| 8 — Mobile | 4 wk | 20 wk |
| 9 — POS + Maint + HR | 3 wk | 23 wk |
| 10 — Reports | 2 wk | 25 wk |
| 11 — Comms | 2 wk | 27 wk |
| 12 — Polish & Launch | 3 wk | **30 wk** |

**Total: ~30 weeks (~7 months)** of focused work. Realistic for solo+AI; faster if you skip non-essential features in v1 (POS, advanced HR, full notifications).

---

## What to Build First (MVP — 12 weeks)

If you want a minimal working version fast, cut to:
- Phase 0, 1, 2 (setup + DB + auth)
- Phase 3, 4 (products + customers)
- Phase 6 (contracts — partial: no oil switching, no trial workflow)
- Phase 8 partial (mobile: just refills, no offline, no advanced flows)
- Manual invoicing instead of automated

That gives you the basics in ~12 weeks. Iterate from there.
