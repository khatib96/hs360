# PERMISSIONS.md — Custom Permission System

> **No roles. No templates. Pure custom permissions per user.**
> Two account types: Manager (full access, no checks) and User (every permission grant is explicit).
> Updated 2026-05-16 to resolve conflicts: field-level hiding uses `security_invoker` safe views or permission-shaped RPCs, not RLS policies on views.

---

## 1. The Model — Explicit by Design

### 1.1 Two Account Types

| Type | Description |
|------|-------------|
| **Manager** | Full access to everything in their tenant. No permission checks run. |
| **User** | **Zero permissions by default.** Every single permission must be explicitly granted. |

A new User created without any granted permissions can log in but sees only an empty home screen. The Manager must explicitly enable each module, action, and field they want the User to access.

### 1.2 Why No Roles or Templates

Roles cause maintenance pain over time:
- Roles drift from reality (one person often handles multiple job functions)
- Editing a role affects everyone assigned to it (dangerous)
- Different people in the same "role" actually need different access
- Migration headaches when business rules change

**Explicit permissions per user** means:
- You see exactly what each person can do, with no hidden inheritance
- Changes to one user never affect another
- Onboarding is more work upfront, but maintenance is simpler forever
- New permissions added later don't auto-apply to anyone

### 1.3 The Trade-off
Setting up a new User takes 5–10 minutes (clicking checkboxes for each capability). This is intentional. The Manager thinks deliberately about what each person should access.

---

## 2. Permission Granularity — Three Levels

```
Module           → "contracts" (an entire section of the app)
   └── Action    → "create" / "view" / "edit" / "delete" / "export" / "approve"
       └── Field → "monthly_rental_value" / "snapshot_total_cost"
```

### 2.1 Module Level
If a User has no permissions in the "contracts" module, the entire Contracts tab is hidden from their navigation.

### 2.2 Action Level
Within a module, fine-grained control:
- `view` — see list and detail pages
- `view_list` — see the list but not full details (rare; separate if needed)
- `create` — create new records
- `edit` — modify existing records
- `delete` — soft-delete records
- `export` — download PDFs / Excel
- `approve` — approve overrides (min-profit, etc.)
- `send` — send notifications/messages

Not every module has every action. The catalog defines what exists.

### 2.3 Field Level
For sensitive fields, individual fields can be hidden even when the User can view the record.

Example: User can view a contract, but `snapshot_total_monthly_cost` and `snapshot_monthly_profit` columns are not returned in the API response and not rendered in the UI.

---

## 3. The Permission Catalog

Every possible permission is pre-defined in the `permissions` table. Managers cannot invent new permissions — they pick from this catalog.

### 3.1 Catalog Structure

```sql
create table permissions (
  id text primary key,                       -- e.g. 'contracts.create'
  module text not null,                      -- e.g. 'contracts'
  action text not null,                      -- e.g. 'create'
  scope text not null default 'action',      -- 'action' | 'field'
  field_name text,                           -- populated when scope='field'
  label_ar text not null,
  label_en text not null,
  description_ar text,
  description_en text,
  is_sensitive boolean default false,        -- triggers UI warning
  category text not null,                    -- for UI grouping
  sort_order int default 0
);
```

### 3.2 Sample Catalog Rows

```sql
-- Module-action permissions
insert into permissions values
  ('dashboard.view',        'dashboard', 'view',   'action', null, 'عرض اللوحة الرئيسية', 'View dashboard', null, null, false, 'core', 1),

  ('customers.view',        'customers', 'view',   'action', null, 'عرض الزبائن', 'View customers', null, null, false, 'sales', 10),
  ('customers.create',      'customers', 'create', 'action', null, 'إضافة زبون', 'Create customers', null, null, false, 'sales', 11),
  ('customers.edit',        'customers', 'edit',   'action', null, 'تعديل زبون', 'Edit customers', null, null, false, 'sales', 12),
  ('customers.delete',      'customers', 'delete', 'action', null, 'حذف زبون', 'Delete customers', null, null, false, 'sales', 13),
  ('customers.view_ledger', 'customers', 'view',   'action', null, 'عرض دفتر حسابات الزبون', 'View customer ledger', null, null, true, 'sales', 14),
  ('customers.export',      'customers', 'export', 'action', null, 'تصدير بيانات الزبائن', 'Export customer data', null, null, false, 'sales', 15),

  ('products.view',                 'products', 'view',   'action', null, 'عرض المنتجات', 'View products', null, null, false, 'inventory', 20),
  ('products.create',               'products', 'create', 'action', null, 'إضافة منتج', 'Create products', null, null, false, 'inventory', 21),
  ('products.edit',                 'products', 'edit',   'action', null, 'تعديل منتج', 'Edit products', null, null, false, 'inventory', 22),
  ('products.delete',               'products', 'delete', 'action', null, 'حذف منتج', 'Delete products', null, null, false, 'inventory', 23),

  -- Field-level permissions on products
  ('products.field.avg_cost',           'products', 'view', 'field', 'avg_cost',           'عرض متوسط التكلفة', 'View average cost', null, null, true, 'inventory', 24),
  ('products.field.last_purchase_cost', 'products', 'view', 'field', 'last_purchase_cost', 'عرض آخر سعر شراء', 'View last purchase cost', null, null, true, 'inventory', 25),
  ('products.field.min_sale_price',     'products', 'view', 'field', 'min_sale_price',     'عرض الحد الأدنى للبيع', 'View min sale price', null, null, true, 'inventory', 26),
  ('products.field.min_rental_price',   'products', 'view', 'field', 'min_rental_price',   'عرض الحد الأدنى للإيجار', 'View min rental price', null, null, true, 'inventory', 27),

  -- Contracts
  ('contracts.view',           'contracts', 'view',    'action', null, 'عرض العقود',        'View contracts',          null, null, false, 'sales', 30),
  ('contracts.create',         'contracts', 'create',  'action', null, 'إنشاء عقد',         'Create contracts',        null, null, false, 'sales', 31),
  ('contracts.edit',           'contracts', 'edit',    'action', null, 'تعديل عقد',         'Edit contracts',          null, null, false, 'sales', 32),
  ('contracts.delete',         'contracts', 'delete',  'action', null, 'حذف عقد',           'Delete contracts',        null, null, true,  'sales', 33),
  ('contracts.close',          'contracts', 'close',   'action', null, 'إغلاق عقد',         'Close contracts',         null, null, false, 'sales', 34),
  ('contracts.approve_override', 'contracts','approve','action', null, 'الموافقة على تجاوز الحد الأدنى', 'Approve min-profit overrides', null, null, true, 'sales', 35),

  -- Field-level on contracts (cost snapshots)
  ('contracts.field.snapshot_device_cost', 'contracts','view','field','snapshot_device_monthly_cost', 'عرض تكلفة الجهاز في العقد', 'View device cost snapshot', null, null, true, 'sales', 36),
  ('contracts.field.snapshot_oil_cost',    'contracts','view','field','snapshot_oil_monthly_cost',    'عرض تكلفة الزيت في العقد',  'View oil cost snapshot',    null, null, true, 'sales', 37),
  ('contracts.field.snapshot_profit',      'contracts','view','field','snapshot_monthly_profit',     'عرض الربح المتوقع',          'View expected profit',       null, null, true, 'sales', 38),

  -- Invoices, vouchers, etc. — same pattern...
  -- (full catalog has ~150 permissions across all modules)
;
```

### 3.3 Modules Covered

The full catalog includes permissions for:

- `dashboard`
- `customers`, `customers.ledger`, `customer_service_locations` (read via `customers.view`, mutate via `customers.edit` unless dedicated permissions are introduced)
- `suppliers`
- `products`, `product_units`, `product_groups`
- `inventory`, `warehouses`, `inventory_movements`
- `contracts`, `contract_lines`, `contract_oil_changes`
- `visits` (field operations)
- `invoices` (with sub-types: sales, purchase, rental, returns)
- `vouchers` (receipt, payment)
- `quotations`
- `journal` (manual entries)
- `chart_of_accounts`
- `maintenance`
- `pos`
- `hr` (employees, salaries, advances, commissions)
- `reports` (each report is its own permission)
- `calendar`
- `messaging` (whatsapp, email)
- `settings` (company, users, currencies, templates, etc.)

Each module has its own set of actions and (where relevant) field-level permissions.

---

## 4. Granting Permissions to a User

### 4.1 Database

```sql
create table user_permissions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  tenant_user_id uuid not null references tenant_users(id) on delete cascade,
  permission_id text not null references permissions(id),
  granted_at timestamptz default now(),
  granted_by uuid references auth.users(id),
  unique(tenant_user_id, permission_id)
);

create index idx_userperms_user on user_permissions(tenant_user_id);
create index idx_userperms_perm on user_permissions(permission_id);
```

To grant a permission: insert a row. To revoke: delete the row. Simple.

### 4.2 Tenant Users (Updated)

```sql
create type user_account_type as enum ('manager', 'user');

create table tenant_users (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  account_type user_account_type not null default 'user',
  display_name text,
  is_active boolean default true,
  invited_by uuid references auth.users(id),
  joined_at timestamptz default now(),
  unique(tenant_id, user_id)
);
```

No role column. No template_id. Just an account_type flag.

---

## 5. The Permission Check Function

```sql
create or replace function user_has_permission(p_permission_id text)
returns boolean as $$
declare
  v_is_manager boolean;
begin
  -- Managers bypass all checks
  select account_type = 'manager' into v_is_manager
  from tenant_users
  where user_id = auth.uid() and is_active = true
  limit 1;
  
  if v_is_manager then
    return true;
  end if;
  
  -- For Users, the permission must be explicitly granted
  return exists (
    select 1
    from user_permissions up
    join tenant_users tu on tu.id = up.tenant_user_id
    where tu.user_id = auth.uid()
      and tu.is_active = true
      and up.permission_id = p_permission_id
  );
end $$ language plpgsql stable security definer;
```

Cached per session — Postgres reuses the result across queries in the same connection.

---

## 6. RLS Policies Use This Function

Every business table has RLS policies that call `user_has_permission()`:

```sql
-- contracts table
create policy "contracts_select" on contracts
  for select using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.view')
  );

create policy "contracts_insert" on contracts
  for insert with check (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.create')
  );

create policy "contracts_update" on contracts
  for update using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.edit')
  );

create policy "contracts_delete" on contracts
  for delete using (
    tenant_id = current_tenant_id()
    and user_has_permission('contracts.delete')
  );
```

Same pattern across every business table.

---

## 7. Field-Level Hiding via Views

For field permissions, the data layer presents safe views per table. RLS stays on the base table; the view uses `security_invoker = true` so the caller's permissions and base-table RLS still apply.

```sql
-- Restricted view: omits sensitive cost columns
create or replace view contracts_safe
with (security_invoker = true) as
  select
    id, tenant_id, contract_number, type, status,
    customer_id, service_location_id, contact_person_name, contact_phone, contact_email,
    start_date, end_date, trial_days, trial_end_date, trial_outcome,
    billing_day, refill_day,
    monthly_rental_value,
    total_contract_value,
    -- snapshot_* columns OMITTED
    location_name, location_governorate, location_area,
    location_lat, location_lng, location_address, location_google_maps_url,
    signed_by_customer_at, signature_url,
    created_by_agent_id,
    closed_at, closure_reason,
    notes, created_at, updated_at
  from contracts;
```

Users with sensitive field permissions may query the base table or a full view. Users without those permissions query `contracts_safe`.

For dynamic detail screens, an RPC can return JSON shaped by permission checks:

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

### 7.1 App Layer Picks the Right View

```dart
class ContractRepository {
  Future<List<Contract>> fetchAll() async {
    final canSeeSnapshots = ref.read(permissionServiceProvider).hasAll([
      'contracts.field.snapshot_device_cost',
      'contracts.field.snapshot_oil_cost',
      'contracts.field.snapshot_profit',
    ]);
    
    final source = canSeeSnapshots ? 'contracts' : 'contracts_safe';
    final rows = await supabase.from(source).select();
    return rows.map(Contract.fromJson).toList();
  }
}
```

If the User lacks even one field permission, they get `contracts_safe` (snapshot fields are absent from the response).

### 7.2 UI Conditionally Renders

```dart
if (ref.watch(permissionServiceProvider).has('contracts.field.snapshot_profit'))
  ListTile(
    title: Text(loc.expectedMonthlyProfit),
    trailing: MoneyDisplay(contract.snapshotMonthlyProfit!),
  ),
```

If the field is hidden, the row is not rendered at all (not even greyed out — pure absence).

---

## 8. The Permission Editor UI

This is the most important admin screen. Managers spend real time here.

### 8.1 User List (Manager view)

```
┌──────────────────────────────────────────────────────┐
│  Settings → Users                                    │
├──────────────────────────────────────────────────────┤
│  [+ Invite New User]                                 │
│                                                      │
│  Name         Email          Type      Permissions   │
│  ────────────────────────────────────────────────    │
│  Mohammad     moh@...        Manager   All (∞)       │
│  Ahmad        ahmad@...      User      24 granted    │
│  Sara         sara@...       User      12 granted    │
│  Khalid       khalid@...     User      0 granted ⚠   │
│                                                      │
│  Tap a user → manage permissions                     │
└──────────────────────────────────────────────────────┘
```

Khalid with 0 permissions is flagged — he can log in but sees nothing useful.

### 8.2 Permission Editor (Per User)

```
┌──────────────────────────────────────────────────────────┐
│  Permissions for: Ahmad (ahmad@example.com)              │
├──────────────────────────────────────────────────────────┤
│  Account type: User                                      │
│  Granted: 24 of 152 permissions                          │
│                                                          │
│  [Search permissions...]   [Filter: ☑ Sensitive only]    │
│                                                          │
│  Quick: [Grant all in section] [Revoke all in section]   │
│                                                          │
│  ▼ Dashboard                                             │
│    [✓] View dashboard                                    │
│                                                          │
│  ▼ Customers                                             │
│    [✓] View customers                                    │
│    [✓] Create customer                                   │
│    [ ] Edit customer                                     │
│    [ ] Delete customer                                   │
│    [✓] View customer ledger ⚠                            │
│    [ ] Export customer data                              │
│                                                          │
│  ▼ Products                                              │
│    [✓] View products                                     │
│    [ ] Create / edit products                            │
│    [ ] View average cost ⚠                               │
│    [ ] View last purchase cost ⚠                         │
│    [ ] View min sale price ⚠                             │
│    [ ] View min rental price ⚠                           │
│                                                          │
│  ▼ Contracts                                             │
│    [✓] View contracts                                    │
│    [✓] Create contracts                                  │
│    [ ] Edit contracts                                    │
│    [ ] Delete contracts                                  │
│    [ ] Close contracts                                   │
│    [ ] Approve min-profit overrides ⚠                    │
│    [ ] View device cost snapshot ⚠                       │
│    [ ] View oil cost snapshot ⚠                          │
│    [ ] View expected profit ⚠                            │
│                                                          │
│  ▼ Invoices                                              │
│    [✓] View invoices                                     │
│    [ ] Create sales invoice                              │
│    [ ] Create purchase invoice                           │
│    [ ] Edit invoices                                     │
│    [ ] Cancel invoices                                   │
│                                                          │
│  ▼ Vouchers                                              │
│    [✓] View vouchers                                     │
│    [✓] Create receipt voucher (mobile)                   │
│    [ ] Create payment voucher                            │
│                                                          │
│  ▼ Reports                                               │
│    [ ] View P&L ⚠                                        │
│    [ ] View debt aging                                   │
│    [ ] View contract profitability ⚠                     │
│    [ ] View agent performance                            │
│                                                          │
│  ... (all modules) ...                                   │
│                                                          │
│  [Cancel]                              [Save changes]    │
└──────────────────────────────────────────────────────────┘
```

### 8.3 UX Details
- Sensitive permissions marked with ⚠ (anything financial/cost-related)
- Search box filters in real-time
- "Filter: sensitive only" lets the Manager review just the sensitive ones
- "Grant all in section" / "Revoke all in section" buttons for bulk operations within one module
- Changes are previewed: "You're about to grant 5 and revoke 3 permissions" before saving
- Save commits all changes in one atomic operation

### 8.4 Audit Trail
Every grant or revoke logs an `audit_log` entry:
```
2026-05-15 14:32 — Mohammad granted "contracts.create" to Ahmad
2026-05-15 14:32 — Mohammad revoked "products.delete" from Ahmad
```

---

## 9. Frontend Permission Service

```dart
@Riverpod(keepAlive: true)
class PermissionService extends _$PermissionService {
  Set<String> _granted = {};
  bool _isManager = false;

  @override
  Future<void> build() async {
    final response = await ref.read(supabaseClientProvider)
        .rpc('get_my_permissions');
    
    _isManager = response['is_manager'] as bool;
    _granted = Set<String>.from(response['permissions'] as List);
    
    // Cache locally for offline mobile use
    await _cacheLocally();
  }

  bool has(String permissionId) {
    return _isManager || _granted.contains(permissionId);
  }

  bool hasAny(List<String> ids) {
    return _isManager || ids.any(_granted.contains);
  }

  bool hasAll(List<String> ids) {
    return _isManager || ids.every(_granted.contains);
  }
  
  bool get isManager => _isManager;
}
```

### 9.1 RPC: get_my_permissions

```sql
create or replace function get_my_permissions()
returns json as $$
declare
  v_is_manager boolean;
  v_permissions text[];
begin
  select account_type = 'manager' into v_is_manager
  from tenant_users
  where user_id = auth.uid() and is_active = true
  limit 1;
  
  if v_is_manager then
    return json_build_object('is_manager', true, 'permissions', '[]'::json);
  end if;
  
  select array_agg(up.permission_id) into v_permissions
  from user_permissions up
  join tenant_users tu on tu.id = up.tenant_user_id
  where tu.user_id = auth.uid() and tu.is_active = true;
  
  return json_build_object(
    'is_manager', false,
    'permissions', coalesce(v_permissions, '{}'::text[])
  );
end $$ language plpgsql stable security definer;
```

### 9.2 Permission Gates in Widgets

```dart
// Wrapper widget for clean conditional rendering
class PermissionGate extends ConsumerWidget {
  final String? permission;
  final List<String>? anyOf;
  final List<String>? allOf;
  final Widget child;
  final Widget fallback;

  const PermissionGate({
    this.permission, this.anyOf, this.allOf,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(permissionServiceProvider);
    final ok = svc.maybeWhen(
      data: (_) {
        final s = ref.read(permissionServiceProvider.notifier);
        if (permission != null) return s.has(permission!);
        if (anyOf != null) return s.hasAny(anyOf!);
        if (allOf != null) return s.hasAll(allOf!);
        return false;
      },
      orElse: () => false,
    );
    return ok ? child : fallback;
  }
}

// Usage
PermissionGate(
  permission: 'contracts.create',
  child: ElevatedButton(
    onPressed: () => context.go('/contracts/new'),
    child: Text(loc.newContract),
  ),
)
```

---

## 10. Mobile Offline Permissions

The mobile app needs to enforce permissions even when offline.

```dart
// On login (online), cache permissions
await secureStorage.write(
  key: 'cached_permissions',
  value: jsonEncode({
    'is_manager': isManager,
    'permissions': permissions.toList(),
    'cached_at': DateTime.now().toIso8601String(),
    'expires_at': DateTime.now().add(Duration(hours: 24)).toIso8601String(),
  }),
);

// If offline, load from cache
final cached = await secureStorage.read(key: 'cached_permissions');
if (cached != null) {
  final data = jsonDecode(cached);
  if (DateTime.parse(data['expires_at']).isAfter(DateTime.now())) {
    _isManager = data['is_manager'];
    _granted = Set<String>.from(data['permissions']);
  } else {
    // Expired — force re-login when back online
    throw PermissionsExpiredException();
  }
}
```

Server is always the final authority — even if the cached permissions say "you can do X", the RLS check on the server will block the request if it disagrees.

---

## 11. Edge Cases & Safety

### 11.1 Last Manager Protection
The system prevents demoting the **last active Manager** of a tenant:
```sql
-- Trigger before update on tenant_users
create function prevent_last_manager_demotion() returns trigger as $$
begin
  if OLD.account_type = 'manager' and NEW.account_type = 'user' then
    if (select count(*) from tenant_users
        where tenant_id = NEW.tenant_id
          and account_type = 'manager'
          and is_active = true
          and id != NEW.id) = 0 then
      raise exception 'Cannot demote the last active manager';
    end if;
  end if;
  return NEW;
end $$ language plpgsql;
```

Same for disabling the last Manager.

### 11.2 Self-Modification Block
Users (including Managers) cannot edit their own permissions. A Manager wanting to demote themselves must do it via another Manager.

### 11.3 Empty Permissions = Empty UI
A User with zero granted permissions sees:
- Login works
- After login: an empty home screen with a message
  > "You don't have any permissions yet. Please contact your manager."

No menus, no tabs, no data. Clean and clear.

### 11.4 Emergency Recovery
If somehow no Manager exists in a tenant, the VPS has an emergency CLI:
```bash
docker exec -it supabase-db psql -U postgres -c \
  "update tenant_users set account_type = 'manager' where user_id = '<uuid>';"
```

This is a manual server-side operation, never exposed via the app.

---

## 12. Adding New Permissions Later

When a new feature ships, new permissions are added to the catalog via migration:

```sql
-- migration: 040_add_pos_permissions.sql
insert into permissions (id, module, action, label_ar, label_en, category, sort_order)
values
  ('pos.use',         'pos', 'use',     'استخدام نقطة البيع',   'Use POS',          'sales', 100),
  ('pos.refund',      'pos', 'refund',  'استرجاع من نقطة البيع','Process refunds',  'sales', 101),
  ('pos.daily_close', 'pos', 'close',   'إقفال يومي للنقطة',     'Daily POS close',  'sales', 102);
```

These new permissions are **not granted to anyone automatically**. The Manager must explicitly grant them to relevant Users.

This is intentional: new features don't accidentally become accessible to people who shouldn't have them.

---

## 13. Cursor Implementation Notes

When building any new feature:

1. **Define the permissions first** — what actions, what fields?
2. **Add them to the catalog migration** in the same PR
3. **Write RLS policies** that check the permissions via `user_has_permission()`
4. **Create restricted views** for any sensitive field-level filtering
5. **Use `PermissionGate` widgets** to hide UI elements
6. **Test as a User with zero permissions** to make sure nothing accidentally leaks

The default mindset: **nothing is visible unless explicitly granted**.
