# Phase 7.5 - Product Structure, Navigation, and Stabilization Plan

> Status: **PLANNED / NOT STARTED** (2026-07-22).
>
> Purpose: pause feature expansion after Phase 7, turn the existing collection
> of screens into a coherent ERP product, expose existing safety workflows
> consistently, and lock the desktop/mobile information architecture before
> Phase 8 adds more field workflows.
>
> This phase does not reopen Phase 7 and does not renumber Phases 0-7. It is a
> new stabilization checkpoint between accepted Phase 7 and future Phase 8.
>
> Canonical companions: `CANONICAL_DECISIONS.md`, `MVP_SCOPE.md`,
> `NAVIGATION_AND_MODULES_BRIEF.md`, `PERMISSIONS.md`, `FIELD_OPS.md`, and
> `PHASE_5_INVOICES_VOUCHERS_JOURNAL_PLAN.md`.

---

## 1. Why This Phase Exists

The current desktop shell exposes implementation-level pages as a long flat
navigation list. That was useful while building individual features, but it no
longer reflects how a user understands the business.

Phase 7.5 fixes the product structure before Phase 8 adds visits, offline
mobile work, employee requests, and more permission-dependent surfaces.

The phase separates three kinds of work:

1. **Structure correction now** - navigation, module hubs, naming, shared
   commands, identity/profile chrome, and responsive behavior.
2. **Safety completion now** - consistent draft/edit/cancel/reverse/deactivate
   actions, basic audit review, and finance/inventory integrity checks.
3. **Planned expansion later** - full HR, payroll, POS, financial statements,
   advanced dashboards, and operations maps remain in their future phases.

---

## 2. Locked Information Architecture

### 2.1 Desktop Primary Navigation

The desktop sidebar contains business modules, not every route or action:

1. Dashboard / `لوحة التحكم`
2. Daily Activity / `ملخص اليوم`
3. Customers & Suppliers / `العملاء والموردون`
4. Contracts / `العقود`
5. Appointments & Visits / `المواعيد والزيارات`
6. Inventory / `المخزون`
7. Finance / `المالية`
8. Point of Sale / `نقطة البيع` - hidden until its phase and permission exist
9. Human Resources / `الموارد البشرية` - hidden until its surfaces exist

The lower fixed area contains:

- Audit Log / `السجل`, permission-gated;
- Settings / `الإعدادات`, permission-gated by settings sub-area;
- the signed-in user's photo/initials, display name, employee code when linked,
  profile entry, and sign-out action.

The sidebar may collapse to icons with accessible tooltips. It must not expose
standalone actions such as `Add product` or individual settings pages.

### 2.2 Global Top Bar

The global top bar is intentionally small:

- page/module title and breadcrumb/back behavior;
- global search/command palette when implemented;
- permission-filtered quick-create menu;
- notifications;
- locale switch;
- active warehouse/operating context only when a workflow explicitly supports
  that context.

It must not duplicate all sidebar modules.

### 2.3 Contextual Module Navigation

Below the global bar, the active module may expose horizontal tabs or a compact
sub-navigation. Only tabs supported by permission and implemented routes appear.

| Module | Contextual surfaces |
|---|---|
| Customers & Suppliers | Customers, Suppliers; customer detail owns locations, balance, contracts, invoices, vouchers, visits, and history |
| Contracts | Overview/list, Trials, Rentals, actions/due items where implemented |
| Appointments & Visits | Calendar, Today Agenda, Visits, Follow-up, Route/Operations Map when implemented |
| Inventory | Overview/Balances, Products, Warehouses, Inventory Documents, Movements, Transfers, Stock Count/Reconciliation |
| Finance | Overview, Invoices, Vouchers, Cash & Bank, Chart of Accounts, Journal Entries, General Ledger, Reports, Period Close |
| Human Resources | Employees, Requests, Approvals, Salaries, Advances, Commissions, Employee Documents |
| Settings | Company, Users & Permissions, Finance/Tax, Documents/Templates, Calendar, Field Operations, Localization |

Tabs organize existing concepts; they do not merge distinct entities or weaken
their permissions.

### 2.4 Naming Rules

- `Daily Activity / ملخص اليوم` is an operational cross-module activity view.
- `Journal Entries / القيود اليومية` is the accounting journal inside Finance.
- `General Ledger / دفتر الأستاذ` is account-by-account posted activity.
- Avoid using bare `اليومية` for both operational and accounting meanings.
- `Appointments & Visits` is one user-facing module, but a calendar event remains
  a plan and a visit remains execution evidence.

---

## 3. Dashboard and Daily Activity

### 3.1 Dashboard v1

Phase 7.5 replaces the placeholder dashboard with a permission-shaped,
read-only operational dashboard using existing trusted data contracts.

Initial widgets may include:

- today's appointments and completed/remaining visits;
- overdue calendar items;
- active/trial/rental contract counts;
- rented/trial asset summaries;
- current-period sales and collections only where accounting definitions are
  accepted and queryable safely;
- inventory or data-quality warnings;
- notifications and items requiring attention;
- permission-filtered quick actions.

Every KPI or chart that represents records must drill into the filtered source
list. A widget must not show totals derived from data the user cannot view.
Motivational text is optional polish and cannot displace operational alerts.

Advanced trends, owner analytics, contract-health scoring, and configurable
dashboards remain Phase 10.

### 3.2 Daily Activity

Daily Activity answers: **what happened on the selected business date?**

It is a read model/timeline that may combine authorized projections of:

- appointments and visit outcomes;
- contracts created, converted, closed, or otherwise changed;
- invoices, returns, and vouchers;
- cash/bank movements;
- confirmed inventory documents, transfers, and counts;
- audit-worthy administrative actions.

It supports date selection and links to source records. It is not the general
ledger, does not invent accounting entries, and does not expose raw audit JSON
to users lacking audit permission.

---

## 4. Module Consolidation Rules

### 4.1 Inventory

Inventory and warehouse management form one module. The following remain
separate concepts inside it:

- a Product defines an item;
- a Warehouse defines a location;
- a Balance relates a product to a warehouse;
- a Movement is immutable stock history;
- an Inventory Document is the controlled business/accounting operation;
- a Transfer moves owned stock without changing total GL inventory value;
- a Count/Reconciliation compares expected and actual stock.

`Add product`, `Add warehouse`, `Transfer`, `Stock count`, and adjustments are
in-module commands, never primary navigation items.

### 4.2 Finance

Finance groups invoices, vouchers, cash/bank, chart of accounts, journal
entries, ledgers, reports, and close without collapsing their accounting
semantics.

Phase 7.5 organizes the existing screens and adds an integrity gate. Phase 10
still owns the complete General Ledger UI, trial balance, financial statements,
inventory-to-GL reconciliation report, fiscal periods, and year-end close.

### 4.3 Customers and Suppliers

Customers and suppliers share one module shell and search experience but retain
separate records, permissions, and A/R/A/P semantics. Customer service locations
remain a customer-detail surface, not a sidebar module.

### 4.4 Appointments and Visits

Calendar and Visits share one operations module:

```text
calendar event (plan)
        -> assignment/reschedule
        -> visit execution in Phase 8
        -> GPS/photo/quantity/result/collection facts
```

An authorized employee may record an unplanned field visit with a required
purpose/reason. It may finish with no sale, a follow-up, a trial contract, or a
rental contract. Any created contract is linked to the visit. Commission or
performance credit is based on accepted completion facts, not merely creating
an appointment.

---

## 5. Record Correction, Cancellation, and Audit Policy

UI wording and available actions follow record lifecycle, permission, and
downstream effects:

| Record state/type | Allowed correction |
|---|---|
| Unposted draft | Edit; discard only through the accepted draft policy |
| Confirmed invoice/voucher/inventory document | Never hard-delete; cancel/reverse atomically with permission, reason, idempotency, and audit when safety rules allow |
| Return | Separate return/credit document linked to the original; not a cancellation alias |
| Posted journal entry | Immutable; correction through an authorized reversal/correcting source document |
| Active/used contract | No hard delete; lifecycle close/terminate/cancel/return paths only |
| Customer, supplier, product, employee, warehouse | Deactivate when referenced; hard delete only for an explicitly safe unused draft/master case |
| Audit row | Immutable and never user-deletable |

The UI must preview material effects where possible: stock restoration,
allocations/credits, cash/bank reversal, journal reversal, linked unit safety,
and period locks. If the backend rejects a correction, the user receives a
specific actionable reason.

Phase 7.5 exposes a basic filterable Audit Log surface for authorized users:
actor, timestamp, action, module/entity, reason, safe before/after summary, and
source-record link. Phase 10 owns the advanced audit-review dashboard.

---

## 6. Employee Identity, Work Profile, and Authentication Boundary

The system keeps these concepts distinct:

- **Employee** - the HR/business record;
- **Tenant user** - the application membership and Manager/User account type;
- **Permissions** - the final authority for every module/action/field;
- **Work profile** - administrative, field, or hybrid presentation preference;
- **Employee code** - a unique tenant-scoped business/login alias when linked.

Not every employee must be a user. A user linked to an employee may sign in
through a future employee-code experience, but Supabase `auth.users.id` remains
the underlying identity. Employee code must never replace secure credentials
or become an authorization role.

The work profile selects a sensible default shell. It never grants permissions.
Managers and explicitly permitted users may still open any allowed surface.

Full employee personal, passport, residency, employment, temporary-assignment,
and document records are Phase 9. Phase 8 may introduce the minimum employee
link/work-profile fields needed for mobile routing and requests.

---

## 7. Requests and Approvals Foundation

Requests are a reusable audited workflow, not unrelated form tables.

Initial request families:

- leave;
- salary advance;
- visit/date reschedule;
- one-time or standing delegation/substitution;
- official letter/certificate request;
- contract price/profit exception or other approved override;
- van-stock refill/transfer request.

Shared lifecycle:

```text
draft -> submitted -> under_review -> approved | rejected | cancelled
```

Every request stores requester/employee, tenant, type, reason, structured
payload, relevant entity links, optional attachments, current version, status,
decision actor/time/reason, and immutable history. The approver is resolved by
explicit permission and request policy, not by a hardcoded job title.

An official letter/certificate request includes the destination/recipient
organization and requested letter/certificate name in addition to the reason.

Phase 8 introduces the generic foundation plus field-critical request types.
Phase 9 completes HR request types, employee documents, and administrative
inboxes. Approval never directly mutates a financial or operational record
unless a dedicated atomic application RPC validates the approved request.

---

## 8. Adaptive Mobile Shell Direction

Phase 8 replaces the current generic drawer assumption with a permission-shaped
mobile shell.

Field/hybrid default navigation:

- Today;
- Appointments & Visits;
- Requests;
- Contracts when permitted;
- Invoices/Collections when permitted;
- More, including customers, van stock, profile, and settings as permitted.

Administrative default navigation emphasizes dashboard/alerts, approval inbox,
calendar, and permitted finance/customer views. A work profile changes ordering
and defaults only; permissions decide visibility and server access.

---

## 9. Owner Idea Placement Matrix

| Owner idea | Accepted treatment | Delivery |
|---|---|---|
| Shorter main sidebar plus upper navigation | Module sidebar + global utility bar + contextual module tabs | Phase 7.5 |
| User photo/name at sidebar bottom | User/profile system footer | Phase 7.5 |
| Interactive Dashboard, appointments, visits, rentals, trends, alerts | Trusted Dashboard v1 now; advanced trends/customization later | Phase 7.5 / 10 |
| `اليومية` showing everything on a chosen day | Named Daily Activity / `ملخص اليوم`; kept separate from accounting journal | Phase 7.5 |
| Products, warehouses, movements, transfers, balances, counts together | One Inventory module with distinct internal entities/tabs | Phase 7.5 |
| Invoices, vouchers, CoA, cash/bank, journal, ledger, reports, close together | One Finance module; existing posting engine preserved | Phase 7.5 / 10 |
| Customers as an important main area | Customers & Suppliers primary module; customer locations/history stay inside detail | Phase 7.5 |
| Visits and appointments feel like one area | One Appointments & Visits module; plan and execution remain distinct | Phase 7.5 / 8 |
| Agent records a sales visit and may create trial/rental contract | Unplanned visit workflow with reason/evidence/outcome and linked contract | Phase 8 |
| Edit/delete with permissions and full downstream effects | Draft edit/discard; confirmed cancel/reverse; master deactivate; immutable audit | Phase 7.5 |
| Complete program activity log | Basic filterable Audit now; advanced review dashboard later | Phase 7.5 / 10 |
| Employee number and rich employee file | Existing employee code becomes controlled number/login alias; full secure HR file | Phase 8 minimum / 9 full |
| Administrative versus field mobile shape | Work-profile default ordering plus explicit permission filtering | Phase 8 |
| Leave, advance, visit change, delegation, letter/certificate requests | Generic request/approval engine; field-critical first, full HR later | Phase 8 / 9 |
| Settings in one place | Settings module with permissioned company/user/finance/template/calendar/field subsections | Phase 7.5 |
| Operations Map | Remains the reusable Phase 10 map, not an expansion of Phase 7 Route View | Phase 10 |

---

## 10. Milestones

### M0 - Documentation and Scope Lock

- Update all canonical and roadmap documents.
- Reconcile old `Phase 2` labels with current Phase 8-10 placement.
- Lock Arabic/English module names and entity boundaries.
- Approve low-fidelity desktop and mobile navigation maps before code changes.

### M1 - Shell and Navigation Model

- Introduce typed module/navigation definitions.
- Implement desktop module sidebar, contextual module navigation, lower system
  area, and user identity footer.
- Keep visibility permission-derived.
- Preserve deep links and reliable back targets.

### M2 - Existing Screen Consolidation

- Move current routes under Customers, Contracts, Operations, Inventory,
  Finance, and Settings module shells without changing trusted backend behavior.
- Replace standalone create/actions in navigation with in-module commands.
- Add breadcrumbs and consistent empty/loading/error states.

### M3 - Dashboard v1 and Daily Activity

- Define bounded, permission-safe read contracts.
- Replace the placeholder dashboard.
- Add selected-date Daily Activity with source-record drill-down.
- Prove totals do not leak hidden data.

### M4 - Record Actions and Audit Surface

- Standardize draft/edit/cancel/reverse/deactivate command presentation.
- Expose already implemented safe cancellation workflows consistently.
- Add reason capture, consequence preview, and actionable rejection messages.
- Add basic filterable audit-log review.

### M5 - Finance and Inventory Integrity Gate

- Verify document-to-journal links and balanced entries.
- Verify safe cancellation/reversal effects.
- Verify inventory movements/balances and serialized-unit guards.
- Add a verification-only trial-balance/inventory-GL check if needed; the full
  reporting UI remains Phase 10.

### M6 - Responsive, Bilingual, Permission Acceptance

- Arabic/English and RTL/LTR acceptance.
- Desktop, narrow desktop/tablet, and current mobile fallback acceptance.
- Zero-permission, assigned-only, module-view, and Manager scenarios.
- Keyboard/focus/text-scale/accessibility checks.

### M7 - Phase Close and Phase 8 Handoff

- Automated tests and manual owner acceptance pass.
- No trusted Phase 5-7 semantics regress.
- Phase 8 receives the accepted navigation contract, employee/work-profile
  boundary, request foundation specification, and visit/calendar boundary.

---

## 11. Acceptance Gates

Phase 7.5 closes only when:

- the sidebar contains modules rather than a flat list of routes/actions;
- every existing production route remains reachable through its module;
- the top bar and contextual navigation do not duplicate one another;
- Dashboard and Daily Activity have distinct accepted meanings;
- Inventory and Finance group related screens without merging their entities;
- appointments and visits appear unified to users but remain plan vs execution;
- posted financial records cannot be hard-deleted from the UI;
- cancellation/reversal/deactivation actions match backend safety rules;
- audit review is permission-gated and immutable;
- user identity/profile appears in the shell;
- Arabic/English, RTL/LTR, narrow widths, and permission cases pass;
- documentation and the Phase 8 handoff are consistent.

---

## 12. Explicit Non-Goals

Phase 7.5 does not implement:

- full field visit execution or offline sync;
- full HR/payroll/employee-document management;
- all request types and approval application handlers;
- POS;
- full General Ledger/report/financial-close UI;
- advanced configurable dashboards;
- route optimization or the Phase 10 Operations Map;
- new external notification channels.

These scopes are planned now and implemented in their assigned phases.
