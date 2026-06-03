# PAYMENT_SYSTEM.md — Payments, Vouchers & Accounting

> Money flow, voucher management, WAC, monthly billing.
> Updated 2026-05-16 to resolve conflicts: KWD amounts are examples only. v1 has one default currency per tenant.

---

## 1. The Three Money Documents

| Document | Purpose | Affects A/R | Affects Cash |
|----------|---------|-------------|--------------|
| **Invoice** | Records a charge owed by or to a party | Yes (creates) | No |
| **Voucher** | Records actual cash movement | Yes (reduces) | Yes |
| **Journal Entry** | The accounting record behind each | (depends) | (depends) |

Every invoice and voucher generates a **journal entry**. Journal entries are double-entry: debits equal credits, always.

---

## 2. Invoices

### 2.1 Invoice Types

| Type | Direction | Effect |
|------|-----------|--------|
| `sales` | Money owed to us by customer | Dr A/R, Cr Sales Income |
| `purchase` | Money we owe to supplier | Dr Inventory, Cr A/P |
| `sales_return` | Reverse of sales | Dr Sales Income, Cr A/R |
| `purchase_return` | Reverse of purchase | Dr A/P, Cr Inventory |
| `rental_monthly` | Monthly bill for a rental contract | Dr A/R, Cr Rental Income |
| `opening_balance_customer` | Initial customer debt | Dr A/R, Cr Equity |
| `opening_balance_supplier` | Initial supplier credit | Dr Equity, Cr A/P |

### 2.2 Invoice Lifecycle

```
DRAFT  →  CONFIRMED  →  PARTIALLY_PAID  →  PAID
                  ↘
                   CANCELLED  (requires `invoices.cancel`)
```

- **Draft:** editable, not posted to journal, doesn't affect balances
- **Confirmed:** posted, immutable (except via `invoices.cancel` → cancellation)
- **Partially paid:** at least one voucher allocated but balance > 0
- **Paid:** sum of allocated vouchers ≥ total
- **Cancelled:** reversal journal entry posted

### 2.3 Rental Monthly Invoices

Generated automatically by `monthly_billing_job()`:

```sql
-- Pseudo-code
For each active rental contract with billing_day = current_day_of_month:
  Insert invoice:
    type = 'rental_monthly'
    customer_id = contract.customer_id
    contract_id = contract.id
    date = today
    due_date = today + <payment_terms_days>  -- from contract/invoice terms (removed from customer profile in M5.5)
    
  Insert single invoice_line:
    product_id = NULL (or a synthetic "rental" product)
    description = "Monthly rental — {month_name}"
    qty = 1
    unit_price = contract.monthly_rental_value
    line_total = contract.monthly_rental_value
    
  total = contract.monthly_rental_value
  
  Post journal_entry:
    Dr  A/R subaccount (customer)         monthly_rental_value
    Cr  Rental Income                     monthly_rental_value

  Generate PDF, store in invoice_pdfs bucket
  
  If tenant.auto_send_invoice_pdf:
    Queue email + WhatsApp notifications
```

### 2.4 Refill-Generated Invoices

When a refill visit completes (and the refill has a per-refill charge — usually for contracts where oil is billed separately), the visit RPC creates an invoice:

```
type = 'sales' OR 'rental_monthly' (depending on tenant config)
contract_id = visit.contract_id
visit_id = visit.id
single line: oil refill amount
```

For most Hayat Secret contracts, the monthly rental already covers oil, so refills don't generate separate invoices — the agent simply records the visit. Tenant settings control this:

```
billing_model: 
  - 'all_inclusive'  → monthly invoice covers everything (default)
  - 'separate_oil'   → refill generates its own invoice
```

### 2.5 Invoice PDF

Generated from the canonical structured JSON document template.

Phase 5 renderer:
- Flutter client-side `pdf`/`printing` renderer for desktop/mobile preview and local printing.
- Stored template body lives in `document_templates.body_json`.
- Tenant branding and defaults live in `tenant_document_settings`.

Later server renderer:
- An Edge Function may render and store archived or auto-sent PDFs.
- It must consume the same JSON template model; do not create a second HTML-only template system.

Storage path for archived PDFs: `{tenant_id}/invoices/{invoice_number}.pdf`.

The PDF includes:
- Tenant header (logo, name, address, tax ID if applicable)
- Customer info
- Invoice meta (number, date, due date)
- Itemized table
- Subtotal, discount, tax, total
- Payment terms
- Footer (bank details, thank-you message)

Both Arabic and English versions can be generated; the customer's preferred language is used by default.

---

## 3. Vouchers — Cash Movement

### 3.1 Voucher Types

| Type | Who pays whom | Cash account effect |
|------|---------------|---------------------|
| `receipt` | Customer → us | Cash account debits (money in) |
| `payment` | We → supplier / employee / other | Cash account credits (money out) |

### 3.2 Receipt Voucher

When a customer pays:

```
voucher:
  type = 'receipt'
  customer_id = X
  amount = 50.000
  payment_method = 'knet'
  reference_no = 'KNT-998877'
  account_id = customer X's A/R subaccount
  cash_account_id = "Cash on Hand" or "Bank — KNET" account
  collected_by = current user
  
voucher_invoice_allocations:
  voucher_id, invoice_id 1, 25.000
  voucher_id, invoice_id 2, 25.000

journal_entry:
  Dr  Cash on Hand (or Bank)           50.000
  Cr  A/R subaccount (customer X)      50.000

After:
  invoice 1: paid_amount += 25.000, status updated
  invoice 2: paid_amount += 25.000, status updated
```

### 3.3 Allocation Modes

When a customer pays an amount that could cover multiple invoices:

**Auto-FIFO (default):**
The system allocates from oldest invoice to newest until the voucher amount is exhausted. Partial allocation on the last invoice if needed.

**Manual:**
The user picks which invoices to allocate to and how much per invoice.

**Unallocated:**
If the customer pays more than all open invoices total, the excess sits as a credit on the customer's account. It will auto-apply to future invoices unless the user manually allocates it.

### 3.4 Payment Voucher

When we pay a supplier, employee, or expense:

```
voucher:
  type = 'payment'
  supplier_id = X  (or employee_id, or NULL for direct expense)
  amount = 100.000
  payment_method = 'bank_transfer'
  account_id = supplier X's A/P subaccount (or expense account)
  cash_account_id = "Bank — Main"

journal_entry:
  Dr  A/P subaccount (supplier X)    100.000   (or expense account)
  Cr  Bank — Main                    100.000
```

### 3.5 Voucher PDF (Receipt)

Same JSON template engine as invoice PDF. Path for archived PDFs: `{tenant_id}/vouchers/{voucher_number}.pdf`.

Auto-sent to customer via WhatsApp + email when configured. Field agents can trigger send manually if they don't want auto-send.

Auto-send depends on the later server renderer. Local preview/print in Phase 5 uses the Flutter renderer.

---

## 4. Customer Payments — The Three Patterns

### 4.1 Pattern A: Pay at Refill
The agent is there, collects cash/KNET, issues receipt voucher on the spot via mobile.
- Visit RPC creates invoice + voucher + allocation atomically
- Customer receives receipt PDF via WhatsApp before agent leaves

### 4.2 Pattern B: Pay Later
Refill happens, no payment collected. Invoice is created with `status = confirmed`, no voucher. Days/weeks later, customer pays — a user with `vouchers.create_receipt` creates a receipt voucher allocated to one or more open invoices.

### 4.3 Pattern C: Pay in Advance
Customer wants to prepay 3 months. Accountant creates a receipt voucher with `amount = 37.500`. Either:
- Allocates to current open invoice (12.500) and leaves 25.000 unallocated as credit
- Or generates next 2 monthly invoices early and allocates fully

Unallocated credit is shown on customer detail as: "Credit balance: KWD 25.000."

---

## 5. Weighted Average Cost (WAC)

Each product has `avg_cost`. This is the cost basis for:
- Profit calculations
- Inventory valuation
- Contract snapshots at creation time

### 5.1 WAC Formula

```
On each purchase:
  new_qty = current_qty + purchased_qty
  new_avg_cost = (current_qty × old_avg_cost + purchased_qty × purchase_unit_cost) / new_qty
```

### 5.2 Per-Tenant Per-Product WAC

The WAC is per-tenant per-product (a global product wouldn't share WAC across tenants).

For serialized assets (devices), each `product_unit` records its own `purchase_cost`. The product's WAC is the average across all units. But for accuracy in contract snapshots, the system uses the **specific unit's purchase_cost** when an asset_rental contract is created, not the product-level average.

For consumables (oils), there are no per-unit records — only the product-level WAC matters.

### 5.3 When WAC Recalculates

- After every confirmed `purchase` invoice
- After every confirmed `purchase_return`
- Manual recalc available in admin tools (rare)

WAC does **not** recalculate on sales, refills, or other outbound movements — outbound uses the current WAC as the cost basis.

### 5.4 Edge Case: First Purchase
If `current_qty = 0`, `new_avg_cost = purchase_unit_cost`.

### 5.5 Edge Case: Negative Inventory
Negative balances should be impossible (the system rejects movements that would go negative), but if somehow they happen, WAC freezes until balance returns positive.

---

## 6. Journal Entries — Always Balanced

Every entry has multiple lines. The sum of `debit` must equal the sum of `credit`. Postgres enforces this via a trigger:

```sql
create function check_journal_balanced() returns trigger as $$
begin
  if (select sum(debit) - sum(credit)
      from journal_lines
      where journal_entry_id = NEW.journal_entry_id) != 0 then
    raise exception 'Journal entry % not balanced', NEW.journal_entry_id;
  end if;
  return NEW;
end;
$$ language plpgsql;

create constraint trigger journal_balance_check
  after insert or update on journal_lines
  deferrable initially deferred
  for each row execute function check_journal_balanced();
```

The `deferrable initially deferred` allows multiple lines to be inserted within one transaction; the check runs at COMMIT.

---

## 7. Chart of Accounts — Default Template

When a tenant is created, the system seeds a default CoA:

```
1000 ASSETS
  1100 Current Assets
    1101 Cash on Hand
    1102 Bank — Main
    1103 Bank — KNET Settlement
    1110 Accounts Receivable                    ← parent for customer subs
    1120 Inventory — Available
    1121 Inventory — Rented Assets
    1122 Inventory — Trial Assets
    1123 Inventory — Maintenance
    1130 Prepaid Expenses
  1200 Fixed Assets
    1201 Furniture & Equipment
    1202 Vehicles

2000 LIABILITIES
  2100 Current Liabilities
    2110 Accounts Payable                       ← parent for supplier subs
    2120 Salaries Payable
    2130 Other Accrued Expenses

3000 EQUITY
  3100 Owner's Capital
  3200 Owner's Drawings
  3300 Retained Earnings

4000 INCOME
  4100 Sales Income
  4200 Rental Income
  4300 Other Income

5000 EXPENSES
  5100 Cost of Goods Sold
  5101 Cost of Oil Consumed
  5200 Salaries & Wages
  5210 Commissions
  5300 Rent
  5400 Utilities
  5500 Fuel & Vehicle
  5600 Depreciation — Rental Assets
  5700 Repairs & Maintenance
  5800 Marketing
  5900 Other Expenses
```

Tenant can customize: add accounts, deactivate unused ones, rename. System accounts (`is_system = true`) cannot be deleted — they're referenced by automated entries.

---

## 8. Sample Journal Entries

### 8.1 Sales Invoice (Cash)
```
Customer buys a perfume for 25.000, pays cash on the spot.
This is actually two entries (invoice + receipt voucher).

INVOICE journal:
  Dr  A/R — Customer X          25.000
  Cr  Sales Income              25.000

VOUCHER journal:
  Dr  Cash on Hand              25.000
  Cr  A/R — Customer X          25.000

Result: Cash up 25, A/R nets to 0, Sales Income up 25.
```

### 8.2 Purchase Invoice
```
We buy 100 liters of Hilton oil at 10 KWD/liter = 1000 KWD.

INVOICE journal:
  Dr  Inventory — Available     1000.000
  Cr  A/P — Supplier Y          1000.000

Inventory balance: +100 L of Hilton in main warehouse
WAC recalculated for Hilton
```

### 8.3 Refill Visit (Cost Recognition)
When a refill happens, cost-of-goods-sold needs to be recognized:
```
Agent refills 500 ml of Hilton (WAC = 0.010/ml = 5.000 cost)

JOURNAL:
  Dr  Cost of Oil Consumed      5.000
  Cr  Inventory — Available     5.000

Inventory balance: -500 ml from van warehouse
```

This is run automatically by `record_refill_visit`.

### 8.4 Monthly Rental Invoice
```
Cafe Bloom's monthly rental of 12.500 generated.

JOURNAL:
  Dr  A/R — Cafe Bloom          12.500
  Cr  Rental Income             12.500
```

### 8.5 Contract Creation (Asset Movement)
```
New contract; device with cost 60.000 reserved for customer.

The device stays in our books; only its physical location/state changes.

JOURNAL:
  Dr  Inventory — Rented Assets  60.000
  Cr  Inventory — Available      60.000

(Both are asset accounts; the device hasn't been sold.)
```

Optionally, monthly depreciation can be recognized:
```
Each month, while contract is active:
  Dr  Depreciation — Rental Assets    2.500
  Cr  Accumulated Depreciation        2.500
```

This is optional for v1 — many small businesses don't bother. Tenant setting `track_rental_depreciation = false` skips it.

---

## 9. Debt Aging Report

Generated on demand by `aged_receivables(tenant_id)` function.

```
For each customer with open invoices:
  Compute, per invoice, days_overdue = today - due_date
  Bucket: 0-30, 31-60, 61-90, 91+, NOT_DUE
  
Output:
  customer | balance | current | 1-30 | 31-60 | 61-90 | 91+
```

Used for collections planning. Displayed as a sortable table on desktop.

---

## 10. Reports — The Money Reports

### 10.1 Profit & Loss

```
For period [start, end]:
  Income:
    Rental Income       sum(credits to 4200)
    Sales Income        sum(credits to 4100)
    Other Income        sum(credits to 4300)
  
  Expenses:
    Cost of Goods Sold  sum(debits to 5100, 5101)
    Salaries            sum(debits to 5200, 5210)
    Operating           sum(debits to 5300-5900)
    Depreciation        sum(debits to 5600)
  
  Net Profit = Income - Expenses
```

### 10.2 Contract Profitability

Per active contract, computed from snapshots:

```
monthly_revenue           = contract.monthly_rental_value
monthly_cost              = contract.snapshot_total_monthly_cost
monthly_profit            = contract.snapshot_monthly_profit

cumulative_revenue        = monthly_revenue × months_active
cumulative_cost           = monthly_cost × months_active
cumulative_profit         = monthly_profit × months_active

actual_revenue            = sum of paid amounts on this contract's invoices
overdue_balance           = sum of unpaid amounts past due
```

This uses **snapshots**, so historic profit doesn't move when current prices change.

### 10.3 Cash Flow

```
For period [start, end]:
  Cash in (receipt vouchers)
  Cash out (payment vouchers)
  Net cash movement
  Closing cash balance per cash account
```

---

## 11. Payment Methods & Cash Accounts

Each payment method maps to a cash account:

| Method | Default Cash Account |
|--------|----------------------|
| `cash` | Cash on Hand |
| `knet` | Bank — KNET Settlement |
| `bank_transfer` | Bank — Main |
| `cheque` | Cheques Received (or Bank — Main when cleared) |
| `other` | Configurable |

Tenant can configure mappings in settings.

---

## 12. Closing the Books

Phase 4 feature, not in v1. When implemented:
- Monthly close: locks the period; no edits to prior months without Manager/approver override
- Year-end close: zeros out income/expense, posts net to retained earnings

For v1, the books are always "open" — corrections can be made any time. The audit log records every change.
