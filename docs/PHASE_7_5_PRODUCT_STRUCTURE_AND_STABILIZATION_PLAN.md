# Phase 7.5 - Product Structure, Navigation, and Stabilization Plan

> Status: **IN PROGRESS — M0, M0.5, AND M1 CLOSED / ACCEPTED; M2 NEXT**
> (started 2026-07-24).
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
>
> Supporting M0 inputs: `PRODUCT_UI_VISION.md` and
> `PROJECT_REVIEW_REPORT_2026-07-24.md`. They explain the visual direction and
> diagnosis; this file remains the execution source of truth.

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
3. Appointments & Visits / `المواعيد والزيارات`
4. Contracts / `العقود`
5. Customers & Suppliers / `العملاء والموردون`
6. Finance / `المالية`
7. Inventory / `المخزون`
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
- bounded global search/command palette;
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

Dashboard v1 has four fixed priority slots:

1. today's appointments/visits, including completed and remaining when those
   facts exist;
2. overdue operational items;
3. active/trial/rental contract and asset condition;
4. current-month collections and outstanding amount for users allowed to view
   the underlying financial records.

If a slot has no accepted trusted read contract, it shows a truthful
permission-safe unavailable/empty state rather than a fabricated KPI.
Inventory/data-quality warnings, approval items, trends, comparisons, and
configurable placement remain later enhancements.

Every KPI or chart that represents records must drill into the filtered source
list. A widget must not show totals derived from data the user cannot view.
Motivational text is optional polish and cannot displace operational alerts.

Advanced trends, owner analytics, contract-health scoring, and configurable
dashboards remain Phase 10.

### 3.2 Global Search and In-App Notifications

Phase 7.5 includes a bounded global search over:

- customers and suppliers;
- contracts;
- invoices;
- products and serialized units;
- implemented document types that have a stable number/identifier.

Search is permission-shaped on the server, returns a capped number of grouped
results, never includes protected fields merely to improve matching, and opens
the canonical detail route. Empty, loading, partial-error, keyboard-selection,
RTL/LTR, and narrow-width behavior are part of acceptance. This is navigation
search, not a universal data export or reporting engine.

The top-bar notification bell is functional in Phase 7.5. It exposes existing
in-app notifications and calendar reminders with unread/read state, unread
badge, safe deep-link, and own-notification visibility. If a notification's
source is no longer visible, the UI must fail closed without revealing its
label. Email, WhatsApp, SMS, push delivery, templates, and channel settings
remain Phase 11 unless already required by a later accepted workflow.

### 3.3 Daily Activity

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

## 10. Execution Rules

1. Milestones execute in order. A later milestone may be explored, but it does
   not close before all of its declared prerequisites.
2. Each milestone ends with automated checks, a short evidence note, and an
   explicit `CLOSED / ACCEPTED` status before the next milestone becomes active.
3. Visual work uses approved reference screens and an acceptance matrix; owner
   acceptance is required where specified and is not replaced by automated
   tests.
4. Existing Phase 5-7 business behavior is preserved. Route regrouping does not
   authorize backend rewrites.
5. Refactoring follows touched-code pressure: `app_shell.dart` must be split as
   part of the new shell; other large controllers/repositories are split only
   when the milestone changes them or tests show a concrete maintainability
   need.
6. Performance baselines are measured before and after. The old 800ms calendar
   target is an optimization target, not a Phase 7.5 closure blocker; no
   material regression from the accepted Phase 7 baseline is allowed.
7. New database behavior, if required, uses forward-only migrations with
   tenant isolation, RLS/RPC ACLs, audit, idempotency where applicable, and SQL
   regression coverage.

---

## 11. Milestone Plan

### M0 - Scope, Visual Contract, and Owner Acceptance

**Goal:** remove visual and product ambiguity before code changes.

**State:** `CLOSED / ACCEPTED` on 2026-07-24. The owner accepted Option C —
Executive Warmth and its complete expanded/collapsed, Dashboard, Inventory,
Finance, detail, field/admin mobile, and AR/EN reference set. The accepted
route/module/back-target contract, permission visibility contract, checklist,
and evidence index are under `docs/phase_7_5/m0/`.

**Work:**

- accept the three-layer navigation model and the locked sidebar order in this
  plan;
- prepare comparable low-fidelity references for:
  1. expanded desktop shell;
  2. collapsed/narrow shell;
  3. Dashboard;
  4. Inventory module;
  5. Finance module;
  6. a representative detail page;
  7. field and administrative mobile direction for the Phase 8 handoff;
- show both Arabic RTL and English LTR behavior;
- lock the four Dashboard v1 slots;
- lock global search and in-app notifications as Phase 7.5 deliverables;
- confirm that dark mode is deferred to Phase 12;
- approve semantic color roles and the current bundled-font direction before
  changing theme assets.

**Closure evidence:**

- owner-approved reference set;
- `docs/phase_7_5/m0/M0_ROUTE_MODULE_MATRIX.md`;
- `docs/phase_7_5/m0/M0_PERMISSION_VISIBILITY_MATRIX.md`;
- `docs/phase_7_5/m0/M0_ACCEPTANCE_RECORD.md`;
- no unresolved M0 decisions in `PRODUCT_UI_VISION.md`;
- canonical docs match this plan.

### M0.5 - Regression Baseline and Safety Snapshot

**Goal:** establish what must not regress while the shell is rebuilt.

**State:** `CLOSED / ACCEPTED` on 2026-07-24. The application, SQL,
integration, data-pollution, route/deep-link, screenshot, performance, and
migration baselines are recorded under `docs/phase_7_5/m0_5/`. No production
behavior or migration was added.

**Work:**

- record clean analyzer, Flutter test, SQL/integration, and data-pollution
  baselines using the repository's accepted runners;
- inventory every existing route, deep link, parent/back target, visible menu
  entry, and required permission;
- capture reference screenshots for representative Phase 5-7 screens in
  Arabic/English at desktop and narrow widths;
- record current calendar list performance and other high-use read paths;
- confirm migration checksums and current database boundary before adding any
  Phase 7.5 migration.

**Closure evidence:**

- `docs/phase_7_5/m0_5/M0_5_BASELINE_REPORT.md`;
- `docs/phase_7_5/m0_5/M0_5_ROUTE_BASELINE_AND_ZERO_LOSS_CHECKLIST.md`;
- `docs/phase_7_5/m0_5/M0_5_SCREENSHOT_MANIFEST.md` and its 12 durable images;
- `docs/phase_7_5/m0_5/M0_5_MIGRATION_CHECKSUMS.txt`;
- all accepted runners passed, SQL pollution delta and final domain counts are
  zero, and all 50 named route paths plus the root resolver are inventoried.

### M1 - Theme Tokens and Shared UI Foundation

**Goal:** create the reusable visual language used by every following
milestone.

**State:** `CLOSED / ACCEPTED` on 2026-07-24. The semantic light-theme
foundation, accepted Option C surfaces, reusable presentation patterns, and
representative feature adoption are implemented. Automated contrast,
keyboard-focus, RTL/LTR, 200% text-scale, regression, and screenshot gates
passed. Evidence is under `docs/phase_7_5/m1/`.

**Work:**

- reconcile documentation and code into semantic tokens: brand accent gold,
  accessible action/focus color, neutrals, and semantic success/warning/error;
- retain the bundled Noto Sans/Noto Sans Arabic family for Phase 7.5 unless M0
  visual comparison proves a replacement and its packaging/performance cost is
  accepted;
- build focused shared patterns for page header, filter/search bar,
  loading/error/empty states, status badge, money display, table/list frame,
  detail header/section, and sensitive-action dialog;
- implement the accepted Option C warm stone/cream surfaces and calm radii,
  while using the accepted compact Option B-inspired filter/table density on
  Finance and Inventory;
- standardize spacing, focus, disabled, hover, destructive, and validation
  states;
- avoid a single configurable “mega table”; feature columns, queries, and
  business behavior remain feature-owned.

**Acceptance:**

- representative Inventory, Finance, Contracts, and Customers screens can use
  the same primitives without losing feature-specific behavior;
- visual states pass light-theme contrast, keyboard focus, RTL/LTR, and text
  scale checks;
- no mass font migration or dark-mode implementation is introduced.

**Closure evidence:**

- `docs/phase_7_5/m1/M1_ACCEPTANCE_REPORT.md`;
- `docs/phase_7_5/m1/M1_SCREENSHOT_MANIFEST.md` and 12 durable AR/EN desktop
  and narrow images;
- `flutter analyze` clean and the complete Flutter suite at 1431 passed;
- 7 focused foundation tests plus representative Inventory, Finance,
  Contracts, and Customers regression coverage;
- the M0.5 contract-detail overflow at 390 px is resolved without changing
  contract behavior;
- no RPC, migration, data contract, dark theme, or font-family replacement was
  introduced.

### M2 - Desktop Shell and Typed Navigation

**Goal:** replace the flat shell with the accepted product structure.

**State:** `NEXT / NOT STARTED`.

**Work:**

- split `app_shell.dart` into focused shell, sidebar, top-bar, contextual-nav,
  and user-card responsibilities;
- introduce one typed module/route metadata source consumed by navigation and
  tests;
- implement expanded/collapsed sidebar, lower Audit/Settings area, and
  signed-in user identity/profile footer;
- match the accepted Option C shell hierarchy in expanded, collapsed/narrow,
  Arabic RTL, and English LTR states;
- implement title/back/breadcrumb, locale, quick-create anchor, search anchor,
  and notification anchor in the top bar;
- implement permission-filtered contextual tabs with scroll/overflow behavior;
- preserve existing URLs, deep links, unsaved-change guards, and deterministic
  back targets.

**Acceptance:**

- no action or individual settings page remains a primary sidebar item;
- every pre-M2 route is reachable and guarded exactly as before;
- empty modules and unauthorized tabs are omitted without leaking labels or
  counts;
- shell behavior matches the M0 reference set in Arabic and English.

### M3 - Module Consolidation and Existing Screen Adoption

**Goal:** place existing functionality inside coherent business modules and
apply the shared presentation patterns.

**Work:**

- consolidate Customers & Suppliers, Contracts, Appointments & Visits,
  Inventory, Finance, and Settings surfaces under their module shells;
- move create/transfer/count/adjust/cancel operations into permission-filtered
  in-module commands;
- rename the accounting navigation label to `Journal Entries / القيود
  اليومية`;
- apply shared page/list/detail/loading/error/empty patterns to the
  representative and high-use surfaces agreed in M0;
- keep unavailable future tabs hidden, while preserving their documented
  placement for later phases.

**Acceptance:**

- module grouping does not merge distinct entities, permissions, or posting
  semantics;
- Calendar remains plan and Visits remains execution evidence;
- users can complete all accepted Phase 3-7 navigation journeys without using
  a direct URL.

### M4 - Global Search, Quick Create, and Notification Center

**Goal:** make high-frequency navigation and attention items useful from every
module.

**Work:**

- implement capped, grouped global search for the scope in section 3.3;
- define permission-safe server/read contracts and tests for search results;
- implement keyboard and pointer navigation plus canonical detail deep-links;
- implement a permission-filtered quick-create menu for existing supported
  workflows only;
- implement the in-app notification panel/list, unread badge, read transition,
  empty/error states, and safe source deep-links;
- do not display a decorative or non-functional bell/search control.

**Acceptance:**

- zero-permission and restricted users cannot infer hidden records through
  result text, counts, timing-visible categories, notifications, or errors;
- unread/read behavior is idempotent and recipient-scoped;
- stale or unauthorized deep-links fail closed;
- search and notification UI pass desktop/narrow, keyboard, AR/EN, and RTL/LTR
  acceptance.

### M5 - Dashboard v1 and Daily Activity

**Goal:** replace the Phase 2 placeholder with useful, trusted operational
orientation.

**Work:**

- implement the four fixed Dashboard slots from section 3.1;
- provide source-list drill-down with the same filters represented by each
  visible number;
- implement selected-date Daily Activity as a union of authorized existing
  projections;
- define stable ordering, pagination, empty/loading/error behavior, and source
  links;
- prevent raw audit fields or unauthorized entity labels from entering either
  surface.

**Acceptance:**

- every number reconciles with its drill-down source under the same permission
  and date context;
- financial slot is absent or safely unavailable without financial permission;
- Dashboard and Daily Activity remain distinct from Journal Entries and the
  Audit Log;
- timezone/date boundaries use the tenant's accepted business-date rules.

### M6 - Record Lifecycle Actions and Basic Audit Review

**Goal:** expose correction workflows consistently without weakening backend
safety.

**Work:**

- standardize draft edit/discard, confirmed cancel/reverse, contract lifecycle,
  and master-data deactivate presentation;
- show non-empty reason capture and consequence preview where the trusted
  backend can determine effects;
- map backend rejections such as period lock or downstream usage to actionable
  localized messages without claiming cancellation is always possible;
- add the permission-gated, redacted Audit Log read contract and basic filters;
- link safe audit rows back to visible source records.

**Acceptance:**

- no posted financial document or used contract exposes hard delete;
- actions remain hidden/disabled consistently by state and permission, while
  the server revalidates every call;
- protected before/after data stays redacted even for a user who has
  `audit_log.view` but lacks source-field access;
- reversal/cancellation tests cover both allowed and deliberately rejected
  downstream states.

### M7 - Finance, Inventory, and Cross-Module Integrity Gate

**Goal:** prove that the structural/UI changes did not damage trusted business
invariants.

**Work:**

- verify balanced journal entries and document-to-journal links;
- verify accepted cancellation/reversal stock, allocation, cash/bank, period,
  and audit effects;
- verify inventory movements, balances, transfers, WAC, and serialized-unit
  guards;
- verify Dashboard, Daily Activity, search, notification, and audit projections
  reconcile with their authoritative sources;
- add verification-only trial-balance/inventory-to-GL queries if needed; full
  finance reporting remains Phase 10.

**Acceptance:** all Phase 5-7 financial/inventory suites and new Phase 7.5
projection/integrity cases pass on a clean reset with no pollution.

### M8 - Responsive, Bilingual, Accessibility, and Performance Acceptance

**Goal:** harden the completed experience across supported layouts and access
profiles.

**Matrix:**

- Arabic RTL and English LTR;
- expanded desktop, collapsed desktop, narrow desktop/tablet, and current
  mobile fallback;
- Manager, zero-permission, assigned-only, single-module, and mixed-permission
  users;
- loading, empty, populated, error, overflow, long-label, large-number, and
  text-scale states.

**Acceptance:**

- keyboard focus/order, tooltips, semantics, contrast, 200% text scale, and
  no-horizontal-page-overflow checks pass;
- contextual tabs scroll/collapse rather than wrap into broken rows;
- no material regression from the M0.5 performance baseline;
- the 800ms calendar target is reported as a non-blocking optimization result.

### M9 - Visual Regression and Owner Acceptance

**Goal:** prove that the implemented product matches the approved direction.

**Work:**

- capture a durable reference set for the M0 screens in both locales and
  representative widths;
- add focused golden/screenshot tests where stable and maintainable;
- complete owner visual review of shell, Dashboard, Inventory, Finance, detail
  page, search, notifications, sensitive action dialog, and Audit;
- correct accepted defects and rerun affected automated/visual gates.

**Closure evidence:** signed owner acceptance note, evidence index/checksums,
and no unresolved severity-1/2 visual or navigation defects.

### M10 - Phase Close, Migration Rehearsal, and Phase 8 Handoff

**Goal:** close Phase 7.5 cleanly and reduce later migration/field-work risk.

**Work:**

- run final clean-reset, analyzer, full Flutter, SQL/integration, pollution,
  permission, route, and documentation consistency gates;
- create a read-only Google Sheets mapping/profile for customers, products,
  contracts, balances, and identifiers, then run one disposable **local**
  import rehearsal without changing production/live data;
- document data-quality findings and forward fixes for the Phase 12 production
  migration;
- hand Phase 8 the accepted mobile information architecture,
  employee/work-profile boundary, request/approval contract, and
  calendar-plan/visit-execution boundary;
- preserve the separate pre-production physical Android smoke obligation.

**Acceptance:**

- all Phase 7.5 milestones are `CLOSED / ACCEPTED`;
- no trusted Phase 5-7 behavior or migration checksum regressed;
- the local rehearsal is repeatable and leaves the baseline clean;
- canonical docs, README, and AI memory agree on the next active phase.

---

## 12. Phase-Level Acceptance Gates

Phase 7.5 closes only when:

- M0 through M10 are explicitly closed with their required evidence;
- the sidebar contains the locked modules rather than a flat route/action list;
- every existing production route remains reachable with reliable back
  navigation;
- search, Dashboard, Daily Activity, notifications, badges, Audit, and module
  tabs are permission-shaped and fail closed;
- the top bar, sidebar, and contextual navigation have distinct responsibilities;
- Inventory and Finance group related screens without collapsing entities;
- appointments and visits appear unified to users but remain plan versus
  execution internally;
- lifecycle actions match backend safety and never imply every confirmed
  document can always be cancelled;
- Arabic/English, RTL/LTR, widths, accessibility states, performance baseline,
  and permission matrix pass;
- finance/inventory integrity and Phase 5-7 regression suites pass cleanly;
- owner visual acceptance and Phase 8 handoff are recorded.

---

## 13. Explicit Non-Goals

Phase 7.5 does not implement:

- full field visit execution or offline sync;
- full HR/payroll/employee-document management;
- all request types and approval application handlers;
- POS;
- full General Ledger/report/financial-close UI;
- advanced configurable dashboards;
- route optimization or the Phase 10 Operations Map;
- new external notification channels;
- dark mode implementation;
- mass font replacement;
- configurable Dashboard layout;
- production/live data import;
- unrelated large-file refactors performed only to reduce line counts.

These scopes are planned now and implemented in their assigned phases.
