# RPC_SPEC.md — Required Stored Function Contracts

> Updated 2026-06-15 for Phase 5 finance contracts.
> The detailed Phase 5 contracts in
> `PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md` supersede older positional
> invoice signatures in this file.

---

## Common Rules

- Existing operational/offline RPCs may accept `p_client_id text`.
- Phase 5 financial RPCs accept `p_idempotency_key uuid` plus canonical payload
  hashing. Re-sending the same key and payload returns the existing result;
  reusing it with a different payload raises `idempotency_payload_mismatch`.
- RPCs derive tenant from `current_tenant_id()`, not from a client-supplied tenant id.
- RPCs call `user_has_permission()` before doing work.
- RPCs raise stable application errors, not raw internal messages.

Standard errors:

| Code | Meaning |
|------|---------|
| `permission_denied` | User lacks required permission |
| `tenant_not_found` | No active tenant for `auth.uid()` |
| `duplicate_client_id` | Same client id points to a different operation |
| `idempotency_payload_mismatch` | Finance idempotency key was reused with a different canonical payload |
| `validation_failed` | Required input is missing or invalid |
| `insufficient_stock` | Inventory would go negative |
| `below_min_profit` | Contract profit is below tenant threshold |
| `journal_unbalanced` | Debit and credit totals differ |

---

## Phase 6 Contract RPCs

> Phase 6 update: the older positional `create_rental_contract(...)` signature
> is superseded by `docs/PHASE_6_CONTRACTS_PLAN.md`. Contracts now include trial
> periods, rental contracts, multiple rental assets, multiple rental
> consumables, conversion, return/extension, configurable pricing basis, and
> idempotent mutation style aligned with Phase 5 finance.

Creates trial/rental contracts, lines, snapshots, asset movement, conversion,
closure, billing, and schedule handoff through RPC-controlled operations.

```sql
preview_contract_profit(p_data jsonb) returns jsonb
create_trial_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
create_rental_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
convert_trial_to_rental(p_data jsonb, p_idempotency_key uuid) returns uuid
extend_trial_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
return_trial_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
close_contract(p_data jsonb, p_idempotency_key uuid) returns uuid
schedule_contract_consumable_change(p_data jsonb, p_idempotency_key uuid) returns uuid
sync_tenant_contract_calendar_events(p_horizon_days int default null) returns jsonb
generate_rental_invoice(p_data jsonb, p_idempotency_key uuid) returns uuid
get_contract_detail(p_contract_id uuid) returns jsonb  -- includes upcoming_schedule (M12)
```

**M12 calendar handoff (internal — not callable by authenticated):**

```sql
sync_contract_calendar_events_internal(p_contract_id uuid, p_horizon_days int default null) returns jsonb
list_contract_upcoming_events_json(p_contract_id uuid, p_limit int default 10) returns jsonb
```

- `sync_tenant_contract_calendar_events` requires `calendar.edit`; default horizon
  30 days, max 180.
- Internal sync runs from lifecycle RPCs, contract status trigger, and postgres
  maintenance only.
- **M2 (`095`):** `sync_contract_calendar_events_internal` is a thin wrapper over
  `sync_contract_calendar_events_entry_internal` (timezone gate + deferred
  reconcile + `_core_internal`). Entry/core, refill chain, consumable
  materialization, and batch helpers are revoked from API roles.
- A done refill without a trusted execution fact is a hard chain stop. Failure
  handlers pass their caught `SQLSTATE` into the internal sanitizer; they do
  not attempt to read exception state from a nested function.
- `schedule_contract_consumable_change` calls `apply_consumable_change_to_calendar`
  instead of a full contract resync.
- Generated rows use `source_kind = contract_generated` with stable `source_key`
  (billing keyed by coverage month `YYYY-MM-01`).
- `get_contract_detail.upcoming_schedule` returns up to 10 pending generated
  events with whitelisted metadata only (no cost fields).

**Phase 7 M1 calendar settings RPCs (`093`):**

```sql
get_calendar_settings() returns jsonb
update_calendar_settings(p_data jsonb) returns jsonb
list_calendar_timezones(p_search text default null) returns table (timezone_name text)
```

- `get_calendar_settings` requires `settings.calendar.view` (or manager).
- `update_calendar_settings` requires `settings.calendar.edit` (or manager).
- `list_calendar_timezones` requires `settings.calendar.view` (or manager).
- Client cannot set `working_schedule_configured`; server sets it on first valid
  atomic save. `configured_at` / `configured_by` are set only on the first
  `false → true` transition.
- Direct INSERT/UPDATE/DELETE on `tenant_calendar_settings` and
  `tenant_working_days` are revoked from API roles.

**`get_calendar_settings` / `update_calendar_settings` response shape:**

```json
{
  "timezone_name": "Asia/Kuwait",
  "timezone_confirmed": true,
  "legacy_timezone_suggestion": "Asia/Kuwait",
  "working_schedule_configured": true,
  "remind_event_workday_start": true,
  "remind_previous_workday_start": true,
  "can_edit": true,
  "days": [
    {
      "iso_weekday": 1,
      "day_mode": "working_hours",
      "work_start": "08:00",
      "work_end": "17:00"
    }
  ]
}
```

**`update_calendar_settings` payload:**

```json
{
  "timezone_name": "Asia/Kuwait",
  "remind_event_workday_start": true,
  "remind_previous_workday_start": true,
  "days": [
    {
      "iso_weekday": 1,
      "day_mode": "working_hours",
      "work_start": "08:00",
      "work_end": "17:00"
    }
  ]
}
```

Day modes: `day_off`, `working_hours`, `24_hours`. Exactly seven distinct
`iso_weekday` values (1–7) required. `work_start` / `work_end` required only for
`working_hours`, validated as `HH:MM` with hour `00–23` and minute `00–59`
via `parse_calendar_work_time()` (invalid values return `validation_failed`).

**Internal (revoked from API roles):**

```sql
resolve_tenant_working_window(p_tenant_id uuid, p_date date) returns jsonb
derive_calendar_event_overdue(p_event_id uuid) returns jsonb
tenant_local_today(p_tenant_id uuid) returns date
calendar_timezone_ready(p_tenant_id uuid) returns boolean
try_tenant_local_today(p_tenant_id uuid) returns date
sync_contract_calendar_events_entry_internal(p_contract_id uuid, p_horizon_days int default null) returns jsonb
sync_contract_calendar_events_core_internal(p_contract_id uuid, p_horizon_days int default null) returns jsonb
apply_consumable_change_to_calendar(p_oil_change_id uuid) returns jsonb
reconcile_deferred_calendar_lifecycle_ops(p_tenant_id uuid, p_contract_id uuid default null) returns void
run_scheduled_calendar_generation(p_horizon_days int default null) returns jsonb  -- GRANT postgres only
run_scheduled_calendar_reminders(p_batch_size int default 100) returns jsonb  -- GRANT postgres only
local_work_start_to_utc(p_timezone text, p_local_date date, p_local_time time) returns record  -- internal, API-revoked
find_previous_working_day(p_tenant_id uuid, p_date date) returns date  -- internal, API-revoked
refresh_calendar_event_reminder_plans(p_event_id uuid) returns void  -- internal, API-revoked
reconcile_tenant_calendar_reminder_plans(p_tenant_id uuid, p_batch_size int default 500) returns void  -- internal, API-revoked
sanitize_sql_error_code(p_sqlstate text) returns text  -- internal, API-revoked
```

**Phase 7 M3 notification read model:** calendar reminder notifications are
recipient-scoped at the database layer. Users always see their own in-app rows;
managers with `notifications.view` may additionally read tenant notifications.
No new client-facing reminder RPCs in M3 — delivery is scheduler-driven.
`run_scheduled_calendar_reminders` does not promote or claim plans for a tenant
whose reconcile queue generation/cursor is incomplete. Its JSON result and
`calendar_reminder_runs` ledger distinguish `plans_retried`, terminal
`plans_failed`, `tenants_reconciled`, and isolated `tenants_failed`; any retry or
isolated tenant failure makes the run `partial`.

**Phase 7 M3 internal helpers (API-revoked):**

```sql
user_has_permission_for_tenant_user(p_tenant_id uuid, p_user_id uuid, p_permission_id text) returns boolean
user_has_calendar_event_visibility(p_event_id uuid, p_user_id uuid) returns boolean
bump_reminder_reconcile_generation(p_tenant_id uuid) returns void
deliver_calendar_reminder_plan_locked(p_plan_id uuid) returns void
record_reminder_delivery_failure(p_plan_id uuid, p_sqlstate text, p_message text) returns void
```

`deliver_calendar_reminder_plan_locked` refreshes the logical occurrence before
delivery and rechecks the current scheduled date, assigned employee, active user
mapping, tenant membership, and calendar-event visibility. It leaves the plan
pending while that tenant has an unfinished reconcile generation.

**Phase 7 M4 calendar read RPCs (`097`):**

```sql
get_calendar_range_summary(p_date_from date, p_date_to date, p_filters jsonb default '{}') returns jsonb
list_calendar_events(
  p_date_from date,
  p_date_to date,
  p_filters jsonb default '{}',
  p_cursor_in_range text default null,
  p_cursor_overdue text default null,
  p_limit int default null,
  p_include_overdue_outside_range boolean default false
) returns jsonb
```

- Both RPCs require `calendar.view` (tenant-wide) or `calendar.view_assigned`
  (assigned rows only). `settings.calendar.view` does **not** grant calendar
  event reads.
- Maximum inclusive range: **62 days**. Default page size **50**, max **100**.
- Overdue derivation uses `tenant_local_today(tenant_id)` only. When the tenant
  working schedule is unconfigured, `tenant_local_today` is null,
  `is_overdue=false`, `overdue_state='schedule_unconfigured'`, and summary
  `overdue_outside_range.state='schedule_unconfigured'`.
- `p_include_overdue_outside_range` defaults to **false** for `list_calendar_events`.
  Summary always returns `overdue_outside_range` with a `state` field.
- Assigned scope: `unassigned_count` is JSON `null` in dense `days[]`; tenant-wide
  scope returns integer counts.
- Display labels (customer, product, agent names) are always returned;
  `available_actions.can_view_*` gates navigation only.
- Rows never expose `source_key` or raw `source_metadata`; calendar-safe
  `operational_metadata` may include `action_kind` and `coverage_month_key`.
- `schedule_state` vocabulary: `working_day`, `non_working_day`,
  `schedule_unconfigured`, `day_off_overridden`.
- Ordering: `in_range` =
  `scheduled_date, type_rank, id ASC`; overdue bucket =
  `original_due_date, scheduled_date, type_rank, id ASC`.
- Cursors are base64 JSON (`version=1`) binding `tenant_id`, `scope`,
  `employee_id`, `date_from`, `date_to`, `bucket`, `filters_hash`, and `last`
  keys (`scheduled_date` + `type_rank` + `id`; overdue adds `original_due_date`).
  `filters_hash = encode(sha256(canonical_filters_json::text), 'hex')`.
- Filter validation rejects unknown keys, empty arrays, `overdue_only` with
  non-pending statuses, and `unassigned_only` with `assigned_agent_id`. Assigned
  scope rejects foreign `assigned_agent_id` and `unassigned_only`.
- Search requires at least two characters (case-insensitive substring match on
  titles, customer/contract/location/agent names).

**`get_calendar_range_summary` response:** `date_from`, `date_to`,
`timezone_name`, `working_schedule_configured`, `tenant_local_today`, `scope`,
`filters_hash`, dense `days[]` (one object per date with `event_count`,
`unassigned_count`, `overdue_count`, `working_day`), `overdue_outside_range`
(`state`, `count`, `oldest_original_due_date`), `filters_applied`.

**`list_calendar_events` response:** `in_range` and `overdue_outside_range`
objects each with `rows`, `next_cursor`, `has_more`. Row objects include titles,
schedule/overdue fields, linked display names, an `execution_summary` key
(explicit JSON `null` without a refill fact; otherwise actual completion,
delivered/contracted quantities, coverage, and next-due facts), and
`available_actions`.

**Internal / revoked from API roles (`097`):**

```sql
calendar_read_scoped_events(...) returns setof ...
assert_calendar_event_view() returns calendar_read_scope_context
parse_calendar_read_filters(jsonb, text, uuid) returns calendar_read_filter_bundle
calendar_read_filters_hash(calendar_read_filter_bundle) returns text
decode_calendar_list_cursor(text) returns jsonb
validate_calendar_list_cursor_binding(...) returns void
encode_calendar_list_cursor(jsonb) returns text
```

**ACL hardening (`097`):** `REVOKE SELECT` on `calendar_events` from
`authenticated` and `anon`. Calendar reads must use the M4 RPCs.
`list_contract_upcoming_events_json` remains internal (EXECUTE revoked from API
roles); hardened to use `tenant_local_today` and return `[]` when unconfigured.
Contract detail still embeds upcoming schedule via `build_contract_detail_json`.

**Phase 7 M0 supersession (remaining planned work):**

- Phase 7 calendar event read/reschedule RPCs are date-only and do not accept a
  fabricated event time.
- M4 read RPCs (`097`) return derived overdue state, dense day summaries, and
  dual-bucket pagination; direct `calendar_events` SELECT is revoked from API roles.
- M2 must correct refill generation to one outstanding due event per cadence
  chain.
- Only trusted Phase 8 execution may write `calendar_refill_execution_facts`.
- Execution-fact integrity requires the completed visit to match the linked
  event's customer and service location. Phase 8 calculates the proposed next
  due date from `actual_completion_date` plus confirmed coverage, never from
  the original planned due date.
- Manual next-date override requires a dedicated permission, reason, and audit.

Contract creation payload shape:

```json
{
  "customer_id": "uuid",
  "service_location_id": "uuid",
  "type": "trial|rental",
  "start_date": "2026-07-05",
  "end_date": "2027-07-04",
  "billing_day": 5,
  "refill_day": 5,
  "monthly_rental_value": "20.000",
  "asset_lines": [
    {"product_id": "uuid", "product_unit_id": "uuid"}
  ],
  "consumable_lines": [
    {
      "product_id": "uuid",
      "qty_per_refill": "500.000",
      "refill_frequency_months": 1
    }
  ],
  "override_reason": "Required only for authorized below-min-profit override"
}
```

Requires:

- `contracts.create`
- `contracts.convert_trial` for trial conversion
- `contracts.extend_trial` for trial extension
- `contracts.return_trial` for trial return
- `contracts.close` for rental closure
- `contracts.approve_override` if profit is below threshold and override is requested

Rules:

- `p_service_location_id` must belong to `p_customer_id` in the current tenant.
- The RPC copies service-location address/contact/map fields into the contract snapshot fields.
- Serialized rental assets require concrete `product_unit_id`.
- A contract may include multiple rental assets and multiple rental consumables.
- Rental asset and rental consumable cost basis comes from tenant contract settings and is snapshotted.
- Trial contracts do not create customer invoices by default.
- Receipt vouchers are created only when payment is actually confirmed.

Returns: `contracts.id`

Errors:

- `permission_denied`
- `validation_failed`
- `insufficient_stock`
- `below_min_profit`

---

## Inventory Financial Documents

Phase 5 M4.5 (migrations `065`–`070`) replaces non-financial manual adjustments with:

```sql
record_opening_stock(p_data jsonb, p_idempotency_key uuid) returns uuid
record_inventory_document(p_data jsonb, p_idempotency_key uuid) returns uuid
record_stock_count(p_data jsonb, p_idempotency_key uuid) returns uuid
cancel_inventory_document(
  p_document_id uuid,
  p_reason text,
  p_idempotency_key uuid
) returns uuid
list_inventory_documents(
  p_filters jsonb default '{}'::jsonb,
  p_cursor text default null,
  p_limit int default 50
) returns setof record
get_inventory_document_detail(p_document_id uuid) returns jsonb
list_inventory_adjustment_reasons(
  p_document_type text default null
) returns setof record
```

`record_inventory_document` accepts `document_type: stock_in | stock_out` in
`p_data` only. There are no separate public stock-in/stock-out RPCs.

These RPCs atomically create the source document, movements, balances,
serialized-unit changes, WAC/value snapshots, and balanced journal. Warehouse
transfers remain non-financial.

**Permissions:** `inventory_documents.create_opening`,
`inventory_documents.create_adjustment`, `inventory_documents.create_stock_count`,
`inventory_documents.cancel`, `inventory_documents.view`.

**Payload rules:**

- Client-supplied `counter_account_id` / `account_id` on lines → `validation_failed`.
- Stock-in requires `unit_cost` unless the reason allows WAC fallback (`found_surplus`).
- Stock-out rejects client `unit_cost`; values at locked WAC.
- Stock count uses warehouse `qty_available`; WAC uses all owned buckets.
- All-zero stock count → document and movements only; no `journal_entries` row.

**Legacy wrapper:** `record_inventory_adjustment(...)` remains single-line,
non-serialized, returns `movement_id` (not document id). It calls the internal
posting engine directly so Phase 3 `inventory_movements.create` permission still
applies.

**Cancellation:** safe reversal only; blocked cases return
`correction_document_required`. Reversal journal source is
`inventory_document_reversal` (not a reason row). Idempotent cancel replay returns
the same document id when key and payload match a prior successful cancel.
Serialized documents reject cancel in M4.5 (`correction_document_required`).

**Errors:** `permission_denied`, `validation_failed`, `insufficient_stock`,
`journal_unbalanced`, `correction_document_required`, `books_locked`.

---

## `record_purchase_invoice`

Creates a confirmed purchase invoice, inventory movement, WAC recalculation, and journal entry.

```sql
create or replace function record_purchase_invoice(
  p_data jsonb,
  p_idempotency_key uuid
) returns uuid;
```

`p_data` shape:

```json
{
  "supplier_id": "uuid",
  "date": "2026-06-15",
  "due_date": "2026-07-15",
  "warehouse_id": "uuid",
  "notes": "optional",
  "lines": [
    {
      "product_id": "uuid",
      "qty": "2.000",
      "unit_price": "10.000",
      "discount_pct": "0",
      "line_order": 1,
      "units": [
        {"serial_number": "HS-001", "barcode": "optional"},
        {"serial_number": "HS-002", "barcode": "optional"}
      ]
    }
  ]
}
```

Requires `invoices.create_purchase`. The RPC owns all internal stock/journal
writes; callers do not require direct table-write permission.

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
  p_data jsonb,
  p_idempotency_key uuid
) returns uuid;
```

Requires `invoices.create_sales`.

Returns: `invoices.id`

Errors:

- `permission_denied`
- `validation_failed`
- `insufficient_stock`
- `journal_unbalanced`

---

## Sales and Purchase Returns

Phase 5 M7.5 adds linked return documents:

```sql
record_sales_return(p_data jsonb, p_idempotency_key uuid)
record_purchase_return(p_data jsonb, p_idempotency_key uuid)
cancel_return_invoice(
  p_return_invoice_id uuid,
  p_reason text,
  p_idempotency_key uuid
)
```

Each return references the original invoice and original lines, enforces
cumulative returnable quantity, and uses frozen tax/cost snapshots. Returns are
not cancellation aliases.

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
