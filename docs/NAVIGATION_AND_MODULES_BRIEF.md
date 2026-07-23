# NAVIGATION_AND_MODULES_BRIEF — Canonical Module and Navigation Structure

> Owner-approved revision 2026-07-24 before Phase 7.5 M0.
>
> Purpose: define how existing and planned HS360 capabilities are grouped into
> user-facing modules. This brief supersedes the earlier flat/grouped menu draft
> where it conflicts and is implemented through Phase 7.5.
>
> This is an information-architecture contract. Data rules still come from
> `CANONICAL_DECISIONS.md`; permissions from `PERMISSIONS.md`; execution order
> from `BUILD_PLAN.md` and
> `PHASE_7_5_PRODUCT_STRUCTURE_AND_STABILIZATION_PLAN.md`.

---

## 1. Product Navigation Principles

1. Navigation follows business work, not database tables or implementation
   routes.
2. The sidebar contains a small set of modules, never every page and action.
3. The top global bar contains utilities; the active module owns its contextual
   horizontal sub-navigation.
4. Creation, transfer, count, adjustment, and similar operations are commands
   inside their owning module, not primary navigation entries.
5. Every module, tab, command, widget, count, and drill-down is permission-
   filtered. The server remains authoritative.
6. Grouping screens never merges distinct accounting or operational entities.
7. Deep links and detail/create routes remain valid even when they are not menu
   items.
8. Arabic and English labels are equally canonical; `Daily Activity` and
   `Journal Entries` must never share the ambiguous Arabic label `اليومية`.

---

## 2. Desktop Shell

### 2.1 Primary Sidebar

```text
لوحة التحكم                 Dashboard
ملخص اليوم                  Daily Activity
المواعيد والزيارات          Appointments & Visits
العقود                      Contracts
العملاء والموردون           Customers & Suppliers
المالية                     Finance
المخزون                     Inventory
نقطة البيع                  Point of Sale
الموارد البشرية             Human Resources

────────────────────────────────────────
السجل                       Audit Log
الإعدادات                   Settings
[الصورة/الاسم/الرقم الوظيفي/الملف/الخروج]
```

- POS and HR appear only when their phase surfaces and permissions exist.
- Audit and Settings are anchored in the lower system area.
- The user block shows avatar/initials, display name, employee code when linked,
  profile entry, and sign out.
- The sidebar supports expanded and collapsed modes; collapsed icons require
  accessible labels/tooltips.

### 2.2 Global Top Bar

The top bar contains:

- module/page title;
- breadcrumb or explicit back behavior;
- global search/command palette;
- permission-filtered quick-create menu;
- notifications;
- locale switch;
- an active warehouse/operating context only for workflows that explicitly
  support it.

It does not repeat all sidebar modules.

Phase 7.5 implements global search over customers/suppliers, contracts,
invoices, products/serialized units, and stable implemented document
identifiers. Results are grouped, capped, permission-shaped, and linked to the
canonical detail route. The notification bell is functional and shows the
signed-in user's existing in-app notifications/calendar reminders with
unread/read state and safe deep-links. Neither control may be a decorative
placeholder.

### 2.3 Contextual Module Bar

When a module has multiple surfaces, a horizontal tab/sub-navigation appears
below the title. It may scroll or collapse into a menu on narrow widths. Tabs
the user cannot access are omitted, not disabled as information leaks.

---

## 3. Canonical Module Tree

### 3.1 Dashboard / لوحة التحكم

Dashboard v1 uses four fixed, permission-shaped priority slots:

1. today's appointments/visits, completed and remaining where trusted;
2. overdue operational items;
3. active/trial/rental contracts and asset condition;
4. current-month collections and outstanding amount when authorized.

Inventory/data-quality warnings, approval items, trends, comparisons, health
scores, configurable placement, and owner analytics remain Phase 10 unless
separately promoted.

Every data widget drills into its filtered source records. Motivational phrases
are optional polish after alerts and trusted KPIs.

### 3.2 Daily Activity / ملخص اليوم

Daily Activity is a selected-date operational timeline of authorized events:
appointments, visit outcomes, contracts, invoices/returns, vouchers, cash/bank,
inventory documents/transfers/counts, and relevant administrative changes.

It answers `what happened on this date?`. It is not the accounting day book,
general ledger, or raw audit log.

### 3.3 Customers & Suppliers / العملاء والموردون

Contextual tabs:

- Customers;
- Suppliers.

Customer detail owns:

- profile and contacts;
- service locations;
- financial balance/account statement;
- contracts and rented/trial assets;
- invoices, vouchers, and credits;
- appointments and visits;
- communication and history when implemented.

Customers and suppliers share navigation/search patterns but retain separate
tables, permissions, and A/R versus A/P semantics.

### 3.4 Contracts / العقود

Contextual surfaces:

- all contracts;
- trials;
- rentals;
- lifecycle/due views when implemented.

Create, convert, extend, change consumable, close, terminate, or return are
permission-gated in-module actions. An active/used contract is not hard-deleted.

### 3.5 Appointments & Visits / المواعيد والزيارات

Contextual tabs:

- Calendar;
- Today Agenda;
- Visits;
- Follow-up;
- Route View / Operations Map when its phase is implemented.

The module unifies the user's operational experience but preserves the model:

- calendar event = plan, assignment, participants, and scheduled date/time;
- visit = execution, GPS/photo, quantities, collection, outcome, and evidence.

An authorized user may add an unplanned field visit with purpose/reason. The
visit may produce no sale, a follow-up, a trial contract, or a rental contract.
Created contracts link back to the visit. Performance/commission credit requires
accepted execution, not appointment creation.

### 3.6 Inventory / المخزون

Contextual tabs:

- Overview / Balances;
- Products and Product Groups;
- Warehouses;
- Inventory Documents;
- Movements;
- Transfers;
- Stock Count / Reconciliation;
- later maintenance/unit history links where appropriate.

Rules:

- Product is an item definition; Warehouse is a place; Balance connects them.
- Movements remain immutable history.
- Financial stock operations use controlled inventory documents.
- Transfers remain non-financial at total-company GL level.
- `Add product`, `Add warehouse`, `Transfer`, `Count`, and `Correct` are commands
  inside Inventory.

### 3.7 Finance / المالية

Contextual tabs:

- Finance Overview;
- Invoices: Sales, Purchases, Rental, Sales Returns, Purchase Returns;
- Vouchers: Receipt and Payment;
- Cash & Bank;
- Chart of Accounts;
- Journal Entries / `القيود اليومية`;
- General Ledger / `دفتر الأستاذ`;
- Reports: account statements, accounting day book, trial balance, P&L,
  balance sheet, cash flow, budgets/budget-versus-actual, debt aging, and
  reconciliations;
- Fiscal Period and Year-End Close.

The current Phase 5 engines remain the posting truth. Navigation consolidation
does not introduce direct journal editing or hard deletion. Phase 10 completes
the missing ledger/report/close surfaces.

### 3.8 Point of Sale / نقطة البيع

Phase 9 module:

- sale/cart;
- barcode scan;
- payment;
- receipt/refund according to accepted accounting policy;
- register/daily close.

POS consumes the same product, inventory, invoice, voucher, tax, permission,
and audit foundations; it is not a second accounting engine.

### 3.9 Human Resources / الموارد البشرية

Contextual tabs:

- Employees;
- Requests;
- Approval Inbox;
- Salaries;
- Advances;
- Commissions;
- Employee Documents.

Employee records include tenant-scoped employee code, contact/personal data,
employment dates, work profile, passport/residency and sponsorship status,
employment/temporary-assignment documents, alerts, and active state according
to the Phase 9 accepted data model.

Employee, tenant user, permissions, and work profile remain distinct. A work
profile changes the default desktop/mobile presentation only and grants no
access.

### 3.10 Audit Log / السجل

The basic surface filters by actor, date, module/entity, action, and reason and
links to the source record. Before/after values are presented safely according
to permissions. Audit rows are immutable. Phase 10 adds advanced review,
anomaly, override, cancellation, and permission-change dashboards.

### 3.11 Settings / الإعدادات

Contextual sections:

- Company and localization;
- Users, employee links, permissions, and profile;
- Finance, tax, accounts, fiscal defaults;
- Document templates and branding;
- Calendar working schedule, timezone, reminders, and exceptions;
- Field operations, GPS, visit, and risk settings;
- notification channels/templates when implemented.

Settings permissions are per sub-area. A generic Settings entry must not grant
visibility to every settings page.

---

## 4. Adaptive Mobile Navigation

The mobile shell is derived from work profile for ordering/defaults and from
explicit permissions for visibility/access.

### Field or Hybrid Default

```text
Today | Appointments & Visits | Requests | permitted primary action | More
```

`More` may contain Customers, Van Stock, Contracts, Invoices/Collections,
profile, settings, and sign out according to permission.

### Administrative Default

```text
Home/Alerts | Approvals | Calendar | permitted business module | More
```

The shell must handle mixed permissions without creating hardcoded security
roles. Server checks and RLS remain authoritative offline and online.

---

## 5. Requests and Approval Placement

Requests use one audited lifecycle:

```text
draft -> submitted -> under_review -> approved | rejected | cancelled
```

Initial families:

- leave;
- advance;
- visit reschedule;
- one-time or standing delegation;
- official letter/certificate;
- contract/price exception where accepted;
- van-stock refill/transfer.

The mobile Requests tab serves the employee. HR/operations modules and an
Approval Inbox serve authorized decision makers. Approval authority comes from
permissions and request policy, never only from job type.

---

## 6. Record Actions in Navigation and UI

- Unposted draft: edit/discard according to its policy.
- Confirmed financial document: cancel/reverse with permission and reason;
  never hard-delete.
- Return: linked return/credit document, not cancellation.
- Posted journal: immutable.
- Active/used contract: lifecycle action, not delete.
- Referenced master record: deactivate rather than erase history.
- Every sensitive action: consequence preview, specific rejection reason, and
  immutable audit.

The presence of a button never replaces server validation.

---

## 7. Route and Implementation Rules

1. Preserve existing deep-link paths unless a separately accepted migration is
   needed; module grouping does not require database changes.
2. Use typed module/sub-navigation definitions, not ad-hoc lists repeated by
   screen.
3. All labels come from ARB localization files.
4. Every detail/create/edit/operation route has a clear back/breadcrumb target.
5. Keep unsaved-change protection and shared command patterns.
6. Do not render empty module tabs that have neither an implemented surface nor
   an accepted placeholder need.
7. Keep widgets/counts permission-shaped; a hidden module cannot leak its count
   through Dashboard, search, notifications, or Daily Activity.
8. Desktop, narrow desktop/tablet, and mobile fallback must share module
   semantics even when their chrome differs.

---

## 8. Capability Placement

| Capability | Placement |
|---|---|
| Module shell, shared UI foundation, bounded global search, quick create, in-app notification center, Dashboard v1, Daily Activity, record-action UX, basic Audit | Phase 7.5 |
| Employee link/work profile minimum, adaptive mobile, generic requests foundation, field visits/offline | Phase 8 |
| POS, maintenance, full employee file, HR requests, payroll, advances, commissions | Phase 9 |
| General Ledger UI, accounting day book, trial balance, P&L, balance sheet, close, advanced dashboards/audit/map | Phase 10 |
| External email/WhatsApp delivery | Phase 11 |

No completed phase is renumbered. Future work is subdivided rather than hidden
inside an unrelated milestone.
