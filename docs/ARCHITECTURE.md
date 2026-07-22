# ARCHITECTURE.md — System Architecture

> Updated 2026-05-16 to resolve conflicts: KWD and 3-decimal displays are Hayat Secret examples. Currency display precision comes from the tenant's default currency.

## 1. High-Level Topology

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT LAYER (Flutter)                    │
├──────────────────────────┬──────────────────────────────────┤
│   Desktop App            │   Mobile App                      │
│   (Windows / macOS)      │   (Android / iOS)                 │
│   - Admin                │   - Field agents only             │
│   - Accountant           │   - Offline-capable               │
│   - Warehouse            │   - Live camera, GPS              │
└──────────┬───────────────┴──────────────┬───────────────────┘
           │                              │
           │  HTTPS (REST + Realtime WS)  │
           │                              │
┌──────────▼──────────────────────────────▼───────────────────┐
│                      SUPABASE BACKEND                        │
├──────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────┐  ┌────────────┐  ┌────────┐  │
│  │ PostgreSQL  │  │ Auth     │  │ Storage    │  │ Edge   │  │
│  │ + RLS       │  │ (JWT)    │  │ (S3-like)  │  │ Funcs  │  │
│  │ + Multi-    │  │          │  │            │  │        │  │
│  │   tenant    │  │          │  │            │  │        │  │
│  └─────────────┘  └──────────┘  └────────────┘  └────────┘  │
└──────────┬───────────────────────────────────────┬──────────┘
           │                                       │
    ┌──────▼──────┐                       ┌────────▼────────┐
    │ Resend      │                       │ Meta WhatsApp   │
    │ (email)     │                       │ Cloud API       │
    └─────────────┘                       └─────────────────┘
```

---

## 2. Multi-Tenant Strategy

This system is multi-tenant from line one of SQL.

### 2.1 Approach: Shared DB + Shared Schema + `tenant_id` column

- One Supabase project, one schema
- Every business table has `tenant_id uuid not null`
- RLS policies enforce `tenant_id = current_tenant_id()` on every read/write
- A user belongs to exactly one tenant at a time (`tenant_users` table)
- JWT carries `tenant_id` claim, set on login via a custom JWT hook

### 2.2 Why not separate databases per tenant?
- Cheaper (single Supabase project)
- Easier to maintain (single migration set)
- Cross-tenant analytics possible (for the SaaS operator)
- Postgres RLS is battle-tested for this pattern

### 2.3 Adding a tenant
A simple admin script (or eventually a UI):
1. Insert into `tenants` table
2. Create owner user in `auth.users`
3. Insert into `tenant_users` with role = `owner`
4. Seed default chart of accounts for that tenant
5. Seed default settings

---

## 3. Flutter Application Structure

```
lib/
├── main.dart                       # entry point + locale init
├── app.dart                        # MaterialApp + theme + router
│
├── core/                           # cross-cutting
│   ├── config/                     # env, constants, feature flags
│   ├── theme/                      # colors, typography, RTL
│   ├── localization/               # ar.arb, en.arb
│   ├── routing/                    # GoRouter + permission-aware redirects
│   ├── network/                    # Supabase client wrapper
│   ├── errors/                     # AppException, error mapper
│   └── utils/                      # money formatting, dates
│
├── data/                           # data sources
│   ├── models/                     # Dart classes for each DB table
│   ├── repositories/               # one per entity (Supabase calls)
│   └── local/                      # Drift tables for offline cache
│
├── domain/                         # pure business logic (no Flutter)
│   ├── services/
│   │   ├── pricing_service.dart    # min-profit enforcement
│   │   ├── wac_service.dart        # weighted average cost
│   │   ├── contract_service.dart   # rental lifecycle
│   │   ├── profit_service.dart     # per-contract profitability
│   │   ├── schedule_service.dart   # refill scheduling
│   │   └── commission_service.dart
│   └── validators/
│
├── features/                       # UI by feature
│   ├── auth/
│   ├── products/
│   ├── customers/
│   ├── contracts/                  # MAJOR feature
│   ├── calendar/                   # MAJOR feature
│   ├── invoices/
│   ├── vouchers/                   # collections
│   ├── inventory/
│   ├── maintenance/
│   ├── field_ops/                  # mobile-first execution; permission-shaped
│   ├── pos/
│   ├── hr/
│   ├── reports/
│   └── settings/
│
└── shared/                         # reusable widgets
    ├── widgets/
    └── dialogs/
```

### 3.1 Layer Rules
- `features/` imports from `domain/` and `data/`, never the reverse
- `domain/` is pure Dart — no Flutter, no Supabase, no I/O
- `data/` owns all Supabase calls — features never call Supabase directly
- `core/` is imported by everyone but imports nothing from features

---

## 4. State Management — Riverpod

**Riverpod 2.x with code generation** (`@riverpod` annotations + `riverpod_generator`).

```dart
// Example: products repository
@riverpod
ProductRepository productRepository(ProductRepositoryRef ref) {
  return ProductRepository(ref.watch(supabaseClientProvider));
}

// Example: products list provider
@riverpod
class ProductsList extends _$ProductsList {
  @override
  Future<List<Product>> build() async {
    return ref.watch(productRepositoryProvider).fetchAll();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
```

---

## 5. Supabase Integration

### 5.1 Client Setup
- Single instance in `core/network/supabase_client.dart`
- Wrapped in a Riverpod provider for testability
- Anon key on client, service-role key never leaves Edge Functions
- All client requests include the user's JWT; RLS does the rest

### 5.2 Three Data Patterns

**1. Direct table queries** — simple CRUD
```dart
final products = await supabase
    .from('products')
    .select('*, product_groups(name_ar, name_en)')
    .eq('is_active', true)
    .order('name_ar');
```

**2. RPC functions** — complex atomic operations
- `create_rental_contract(...)` — contract + lines + asset reservation + first invoice + journal entry (all atomic)
- `record_purchase_invoice(...)` — invoice + WAC recalc + inventory in
- `record_sales_invoice(...)` — invoice + stock out + journal
- `record_refill_visit(...)` — inventory out + invoice or charge + optional voucher
- `close_contract(...)` — return assets + final settlement
- `monthly_billing_job(...)` — auto-generate monthly invoices

**3. Realtime subscriptions** — live dashboards
- Admin sees new contracts appear instantly
- Owner sees field visits complete in real-time
- Used sparingly — RLS-filtered

### 5.3 Storage Buckets

| Bucket | Purpose | Access |
|--------|---------|--------|
| `visit_photos` | Live refill photos | Read: `visits.view`. Write: `visits.upload_photo`. |
| `contract_pdfs` | Contract documents | Read: users with `contracts.view_documents`. |
| `invoice_pdfs` | Generated invoices | Read: tenant members. |
| `voucher_pdfs` | Receipt vouchers | Read: tenant members. |
| `product_images` | Catalog images | Public read. Write: `products.edit`. |
| `signatures` | Customer signatures | Write: agent. Read: tenant members. |

All bucket paths are namespaced: `<tenant_id>/<entity>/<filename>`.

---

## 6. Routing

GoRouter with permission-aware redirects.

```
/login
/select-tenant          # if user belongs to multiple tenants (rare)
/

# Admin / Accountant / Warehouse (desktop)
/dashboard
/daily-activity
/products
/products/:id
/customers
/customers/:id
/contracts
/contracts/new
/contracts/:id
/calendar                # major feature
/invoices
/invoices/:id
/vouchers
/vouchers/:id
/inventory
/inventory/warehouses
/inventory/movements
/inventory/transfers
/inventory/maintenance
/finance
/finance/general-ledger
/finance/reports
/pos
/reports
/reports/profit-and-loss
/reports/debt-aging
/reports/contract-profitability
/reports/agent-performance
/hr
/hr/employees
/hr/requests
/hr/approvals
/hr/salaries
/hr/commissions
/audit
/settings
/settings/company
/settings/users
/settings/min-profit
/settings/templates

# Adaptive mobile (routes still permission-gated)
/field/today
/field/calendar
/field/visits
/field/visits/new-unplanned
/field/visit/:id
/field/visit/:id/refill
/requests
/approvals
/field/new-contract
/field/customers
/field/van-stock
/field/end-of-day
/field/quotations/new
```

### 6.1 Redirect Logic
On every navigation:
1. Authenticated? Else → `/login`
2. Tenant resolved? Else → `/select-tenant` (or auto-pick if only one)
3. Current route allowed by user's permissions? Else → first permitted home route

The desktop shell groups routes into modules and contextual tabs; route paths do
not need to mirror the visible menu tree. The mobile shell uses linked employee
work profile only to choose ordering/default landing. Manager/User plus explicit
permissions remain authoritative. Dashboard, search, badges, notifications, and
Daily Activity must use permission-shaped read contracts.

---

## 7. Offline Strategy (Mobile)

Field agents must work without internet. The mobile app uses **Drift (SQLite)** as a local cache.

### 7.1 What's cached
- Today's scheduled visits + tomorrow's
- Customer details for those visits
- Active contracts for those customers (including current oil)
- Agent's current van stock
- Pending offline visits
- Product catalog (read-only)

### 7.2 Sync Flow
```
1. Agent logs in (online required at least once per day)
2. App pulls down today's visits + needed customer/contract data
3. Agent works offline if signal drops
4. Each completed visit stored locally with status=pending_sync and client_id (UUID)
5. When online, background sync:
   - Upload photo to Storage
   - Upload visit row via RPC (idempotent on client_id)
   - Mark local row as synced
6. RPC functions are idempotent — re-sending same client_id is safe
```

### 7.3 Conflict Resolution
- Server is the source of truth
- Idempotent RPCs prevent double-writes
- If a visit is rejected (e.g., contract was closed remotely), agent gets a notification
- Photos are write-once, never overwritten

---

## 8. Internationalization

- Default locale: `ar_KW`
- Secondary: `en_US`
- `intl` package + ARB files
- `Directionality` widget at app root switches with locale
- Number formatting respects locale (Arabic-Indic digits optional per tenant)
- Currency formatting via `NumberFormat.currency(locale: locale, name: tenant.currency)`

### 8.1 RTL
- Layouts use `start/end` instead of `left/right`
- Directional icons auto-flip via `Directionality.of(context)`
- Tables: column semantic order is preserved; visual mirroring is automatic

---

## 9. Money Handling — Strict Rules

**Money is never a `double`.** Anywhere. Period.

### 9.1 Dart
- Use `Decimal` from the `decimal` package
- All money model fields are `Decimal`
- Formatting via `MoneyFormatter` in `core/utils/`

### 9.2 Postgres
- All stored money columns use `numeric(15,3)` in v1 for stable arithmetic and KWD compatibility.
- Display precision comes from `currencies.decimal_places`. KWD uses 3 decimals; SAR/AED/USD usually use 2. KWD is an example, not a hardcoded UI rule.

### 9.3 Rounding
- Display: tenant currency precision from `currencies.decimal_places`
- Storage: `numeric(15,3)` in v1
- Rounding mode: `ROUND_HALF_UP`

---

## 10. Error Handling

```dart
class AppException implements Exception {
  final String code;          // 'NETWORK_ERROR', 'PERMISSION_DENIED', ...
  final String userMessageAr; // localized
  final String userMessageEn;
  final String? technicalDetail;
}

class NetworkException extends AppException { ... }
class AuthException extends AppException { ... }
class ValidationException extends AppException { ... }
class BusinessRuleException extends AppException { ... }  // min-profit, etc.
class TenantMismatchException extends AppException { ... } // RLS violation
```

### 10.1 UI Display
- Centralized `ErrorBanner` widget at top of screen
- Network errors offer retry
- Business rule violations explain the rule clearly
- Never show raw Supabase or Postgres errors to users
- All errors logged to Sentry in production

---

## 11. Audit Trail

A dedicated `audit_log` table records every sensitive change:
- Who: `actor_id`, `actor_account_type`, `tenant_id`
- What: `entity_type`, `entity_id`, `action` (insert/update/delete)
- When: `at` (timestamptz)
- Diff: `before_json`, `after_json`
- Why: optional `reason` (required for some actions, e.g., min-profit override)

Implemented via Postgres triggers on: `invoices`, `vouchers`, `contracts`, `contract_lines`, `journal_entries`, `product_units`, `inventory_movements`.

---

## 12. Deployment

See `BUILD_PLAN.md` for full details. Short version:

- **Dev:** local Supabase + Flutter on dev machine
- **Staging:** dedicated Supabase project, internal testers, real-but-fake data
- **Production:** Supabase Pro tier
- **Desktop distribution:** signed installers via GitHub Releases (Windows MSIX, macOS DMG)
- **Mobile distribution:** Google Play (internal → closed → open), App Store TestFlight

---

## 13. Folder Structure (Repo Root)

```
hayat-secret/
├── lib/                            # Flutter source
├── supabase/
│   ├── migrations/                 # SQL migrations, ordered
│   ├── functions/                  # edge functions (TS)
│   └── seed.sql                    # dev seed
├── docs/                           # the 11 .md files
├── test/                           # unit + widget tests
├── integration_test/               # e2e
├── assets/
│   ├── images/                     # logos
│   ├── fonts/                      # Arabic fonts
│   └── translations/               # arb files copy
├── .env.example
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```
