# RPC_SPEC.md — Required Stored Function Contracts

> Updated 2026-05-16 to resolve conflicts before Phase 0.
> Mutating RPCs are atomic, tenant-aware, permission-checked, and idempotent with `p_client_id`.

---

## Common Rules

- Every mutating RPC accepts `p_client_id text`.
- Re-sending the same `p_client_id` returns the existing result.
- RPCs derive tenant from `current_tenant_id()`, not from a client-supplied tenant id.
- RPCs call `user_has_permission()` before doing work.
- RPCs raise stable application errors, not raw internal messages.

Standard errors:

| Code | Meaning |
|------|---------|
| `permission_denied` | User lacks required permission |
| `tenant_not_found` | No active tenant for `auth.uid()` |
| `duplicate_client_id` | Same client id points to a different operation |
| `validation_failed` | Required input is missing or invalid |
| `insufficient_stock` | Inventory would go negative |
| `below_min_profit` | Contract profit is below tenant threshold |
| `journal_unbalanced` | Debit and credit totals differ |

---

## `create_rental_contract`

Creates contract, lines, snapshots, asset movement, first rental invoice, journal entry, and calendar events in one transaction.

```sql
create or replace function create_rental_contract(
  p_client_id text,
  p_customer_id uuid,
  p_service_location_id uuid,
  p_start_date date,
  p_end_date date,
  p_billing_day int,
  p_refill_day int,
  p_monthly_rental_value numeric,
  p_lines jsonb,
  p_location_lat numeric,
  p_location_lng numeric,
  p_location_address text,
  p_signature_url text,
  p_override_reason text default null
) returns uuid;
```

`p_lines` shape:

```json
[
  {"line_type":"asset","product_id":"uuid","product_unit_id":"uuid"},
  {"line_type":"consumable","product_id":"uuid","qty_per_refill":"500.000","refill_frequency_months":1}
]
```

Requires:

- `contracts.create`
- `contracts.approve_override` if profit is below threshold and override is requested

Rules:

- `p_service_location_id` must belong to `p_customer_id` in the current tenant.
- The RPC copies service-location address/contact/map fields into the contract snapshot fields.
- `p_location_*` values are optional overrides to the snapshot, not the source of truth for customer site identity.

Returns: `contracts.id`

Errors:

- `permission_denied`
- `validation_failed`
- `insufficient_stock`
- `below_min_profit`

---

## `record_purchase_invoice`

Creates a confirmed purchase invoice, inventory movement, WAC recalculation, and journal entry.

```sql
create or replace function record_purchase_invoice(
  p_client_id text,
  p_supplier_id uuid,
  p_invoice_date date,
  p_due_date date,
  p_warehouse_id uuid,
  p_lines jsonb,
  p_notes text default null
) returns uuid;
```

`p_lines` shape:

```json
[
  {"product_id":"uuid","qty":"10.000","unit":"liter","unit_cost":"10.000","product_unit_serials":["HS-001","HS-002"]}
]
```

Requires:

- `invoices.create_purchase`
- `inventory_movements.create`

Returns: `invoices.id`

Errors:

- `permission_denied`
- `validation_failed`
- `journal_unbalanced`

---

## `record_sales_invoice`

Creates a confirmed sales invoice, inventory movement, cost snapshot, and journal entry.

```sql
create or replace function record_sales_invoice(
  p_client_id text,
  p_customer_id uuid,
  p_invoice_date date,
  p_due_date date,
  p_warehouse_id uuid,
  p_lines jsonb,
  p_notes text default null
) returns uuid;
```

Requires:

- `invoices.create_sales`
- `inventory_movements.create`

Returns: `invoices.id`

Errors:

- `permission_denied`
- `validation_failed`
- `insufficient_stock`
- `journal_unbalanced`

---

## `record_refill_visit`

Completes a field refill visit. Records GPS, camera proof, inventory consumption, optional invoice, optional receipt voucher, and optional oil switch.

```sql
create or replace function record_refill_visit(
  p_client_id text,
  p_visit_id uuid,
  p_contract_id uuid,
  p_oil_product_id uuid,
  p_oil_qty numeric,
  p_photo_url text,
  p_photo_taken_at timestamptz,
  p_check_in_lat numeric,
  p_check_in_lng numeric,
  p_check_in_accuracy_m numeric,
  p_payment_amount numeric default null,
  p_payment_method text default null,
  p_payment_reference_no text default null,
  p_invoice_allocations jsonb default '[]'::jsonb,
  p_oil_switch_reason text default null,
  p_notes text default null
) returns uuid;
```

Requires:

- `visits.complete_refill`
- `vouchers.create_receipt` if payment is collected

Rules:

- The visit must carry or derive `service_location_id` from its contract.
- GPS validation compares check-in coordinates against the service location first, then the contract location snapshot if the service location has no coordinates.

Returns: `visits.id`

Errors:

- `permission_denied`
- `validation_failed`
- `insufficient_stock`

---

## `create_receipt_voucher`

Creates a receipt voucher and allocates it to invoices using FIFO or manual allocations.

```sql
create or replace function create_receipt_voucher(
  p_client_id text,
  p_customer_id uuid,
  p_date date,
  p_amount numeric,
  p_payment_method text,
  p_cash_account_id uuid,
  p_reference_no text default null,
  p_allocations jsonb default null,
  p_auto_fifo boolean default true,
  p_notes text default null
) returns uuid;
```

Requires:

- `vouchers.create_receipt`

Returns: `vouchers.id`

Errors:

- `permission_denied`
- `validation_failed`
- `journal_unbalanced`

---

## `create_payment_voucher`

Creates a payment voucher for supplier, employee, or direct expense.

```sql
create or replace function create_payment_voucher(
  p_client_id text,
  p_date date,
  p_amount numeric,
  p_payment_method text,
  p_cash_account_id uuid,
  p_account_id uuid,
  p_supplier_id uuid default null,
  p_employee_id uuid default null,
  p_reference_no text default null,
  p_notes text default null
) returns uuid;
```

Requires:

- `vouchers.create_payment`

Returns: `vouchers.id`

Errors:

- `permission_denied`
- `validation_failed`
- `journal_unbalanced`

---

## `monthly_billing_job`

Scheduled job. Generates rental invoices for active contracts due on the current tenant-local day.

```sql
create or replace function monthly_billing_job(
  p_run_date date default current_date
) returns jsonb;
```

Runs as service role from Edge Function. It must still write tenant-scoped rows and be idempotent per contract/month.

Returns:

```json
{"created": 12, "skipped": 3, "errors": []}
```
