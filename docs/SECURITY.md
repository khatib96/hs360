# SECURITY.md — Security, RBAC & Multi-Tenant Isolation

> Security is not a phase. It's built in from line one of SQL.
> Updated 2026-07-22: access control remains Manager/User + explicit
> permissions. Employee job/work profile and adaptive mobile presentation are
> never authorization roles; record correction is lifecycle-specific.

---

## 1. Threat Model

The system must protect against:

| Threat | Mitigation |
|--------|------------|
| Tenant A reads Tenant B's data | RLS on every business table |
| A user without cost permission sees product costs | RLS policies + `security_invoker` safe views + frontend permission gates |
| A user without edit permission changes prices | RLS + `user_has_permission()` checks |
| Photo from gallery uploaded as "live" | Native camera-only API; EXIF time validation |
| Replay of a refill (re-submitting old visit) | Idempotent RPCs keyed on `client_id` |
| SQL injection | Parameterized queries only (Supabase client does this) |
| Stolen JWT used after firing | Token TTL + revocation; agent re-login required for sensitive actions |
| Photo tampering after upload | Storage write-once policy; audit trail |
| Voucher amount changed after issuance | Vouchers immutable after creation; corrections via reversal entries |

---

## 2. Authentication

### 2.1 Supabase Auth
- Email + password login
- Optional: phone OTP for field agents (often simpler than passwords)
- A future tenant-scoped employee-code login experience may resolve a linked
  account alias, but it must still authenticate securely to Supabase Auth and
  must never use the employee code itself as authority or a password.
- JWT issued on login, includes `user_id` and (via custom hook) `tenant_id`
- Token TTL: 1 hour for access, 30 days for refresh
- Refresh token rotates on each use

### 2.2 Custom JWT Hook
A Supabase Auth hook function enriches the JWT with the user's tenant and account type:

```sql
create or replace function auth_jwt_hook(event jsonb)
returns jsonb language plpgsql as $$
declare
  claims jsonb;
  user_tenant uuid;
  v_account_type user_account_type;
begin
  claims := event->'claims';
  
  select tenant_id, account_type into user_tenant, v_account_type
  from tenant_users
  where user_id = (event->>'user_id')::uuid and is_active = true
  limit 1;
  
  if user_tenant is not null then
    claims := jsonb_set(claims, '{tenant_id}', to_jsonb(user_tenant));
    claims := jsonb_set(claims, '{account_type}', to_jsonb(v_account_type));
  end if;
  
  event := jsonb_set(event, '{claims}', claims);
  return event;
end $$;
```

### 2.3 First-Run / Onboarding
- First Manager is created when tenant is provisioned
- Manager invites other users via email (Supabase magic link or invite token)
- Each invite specifies only `account_type`: `manager` or `user`
- Users start with zero permissions. The Manager grants explicit permissions from the catalog.

### 2.4 Password Policy
- Minimum 10 characters
- At least 1 number, 1 letter
- Common-password blocklist (Supabase default + custom)
- No expiry (modern best practice)
- 2FA optional in v1, mandatory for Manager accounts in Phase 2

---

## 3. Multi-Tenant Isolation — RLS Policies

Every business table has Row Level Security enabled.

### 3.1 The Pattern

For every table `T`:

```sql
alter table T enable row level security;

-- Read: only rows of your tenant
create policy "T_select_own_tenant" on T
  for select using (tenant_id = current_tenant_id());

-- Write: only into your tenant, permission-restricted
create policy "T_insert_own_tenant" on T
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('module.create')
  );

-- Update: only your tenant's rows, permission-restricted
create policy "T_update_own_tenant" on T
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('module.edit')
  );

-- Delete: explicit sensitive permission
create policy "T_delete_with_permission" on T
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('module.delete')
  );
```

The generic delete example is not valid for immutable or referenced business
history. Each table must explicitly choose one of: no delete, safe unused-draft
discard, soft deactivation, lifecycle cancellation, or service-role tenant
erasure. Confirmed financial records never expose client hard delete.

### 3.2 Permission Matrix

| Table | Read | Insert | Update | Delete |
|-------|------|--------|--------|--------|
| `tenants` | own | service-role only | service-role only | service-role only |
| `tenant_users` | `settings.users.view` | `settings.users.invite` | `settings.users.edit` | `settings.users.deactivate` |
| `tenant_settings` | `settings.company.view` | none (init only) | `settings.company.edit` | `settings.company.delete` |
| `employees` | `hr.employees.view` with protected-field shaping | `hr.employees.create` | `hr.employees.edit` | deactivate when referenced |
| `commission_rules` | `hr.commissions.view` | `hr.commissions.create` | `hr.commissions.edit` | `hr.commissions.delete` |
| `salaries` | `hr.salaries.view`; employee self-view via scoped RPC | `hr.salaries.create` | `hr.salaries.edit` | `hr.salaries.delete` |
| `advances` | `hr.advances.view`; employee self-view via scoped RPC | `hr.advances.create` | `hr.advances.edit` | `hr.advances.delete` |
| `warehouses` | `warehouses.view` | `warehouses.create` | `warehouses.edit` | deactivate when safely allowed |
| `chart_of_accounts` | `chart_of_accounts.view` | `chart_of_accounts.create` | `chart_of_accounts.edit` | `chart_of_accounts.delete` (system rows blocked) |
| `product_groups` | `product_groups.view` | `product_groups.create` | `product_groups.edit` | deactivate when referenced |
| `products` | `products.view` | `products.create` | `products.edit` | deactivate when referenced |
| `products.cost_columns` | field permissions such as `products.field.avg_cost` | field permission required | field permission required | n/a |
| `product_units` | `product_units.view` | controlled RPCs | controlled lifecycle RPCs | retire/lifecycle action; no history erasure |
| `maintenance_records` | `maintenance.view` | `maintenance.create` | `maintenance.edit` | `maintenance.delete` |
| `inventory_balances` | `inventory.view` | system functions only | system functions only | n/a |
| `inventory_movements` | `inventory_movements.view` | system functions only | n/a (immutable) | never through the app |
| `customers` | `customers.view` | `customers.create` | `customers.edit` | deactivate when referenced |
| `customer_service_locations` | `customers.view` | `customers.edit` | `customers.edit` | `customers.edit` (deactivate only) |
| `suppliers` | `suppliers.view` | `suppliers.create` | `suppliers.edit` | deactivate when referenced |
| `contracts` | `contracts.view` | `contracts.create` | `contracts.edit` | unused-draft discard only; active/used rows use lifecycle RPCs |
| `contract_lines` | `contracts.view` | `contracts.create` | `contracts.edit` | n/a |
| `contract_oil_changes` | `contracts.view` | `contracts.oil_change` | `contracts.oil_change` | `contracts.oil_change.delete` |
| `visits` | `visits.view` or `visits.view_assigned` | `visits.create` / separately permitted unplanned visit | `visits.edit` or `visits.edit_assigned` | audited cancel; execution evidence is never erased |
| `invoices` | `invoices.view` | system functions or `invoices.create` | `invoices.edit` | `invoices.cancel` |
| `invoice_lines` | `invoices.view` | system functions or `invoices.create` | `invoices.edit` | n/a |
| `vouchers` | `vouchers.view` | `vouchers.create_receipt` or `vouchers.create_payment` | `vouchers.edit` | `vouchers.cancel` |
| `voucher_invoice_allocations` | `vouchers.view` | system | n/a | `vouchers.cancel` |
| `journal_entries` | `journal.view` | system functions only | n/a | n/a |
| `journal_lines` | `journal.view` | system functions only | n/a | n/a |
| `quotations` | `quotations.view` | `quotations.create` | `quotations.edit` | `quotations.delete` |
| `calendar_events` | M4 RPCs only (`get_calendar_range_summary`, `list_calendar_events`); direct `SELECT` revoked for `authenticated`/`anon` | `calendar.create` | `calendar.edit` | audited cancel/lifecycle RPC; no hard delete for accepted workflows |
| `notifications` | own row (`recipient_user_id = auth.uid()`) or `notifications.view` | system functions or `notifications.create` | n/a | `notifications.delete` |
| `audit_log` | `audit_log.view` through a permission-shaped/redacted RPC | trigger only | n/a | never |

Phase 8 Requests & Approvals tables must be RPC-first for lifecycle decisions.
Self-service users may read their own safe request projection; team/all review,
protected attachments, decision, and application each require explicit
permissions. Approval application rechecks tenant, request version/status,
current target state, and idempotency inside one transaction.

Calendar reminder delivery is additionally fail-closed: it waits for the
tenant's reconcile cursor to finish, refreshes the event occurrence, and
revalidates the current assignment, active employee/user mapping, tenant
membership, and `calendar.view_assigned` visibility immediately before the
system notification insert.

The Phase 7.5 notification center may list and mark read only the current
recipient's in-app notifications. Source labels and deep-links are returned
only after rechecking current source visibility; stale or unauthorized targets
fail closed. Global search uses capped permission-shaped source RPCs/views and
must not return protected fields, hidden category counts, or raw cross-module
errors.

**Phase 7 M4 (`097`):** `calendar_events` is RPC-only for API roles.
`get_calendar_range_summary` and `list_calendar_events` enforce
`calendar.view` vs `calendar.view_assigned` server-side via
`assert_calendar_event_view`. `list_contract_upcoming_events_json` is internal
only (EXECUTE revoked from `authenticated`/`anon`); contract detail still
receives upcoming rows through `build_contract_detail_json`.

### 3.3 Cost Column Protection

Users without sensitive field permissions must not see `products.avg_cost`, `products.last_purchase_cost`, contract snapshots, etc.

**Two-layer defense:**

**1. Database level (`security_invoker` safe views):**

```sql
-- Restricted products view. It runs with the caller's privileges and
-- still honors RLS on the underlying products table.
create or replace view products_safe
with (security_invoker = true) as
  select
    id, tenant_id, sku, barcode, name_ar, name_en, description_ar, description_en,
    group_id, product_type, unit_primary, unit_secondary, conversion_factor,
    sale_price,
    rental_price_monthly,
    -- NOTE: avg_cost, last_purchase_cost, min_sale_price, min_rental_price omitted
    expected_lifespan_months,
    default_oil_ml_per_month,
    is_serialized, trackable_for_maintenance,
    reorder_point, is_active, image_url,
    created_at
  from products;

create or replace view contracts_safe
with (security_invoker = true) as
  select
    id, tenant_id, contract_number, type, status,
    customer_id, service_location_id, contact_person_name, contact_phone, contact_email,
    start_date, end_date, billing_day, refill_day,
    monthly_rental_value,
    total_contract_value,
    location_name, location_governorate, location_area,
    location_lat, location_lng, location_address, location_google_maps_url,
    signed_by_customer_at, signature_url,
    created_by_agent_id,
    closed_at, closure_reason,
    notes, created_at, updated_at
  from contracts;

-- App layer chooses the safe view unless the user has all required field permissions.
```

**2. Application level:**
Repositories check permissions before issuing the query. If a User lacks `products.field.avg_cost`, the repository queries `products_safe`. If they have all required field permissions, it queries `products`.

**3. RPC option for dynamic field shaping:**
```sql
create or replace function get_contract_detail(p_contract_id uuid)
returns jsonb as $$
declare
  v_row contracts%rowtype;
begin
  select * into v_row
  from contracts
  where id = p_contract_id
    and tenant_id = current_tenant_id();

  if not found or not user_has_permission('contracts.view') then
    raise exception 'permission_denied';
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'id', v_row.id,
    'contract_number', v_row.contract_number,
    'monthly_rental_value', v_row.monthly_rental_value,
    'snapshot_monthly_profit',
      case when user_has_permission('contracts.field.snapshot_profit')
           then v_row.snapshot_monthly_profit
           else null
      end
  ));
end;
$$ language plpgsql stable security definer;
```

### 3.4 Service Role Key

The Supabase service-role key bypasses RLS. It is **never** exposed to the client.

- Used only by:
  - Edge functions (scheduled jobs, integrations)
  - Backend admin scripts (tenant provisioning)
- Stored in Supabase Vault, not in code
- Never logged

---

## 4. Storage Bucket Policies

```sql
-- visit_photos: users with visit-photo permission insert; tenant members with visit view read
create policy "visit_photos_read" on storage.objects
  for select using (
    bucket_id = 'visit_photos'
    and (storage.foldername(name))[1] = current_tenant_id()::text
    and user_has_permission('visits.view')
  );

create policy "visit_photos_insert" on storage.objects
  for insert with check (
    bucket_id = 'visit_photos'
    and (storage.foldername(name))[1] = current_tenant_id()::text
    and user_has_permission('visits.upload_photo')
  );

-- No update / no delete on visit_photos (write-once)
```

Same pattern for `contract_pdfs`, `invoice_pdfs`, `voucher_pdfs`, `signatures`.

`product_images` is public-read, Manager or product-editor write:
```sql
create policy "product_images_public_read" on storage.objects
  for select using (bucket_id = 'product_images');

create policy "product_images_admin_write" on storage.objects
  for insert with check (
    bucket_id = 'product_images'
    and (storage.foldername(name))[1] = current_tenant_id()::text
    and user_has_permission('products.edit')
  );
```

---

## 5. Live-Photo Enforcement

The biggest fraud risk in field service is **agents uploading stock photos instead of taking real ones**. Defenses:

### 5.1 Native Camera Only
The Flutter `image_picker` package distinguishes camera vs gallery sources. The app uses **only** camera source for visit photos:

```dart
final picker = ImagePicker();
final photo = await picker.pickImage(
  source: ImageSource.camera,        // ← camera only
  imageQuality: 85,
  preferredCameraDevice: CameraDevice.rear,
);
```

There is no UI path to pick from gallery for visit photos.

### 5.2 EXIF Timestamp Check
After upload, an Edge Function reads EXIF metadata:
- If `DateTimeOriginal` is more than 1 hour different from the visit time, flag the visit
- If EXIF is missing entirely, flag the visit (some apps strip EXIF — suspicious for "live" claims)

### 5.3 GPS Stamp
Photos are also tagged with the device's reported GPS at capture time (Flutter can attach this). If GPS is wildly off, flag.

### 5.4 Storage Write-Once
The `visit_photos` bucket has no update or delete policies for normal users. A field user cannot replace a photo after upload.

### 5.5 Audit
Every flagged visit appears on the Manager's "Suspicious Visits" report.

---

## 6. Idempotency

All mutating RPCs accept a `client_id` (UUID generated on the mobile device) for de-duplication:

```sql
create or replace function record_refill_visit(
  p_client_id text,
  p_tenant_id uuid,
  p_contract_id uuid,
  ...
) returns uuid as $$
declare
  existing_id uuid;
begin
  -- Check for replay
  select id into existing_id from visits where client_id = p_client_id;
  if existing_id is not null then
    return existing_id;
  end if;
  
  -- ... normal logic ...
end $$;
```

This makes the mobile app's offline sync safe against retries.

---

## 7. Sensitive Settings — Who Can Change What

| Setting | Editable by |
|---------|-------------|
| `min_monthly_profit` | Manager only |
| `gps_accuracy_threshold_m` | `settings.field_ops.edit` |
| `auto_send_*` | `settings.notifications.edit` |
| Receipt templates | `settings.templates.edit` |
| WhatsApp credentials | Manager only |
| Email credentials | Manager only |
| User account type and permissions | Manager only |
| Chart of accounts (system rows) | none — only seed migration |
| Currency | Manager only (and only before any transactions exist) |

`settings.templates.edit` is a planned Phase 5 permission and must be added to the seed catalog before template settings are implemented.

---

## 8. Audit Log — What Gets Recorded

Triggers on these tables write to `audit_log`:

| Table | Actions logged |
|-------|----------------|
| `customers` | insert, update, deactivate/account link |
| `customer_service_locations` | insert, update, deactivate, set primary |
| `contracts` | insert, update, delete |
| `contract_lines` | insert, update, delete |
| `invoices` | insert, update (limited), cancellation |
| `vouchers` | insert, cancellation |
| `journal_entries` | insert, posting |
| `product_units` | status changes |
| `tenant_users` | account type changes, permission changes, deactivation |
| `tenant_settings` | all updates |
| `products` | price changes, cost recalcs |
| `employees` / employee documents | create, protected-field update, user link, deactivate, document lifecycle |
| `employee_requests` / decisions | submit, review, approve, reject, cancel, apply |

Audit log entries are immutable. There is no UPDATE or DELETE policy on `audit_log`.
The Phase 7.5 audit-review RPC must redact protected before/after fields when the
viewer lacks the corresponding source permission; `audit_log.view` does not
automatically grant all sensitive business fields.

---

## 9. Required Reasons

Some actions require a `reason` field as part of the request:

- Min-profit override on contract → reason required
- Opening stock, inventory stock-in/out, and stock count → controlled reason
  required; stock-out loss/damage/expiry must resolve to an allowed account
- Sales/purchase return → reason required
- Cancel an invoice → reason required
- Cancel a voucher → reason required
- Manual journal entry → description required
- Discrepancy in van reconciliation → reason required
- Visit marked with location_mismatch → reason required when manually proceeding
- Unplanned visit → purpose/reason required
- Visit reschedule or delegation request → reason required
- Employee leave/advance/letter request → reason required
- Request rejection, sensitive approval/override, or cancellation → decision
  reason required according to request policy
- Confirmed-document cancel/reversal or referenced-master deactivation → reason
  required

The frontend enforces presence; the backend rejects empty values.

---

## 10. Logging & Monitoring

### 10.1 Client-Side
- App logs locally (debug builds only)
- Production builds send errors to Sentry
- No PII in error reports (no customer names, phones, etc.)
- Stack traces only

### 10.2 Server-Side
- Supabase logs all auth events
- Edge Functions log to Supabase Logs
- Failed RLS checks logged with `actor_id`, `target_table`, `query_hash`
- Daily digest emailed to tenant owner: failed logins, suspicious visits, RLS violations

---

## 11. Backups

- Supabase automated daily backups (Pro tier)
- Weekly off-site snapshot to a cloud storage bucket (Wasabi or similar)
- Point-in-time recovery available (Pro tier feature)
- Tenant can request a data export (JSON dump of their tenant) — admin tool

---

## 12. Data Retention & Deletion

### 12.1 Soft Delete by Default
Customers, suppliers, customer service locations, products, product groups,
employees, warehouses, and used contracts are never hard-deleted through normal
UI. Use deactivation or the accepted lifecycle instead. Immutable inventory,
finance, visit evidence, request decisions, and audit history are never erased.

### 12.2 Tenant Deletion
Per request, an admin tool can:
1. Export all tenant data to JSON
2. Delete all rows where `tenant_id = X` (cascade)
3. Delete storage objects under `{tenant_id}/`
4. Mark tenant row as `deleted_at = now()` (but keep for audit history)

Implemented via a service-role script, not via UI.

### 12.3 GDPR-ish Customer Data
A customer can request their data:
- Tool exports all their personal info + transaction history
- Tool can anonymize: replace name with `Customer-{hash}`, blank out phone/email

---

## 13. Security Checklist Before Production

- [ ] All tables have `tenant_id` and RLS enabled
- [ ] RLS policies tested with Manager, zero-permission User, and representative permission sets
- [ ] Service-role key not in any client code
- [ ] Storage bucket policies set
- [ ] EXIF check Edge Function deployed
- [ ] 2FA enabled for owner accounts
- [ ] Backup verified by test-restore
- [ ] Sentry capturing client errors
- [ ] Auth rate limits configured
- [ ] Password policy enforced
- [ ] CORS configured (Supabase project settings)
- [ ] All Edge Functions use service-role only when necessary
- [ ] Penetration test by a third party (Phase 4)
