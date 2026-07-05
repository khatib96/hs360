# CONTRACTS_LOGIC.md — Contract Management Logic

> This is the heart of the system. Read it carefully. Every other module depends on these rules.
> Updated 2026-05-16 to resolve conflicts: KWD values are examples. Contract math uses `numeric(15,3)` storage and tenant currency display settings.

---

## 1. Contract Names And Types

Phase 6 uses these business labels:

- `فترة تجريبية` — trial period.
- `عقد` — generic contract label in shared UI.
- `عقد إيجار` — paid rental contract.

A 12-month contract is not a separate database type in Phase 6. It is a rental
contract with a 12-month term.

### 1.1 Trial Contract (`type = 'trial'`)
- **Free for the customer** during the trial period (default 30 days, tenant-configurable)
- Device is shipped to the customer; tracked as `unit_status = 'trial'`
- No invoices generated during trial
- System raises a calendar event 7 days before trial end
- At trial end, sales agent records the outcome:
  - **Converted** → upgrades to a `rental` contract (new contract_number, linked)
  - **Returned** → device comes back to inventory, contract status = `completed`
  - **Extended** → trial_end_date pushed out, reason logged

### 1.2 Rental Contract (`type = 'rental'`)
- Customer pays a fixed monthly value
- Device stays company-owned (`unit_status = 'rented'`)
- Oil refilled on a tenant-configured cadence (usually monthly)
- Monthly invoice generated automatically on billing day
- Open-ended OR fixed term (12/24/etc months)

---

## 2. Pricing Model — The Owner's Rule

### 2.0 Product Pricing Boundary

Products do **not** have a rental price.

Product records store sale/cost data only:
- `sale_price` is the product's sale value in its primary unit.
- Purchase cost / WAC comes from purchase and stock flows; it is not the rental contract price.
- `expected_lifespan_months` exists only for asset-rental products and can differ per product.

Rental pricing is decided on the **contract**, not on the product.

Phase 6 introduces tenant contract settings for the internal basis used by
profit checks:

- Rental asset basis can be actual unit purchase cost, product average cost, or
  product sale price.
- Rental consumable basis can be product sale price, product average cost, or
  product last purchase cost.

The default owner preference for Phase 6 is:

- rental assets use the selected unit's actual cost where available;
- rental consumables use sale price unless settings later choose otherwise.

### 2.1 What the Agent Enters
**Only one number:** the monthly rental value.

That's it. No per-line prices. No formulas to memorize. The customer agreed to pay X dinars per month, the agent types X.

### 2.2 What the System Computes (Snapshot at Save Time)

When the contract is saved, the system reads the current product data and freezes a **snapshot** on the contract row:

```
Inputs available to the system:
  • Selected device unit/product (asset_rental)
      product_unit.purchase_cost or configured basis
      product.expected_lifespan_months  = e.g. 24 as pricing basis
  • Selected rental consumable product (consumable_rental)
      product.sale_price or configured basis per primary unit
      product.unit_primary / unit_secondary / conversion_factor
  • Consumable qty per refill/replacement (entered by agent) = e.g. 500 ml
  • Tenant's min_monthly_profit setting
  • Optional tenant default pricing multiplier for suggestions

Computations:

  asset_monthly_basis      = configured_asset_basis / expected_lifespan_months
  consumable_monthly_basis = converted_consumable_qty × configured_consumable_basis
  total_monthly_basis      = asset_monthly_basis + consumable_monthly_basis
  minimum_allowed_monthly_value =
      total_monthly_basis + tenant.min_monthly_profit
  suggested_monthly_value =
      total_monthly_basis × tenant.default_rental_multiplier
      (if configured)
  expected_monthly_profit =
      monthly_rental_value − total_monthly_basis

Validation:

  IF monthly_rental_value < minimum_allowed_monthly_value
    THEN reject save
       OR require `contracts.approve_override` with reason
```

### 2.3 Example (Hayat Secret Defaults)

```
Owner sets in Settings:
  min_monthly_profit = 5.000 KWD

Agent creates contract:
  Customer: "Cafe Bloom"
  Device: Diffuser Model X (unit cost = 60.000, lifespan basis = 24 months)
  Rental consumable: "Hilton" (sale_price = 15.000 per liter)
  Consumable qty per refill: 500 ml
  Monthly rental value entered by agent: 20.000 KWD

System computes:
  asset_monthly_basis      = 60.000 / 24 = 2.500
  consumable_monthly_basis = 0.5 liter × 15.000 = 7.500
  total_monthly_basis      = 10.000
  minimum_allowed_monthly_value = 10.000 + 5.000 = 15.000
  expected_monthly_profit = 20.000 − 10.000 = 10.000

Validation:
  20.000 >= 15.000 → PASS

Saved to contract:
  monthly_rental_value             = 20.000
  snapshot_device_monthly_basis    = 2.500
  snapshot_oil_monthly_basis       = 7.500
  snapshot_total_monthly_basis     = 10.000
  snapshot_monthly_profit          = 10.000
  snapshot_min_profit_threshold    = 5.000
```

If the field user tried `monthly_rental_value = 11.000` or `12.000`, both are below the minimum allowed `15.000`. The system rejects the save and offers a manager approval path.

### 2.4 Why Snapshots Are Critical

If, six months later, the price of "Hilton" oil rises from 10 to 15 KWD/liter, the **old contract's profit** must still be reported based on what the cost was at signing. Otherwise:
- Profit reports would retroactively change
- Historical analysis would be wrong
- Trends would be impossible to detect

The snapshot is sacred. It never updates after contract creation.

### 2.5 Depreciation And Usage Boundary

Phase 6 does **not** implement accounting depreciation or deep asset-consumption
adjustments.

`expected_lifespan_months` is a pricing/profit basis only. A device may be
configured as 24 months but operate for 30 months or more. Actual depreciation
or usage-based asset consumption should be handled in a later accounting phase
if the business needs it.

The important Phase 6 rule is: device usage can only be inferred from real
contract/trial/visit activity, not from time passing while the device is not in
use.

---

## 3. Contract Total Value

For **fixed-term contracts**, the system also computes:

```
total_contract_value = monthly_rental_value × number_of_months
```

This is informational only — used for:
- Customer-facing contract PDF
- "Total revenue committed" dashboards
- Goal-tracking reports

For open-ended contracts, this field is `NULL`.

---

## 4. Contract Lines — What's Inside

A contract has one or more **lines**, but lines have **no prices** on them. They describe what's included, not how much each part costs.

### 4.1 Asset Lines
- Exactly one device per contract is typical (but the schema supports more)
- Each asset line references a specific `product_unit_id` (a real device with a serial number)
- If the selected product has `is_serialized = true`, `product_unit_id` is mandatory and the RPC must reject product-only asset lines
- On contract activation, that unit's status changes to `rented`

### 4.2 Consumable Lines
- One per oil included in the contract
- Specifies `qty_per_refill` (e.g. 500 ml)
- Specifies `refill_frequency_months` (usually 1 — every month)

### 4.3 Cost Snapshot per Line
Each line has its own `snapshot_unit_cost` and `snapshot_monthly_cost`, even though prices aren't customer-facing. These exist so per-line profitability can be analyzed if needed.

---

## 4.5 Customer And Service Location Boundary

A contract belongs to one customer/account and one operational service location.

- `customer_id` is the company/account that owns the ledger, invoices, vouchers, and statement.
- `service_location_id` is the branch/site/address where the device is installed and visits happen.
- If the customer has one active service location, contract creation may auto-select it.
- If the customer has multiple active service locations, contract creation must require explicit location selection.
- If the customer has no active service location, contract creation should offer inline service-location creation before continuing.

The contract stores a frozen location snapshot at signing:

- location name.
- country, governorate, area, city/address.
- Google Maps URL and latitude/longitude if available.
- contact person and phone for that site.

Changing the service location profile later must not rewrite old contract documents or historical visit context.

---

## 5. Oil-Type Switching Over Time

Customers change their minds. "I want to switch from Hilton to Vanilla starting next refill."

### 5.1 The Mechanism

The `contract_oil_changes` table tracks oil over time as a series of time-bounded records:

```
contract_oil_changes:
─────────────────────────────────────────────────────────────
contract_line_id | oil_product | effective_from | effective_to
─────────────────────────────────────────────────────────────
abc-line-1       | Hilton      | 2026-01-01     | 2026-02-28
abc-line-1       | Vanilla     | 2026-03-01     | NULL  ← current
─────────────────────────────────────────────────────────────
```

### 5.2 Where the Agent Changes It

**Two places:**

**A. From the contract detail screen (requires `contracts.oil_change`)** — for advance scheduling.
The user picks a future effective date.

**B. During a refill visit (mobile, in the field)** — for on-the-spot change.
The agent opens the refill screen. The "Oil" dropdown is **pre-filled with the current oil**. The agent can change it before completing the refill. If changed:
1. The current oil_change row gets `effective_to = today - 1 day`
2. A new oil_change row is inserted: `effective_from = today, effective_to = NULL`
3. The visit records `oil_product_id` = the new oil
4. Optional: the system asks for a reason (kept in audit)

### 5.3 What the Refill Screen Shows

```
┌─────────────────────────────────────────┐
│ Refill — Cafe Bloom                     │
├─────────────────────────────────────────┤
│ Device: Diffuser Model X                │
│ Last refill: 2026-04-03                 │
│ Refill cadence: every month, day 3      │
│                                         │
│ Oil:  [ Hilton ▼ ]    ← current        │
│ Qty:  [ 500 ml ]      ← from contract   │
│                                         │
│ Photo: [📷 Take photo]                  │
│ GPS:   ✓ Verified (within 45m)          │
│                                         │
│ Payment:                                │
│   ○ Collected now: [____] KWD          │
│   ● No payment today (will pay later)   │
│                                         │
│ Notes: [_____________]                  │
│                                         │
│      [Cancel]    [Complete refill]      │
└─────────────────────────────────────────┘
```

If the agent picks a different oil from the dropdown, a confirmation appears: *"Switch oil from Hilton to Vanilla from today onward?"* — Yes/No.

---

## 6. Contract Lifecycle

```
DRAFT
  │
  │ (agent fills in form)
  │
  ▼
ACTIVE                           ← create_rental_contract RPC fires
  │
  │ (monthly billing cycle runs, refills happen)
  │
  ├──→ SUSPENDED (manual pause, e.g. customer travels)
  │       │
  │       └──→ resumed → ACTIVE
  │
  ├──→ COMPLETED (end_date reached, normal closure)
  │       │
  │       └─→ asset returns, final settlement
  │
  ├──→ TERMINATED_EARLY (customer cancels before end)
  │       │
  │       └─→ asset returns, partial month billing, optional penalty
  │
  └──→ EXPIRED (auto for trial contracts past trial_end_date without action)
```

---

## 7. Atomic Contract Creation — RPC

`create_rental_contract` is the atomic operation. It must do all of these in a single transaction:

1. Insert `contracts` row with snapshots computed, `customer_id`, `service_location_id`, and frozen service-location/contact snapshot fields
2. Insert `contract_lines` rows
3. Insert initial `contract_oil_changes` rows (one per consumable line, `effective_from = start_date`)
4. Update `product_units.status` for selected devices to `rented` or `trial`
5. Update `product_units.current_contract_id`, `current_customer_id`, and `current_service_location_id`
6. Decrement `inventory_balances.qty_available`, increment `qty_rented` (or `qty_trial`)
7. Insert `inventory_movements` records (`rental_out`)
8. **For rental contracts:** create first month's `invoices` row (`type = rental_monthly`)
9. **For rental contracts:** create the matching `journal_entries`:
   - Dr Accounts Receivable (customer)
   - Cr Rental Income
10. Seed initial `calendar_events` with `customer_id` and `service_location_id` (first refill, billing date, end-of-trial if trial, contract end if fixed-term)
11. Insert `audit_log` row

Any step failing rolls back everything.

---

## 8. Min-Profit Override Workflow

When the system detects `expected_profit < min_threshold`:

### 8.1 If the user has `contracts.approve_override`
- A confirmation dialog appears: *"Profit is below minimum (X < Y). Proceed?"*
- If confirmed, contract is saved with `min_profit_overridden = true` and a logged reason
- Reason field is **required**

### 8.2 If the user does not have `contracts.approve_override`
- Save is rejected with a clear message
- Field user can tap "Request Manager approval"
- A notification is sent to Managers and users with `contracts.approve_override`
- The contract is saved as `draft` with `pending_approval` flag
- An approver opens it, reviews, and either:
  - Approves → contract becomes `active`, override logged
  - Rejects → contract stays draft, agent is notified

---

## 9. Monthly Billing Cycle

A scheduled Edge Function runs daily. For each tenant, it processes contracts where `billing_day = today's day of month`:

```
For each active contract due to bill today:
  1. Generate invoice (type = rental_monthly)
  2. Single line: "Monthly rental — {month name} {year}"
       qty = 1, unit_price = monthly_rental_value
  3. Post journal entry (Dr AR, Cr Rental Income)
  4. Generate PDF, store in invoice_pdfs bucket
  5. If tenant.auto_send_invoice_pdf:
       queue notification (email + WhatsApp)
  6. Mark invoice.sent_at when sent
```

This runs **separately** from refills. Billing and refilling are decoupled:
- Customer might pay 3 months upfront (vouchers don't need refill visits)
- Customer might delay payment for months (system still bills, A/R grows)
- A refill visit might happen without any payment exchange

---

## 10. The Calendar — Unifying View

The calendar aggregates all date-bound events across the system:

| Event Type | Source |
|------------|--------|
| `refill_due` | Generated from active contracts based on `refill_day` |
| `contract_start` | Start of each contract |
| `contract_end` | End_date of fixed-term contracts |
| `trial_ending` | 7 days before `trial_end_date` |
| `follow_up` | Manually scheduled (e.g. by sales agent after a pitch) |
| `maintenance_due` | When a device hits a maintenance threshold |
| `payment_due` | Overdue invoices |
| `custom` | Anything user-defined |

### 10.1 Views Available

- **Day view** — list of today's events, ordered by time
- **Week view** — 7-column grid
- **Month view** — calendar grid with event dots
- **Agent view** — filtered by `assigned_agent_id`
- **Customer view** — all events for one customer (in customer detail screen)
- **Service location view** — all events for one customer branch/site, useful for multi-location customers

### 10.2 Reminders

Each event has `reminder_offsets_minutes` (default: 1440 = 1 day, 60 = 1 hour before).

A scheduled Edge Function runs every 15 minutes:
1. Find events where `scheduled_date + scheduled_time - offset` is within the last 15 minutes
2. Generate notifications (push to mobile app, email, WhatsApp per tenant settings)
3. Mark as sent

### 10.3 Recurring Refills

Active contracts seed monthly recurring events. The `recurrence_rule` is iCal RRULE format (e.g. `FREQ=MONTHLY;BYMONTHDAY=3` for the 3rd of each month).

A daily job materializes the next 30 days of recurring events into concrete `calendar_events` rows. This makes querying fast and lets agents see them in their calendar.

---

## 11. Contract UI — The Three Screens

### 11.1 Contracts List
- Filter chips: All | Active | Trial | Expired | Pending Approval
- Search by contract #, customer name, phone
- Columns: # | Customer | Service Location | Type | Start | End | Monthly Value | Status
- Row tap → contract detail
- Top-right: **+ New Contract** button

### 11.2 New Contract Form
A multi-step form. **Each step must be valid to proceed.**

**Step 1 — Customer**
- Pick existing customer OR create new (inline form)
- Required: name, primary phone
- Optional: email and company-level contact fields

**Step 1.5 — Service Location**
- Choose the customer's active service location.
- If there is exactly one active service location, auto-select it.
- If there are multiple active service locations, require the user to choose one.
- If none exist, open inline service-location creation before proceeding.
- The selected location fills the contract contact/address/map snapshot fields.

**Step 2 — Type & Term**
- Type: Trial | Rental (radio)
- If Trial: trial_days (default from tenant settings)
- If Rental: start_date, end_date (or open-ended toggle)
- Billing day (1–28)
- Refill day (1–28)

**Step 3 — Products**
- Add device: dropdown of available units (filtered to `product_type = asset_rental`, `status in (available_new, available_used)`)
  - Optional: scan barcode to pick
- Add oil: dropdown of consumable_rental products
- Enter `qty_per_refill` for each oil (default loaded from product, editable)

**Step 4 — Pricing**
- Enter `monthly_rental_value` (single number)
- Live preview pane (requires snapshot field permissions): shows snapshot calculation
- If `user_has_permission('contracts.approve_override')` and profit < min: warning + checkbox "I confirm this is acceptable"
- If agent and profit < min: button "Request approval"

**Step 5 — Location & Signing**
- Location pin and address are pre-filled from the selected service location.
- Address/map/contact fields remain editable as a contract snapshot for this signing only.
- Customer signature (canvas) — if tenant setting requires

**Final — Review & Save**
- Summary view
- "Create contract" button → fires `create_rental_contract` RPC

### 11.3 Contract Detail
Tabs:
- **Overview** — header info, status, snapshot (requires snapshot field permissions), customer info, location
- **Lines** — list of asset/consumable lines with current oil status
- **Visits** — chronological list of refills, sales pitches, maintenance
- **Invoices** — all invoices generated for this contract
- **Vouchers** — all payments received for this contract's invoices
- **Calendar** — upcoming events for this contract
- **History** — audit log entries

---

## 12. Contract Closure

```
[Close Contract] button (requires `contracts.close`)
   │
   ▼
Dialog asks for:
  • Closure type: normal | early_termination
  • Closure date
  • Final asset state: returned_good | returned_damaged | lost
  • Optional: settle outstanding balance now? (open voucher form)
  • Closure reason

On confirm, close_contract RPC runs:
  1. Update contract.status = completed / terminated_early
  2. Update product_units.status back to available_used (or damaged / lost)
  3. Update inventory_balances (qty_rented -1, qty_available +1 / qty_damaged +1)
  4. Insert inventory_movements (rental_return)
  5. Mark all future calendar_events as 'cancelled'
  6. Insert audit_log
```

Outstanding A/R balance remains as a customer debt; it doesn't auto-clear.
