# Phase 7 - Calendar and Company Appointment Management Plan

> Purpose: build a professional, tenant-safe company appointment-management
> system that combines contract-generated due items with internal meetings,
> customer visits, tasks, reminders, activities, and other controlled manual
> business appointments in one operational calendar.
>
> Status: **M0–M12 complete / accepted — `PHASE 7 CLOSED / ACCEPTED`** including
> **`M8 FLUTTER CLOSED / ACCEPTED`** (Gate D **PASS / OWNER ACCEPTED**,
> 2026-07-19). Migrations `093`–`102` remain byte-unchanged
> relative to pre-`103`; **`103`** is the evidence-gated M11 migration and must
> stay byte-identical through M12. **M11 CLOSED / ACCEPTED** (2026-07-19).
> **M12 `CLOSED / ACCEPTED`** — Gates D/E/F **`PASS / OWNER ACCEPTED`**,
> Gate G **PASS**, and Final Gate H **PASS** through migration `104`. Gate F
> used physical iOS + Android Emulator. **Physical Android smoke is required
> before production** under the owner-approved deferral. Phase 8 not started.
> Map provider decision: `docs/PHASE_7_M10_MAP_PROVIDER.md`.
>
> Owner direction (revised 2026-07-15): HS360 Calendar is the company's shared
> appointment-management surface, not only a contract-follow-up calendar. The
> model is hybrid: generated due items and untimed manual items remain day-based;
> an explicitly timed manual event may optionally have a same-day start/end
> window. The UI must never invent a precise time when none was entered.
>
> Canonical sources: `CANONICAL_DECISIONS.md`, `MVP_SCOPE.md`,
> `CONTRACTS_LOGIC.md`, `DATABASE_SCHEMA.md`, `PERMISSIONS.md`,
> `PHASE_6_CONTRACTS_PLAN.md`, and the owner decisions locked in this file. When
> older Phase 7 text conflicts with this file, this file supersedes it after M0
> reconciliation.

---

## Executive Summary

Phase 7 is the company-wide scheduling and planning layer. It connects
contract obligations, office appointments, internal coordination, customer
visits, and later field execution without confusing plans with completed work.

Phase 6 already creates canonical, idempotent contract-generated calendar rows
for billing, refills, trial endings, and contract endings. Phase 7 must expose
those rows through safe read APIs and a professional Arabic/English calendar,
then add controlled company appointment management, participants, assignment,
audited rescheduling, working-date exceptions, reminder generation, mobile
viewing, and route/directions support.

The phase must preserve one critical boundary:

```text
contract or company planning
        -> date-only due item or optional-time manual appointment
        -> assignment and daily planning
        -> Phase 8 visit execution
        -> GPS/photo/actual stock/payment effects
```

A calendar event is a plan, not proof of work. Creating, assigning, or moving an
event must never consume inventory, create a voucher, post accounting entries,
or mark a field visit completed.

The implementation is divided into `M0` through `M12`, with an additional
`M0.5` safety checkpoint. Backend correctness and read contracts come before
the calendar UI. Manual and mutation workflows come only after generated-event
provenance is protected.

---

## What Phase 7 Means

At the end of Phase 7:

- Office users can open a real Calendar module from guarded navigation.
- The default page is split vertically:
  - an upper calendar area;
  - a lower agenda for the selected date.
- Selecting a date updates the lower agenda without leaving the page.
- Every selected date shows whether it is:
  - a configured day off;
  - a limited working day;
  - a full working day;
  - a 24-hour working day.
- Each tenant can configure every weekday independently.
- Contract-generated events remain scheduled by date and never receive an
  invented time.
- Manual company events may be date-only or may carry an explicitly entered,
  same-day start/end time window in the tenant's confirmed IANA timezone.
- Contract-generated events appear without duplication.
- Users can filter events by date, type, status, employee, customer, contract,
  and service location.
- Managers or permitted users can create customer visits, internal meetings,
  tasks/reminders, internal activities/training, and custom manual events.
- Meeting/activity participants are modeled separately from the single
  employee responsible for/assigned to an operational event.
- Authorized settings users can manage official holidays, company closures,
  and exceptional working days as working-calendar exceptions rather than
  pretending they are ordinary appointment cards.
- Authorized users can assign or reassign employees.
- Authorized users can reschedule events to another date.
- Assigned employees see only their own events when they have
  `calendar.view_assigned` rather than global calendar access.
- Date-only reminders are derived from the event date and tenant working
  schedule. Timed-manual reminder behavior must use the accepted explicit time
  contract and cannot silently turn a calendar category into a new notification
  policy.
- Mobile users can view their selected-day agenda and open native directions to
  the event's service location.
- A display-only route view helps the office inspect the geographic distribution
  of one employee's day without claiming route optimization.
- Arabic, English, RTL, LTR, permission, tenant-isolation, performance, and
  accessibility gates pass.

---

## Current Repository Inspection

### Confirmed Starting Point

- Phase 6 is closed through M13 migration `092`; M12 calendar handoff itself is
  migrations `090`/`091`.
- `calendar_events` exists from Phase 1 and already has RLS.
- Seeded calendar permissions already include:
  - `calendar.view`;
  - `calendar.view_assigned`;
  - `calendar.create`;
  - `calendar.edit`;
  - `calendar.delete`.
- `calendar_events` currently supports:
  - event type and status;
  - `scheduled_date`;
  - nullable legacy `scheduled_time`;
  - assignment;
  - contract, customer, service-location, product-unit, and visit links;
  - Arabic/English titles and notes;
  - completion metadata;
  - recurrence fields.
- Phase 6 M12 added:
  - `billing_due`;
  - `source_kind`;
  - deterministic `source_key`;
  - structured `source_metadata`;
  - optional `contract_line_id`;
  - trusted-writer protection for generated provenance;
  - idempotent contract schedule synchronization;
  - lifecycle hooks;
  - a tenant batch synchronization RPC;
  - contract-detail `upcoming_schedule`.
- Contract generation already covers:
  - rental billing dates;
  - refill/consumable schedule dates;
  - trial-ending dates;
  - fixed-term contract endings.
- `notifications` exists but is not yet a complete calendar-reminder delivery
  engine.
- Customer service locations already contain the operational coordinates and
  Google Maps URL needed for directions/route display.
- Flutter has no Calendar feature directory, repository, controller, screen,
  route, or navigation item yet.
- The current field Today screen is a placeholder and remains primarily a
  Phase 8 execution surface.
- There is no working-days/working-hours schema or UI yet.
- `tenants.timezone` currently has a legacy `Asia/Kuwait` default. M0 does not
  treat that inherited value as proof of owner selection; M1 requires explicit
  manager review before calendar settings become configured.
- There is no direct map package or direct `url_launcher` dependency declared
  for Phase 7 use yet; M10 must choose and record the minimal dependencies.

### Existing M12 Semantics That Must Remain Locked

- Generated rows use `source_kind = contract_generated`.
- Manual rows use `source_kind = manual` and have no `source_key`.
- Generated rows are created by trusted server-side paths only.
- Billing source identity uses the coverage month, not merely the displayed
  date.
- Default generation horizon is 30 days and the supported cap is 180 days.
- Suspension removes pending future billing/refill rows; reactivation recreates
  them.
- Schedule generation has no financial side effects.
- Contract detail reads generated pending events from the server and does not
  infer dates on the client.

---

## Owner Decisions Locked For Phase 7

These decisions come from the 2026-07-12 Phase 7 planning discussion plus the
owner's 2026-07-15 company-wide appointment-management expansion. The newer
manual-event decisions supersede the earlier all-events-date-only wording while
preserving the accepted behavior of generated events.

1. Contract-generated events and untimed manual events are day-based.
2. A manual company event always has a date and may optionally enable
   `Set time` / `تحديد وقت` to capture a same-day start and end.
3. A date-only event is expected to occur within the configured working window
   for that date. A timed manual event is validated against the same calendar
   and may show a warning when it conflicts, but it is not silently moved.
4. The legacy nullable `scheduled_time` column remains compatibility-only and
   all new Phase 7 write paths keep it `null`.
5. M7A should introduce an explicit optional timed-event contract using
   `scheduled_start_at timestamptz`, `scheduled_end_at timestamptz`, and
   `scheduled_timezone_name text` (or an equivalently reviewed schema). The
   three values are either all null or all non-null; end must be after start;
   overnight manual appointments are outside v1.
6. Every weekday is configured independently.
7. Each weekday supports exactly one of these v1 modes:
   - non-working/day off;
   - working with one continuous start/end window;
   - working 24 hours.
8. Half-day and full-day are outcomes of the configured window, not separate
   database enums. For example, `08:00-12:00` is a half-day and
   `08:00-17:00` is a full day.
9. Split or overnight shifts are not part of Phase 7 v1. They may be added later
   without changing event date semantics.
10. Events may still be placed on a non-working day when an authorized user
    explicitly confirms the exception. The system warns and records the
    override; it must not silently move the date.
11. Contract generation may produce an event on a non-working day because the
    contractual due date remains factual. The calendar highlights the conflict
    and allows an explicit operational reschedule; it does not rewrite the
    contract date.
12. The primary desktop calendar page is divided vertically:
    - upper section: calendar/month navigation and filters;
    - lower section: selected-day events.
13. Clicking a date refreshes the lower agenda in place.
14. The selected-day header shows its working status/window.
15. Calendar scheduling is operational only. It creates no stock, voucher,
    invoice, journal, GPS, photo, or visit-completion effects.
16. Actual field execution stays in Phase 8.
17. Route View is display-only in Phase 7. It does not promise optimal ordering,
    ETA, traffic-aware routing, or automated dispatch.
18. Native Directions opens the selected service location in the device's map
    application.
19. Working schedules are owner-configured. HS360 creates seven unconfigured
    weekday rows but does not infer a weekend, working day, or working window
    from country, locale, or timezone.
20. Calendar settings remain explicitly unconfigured until the manager chooses
    an IANA timezone and reviews all seven weekdays atomically.
21. No working-hours-based reminder is created while calendar settings are
    unconfigured.
22. An unexecuted due event is never moved or completed automatically. It stays
    pending and is presented as overdue until trusted actual execution arrives.
23. Every generated operational due event preserves `original_due_date`.
24. `overdue` is a derived presentation/read state for a pending event whose
    original due date is before the tenant-local current date; it is not a fake
    completion status.
25. Phase 8 records trusted execution facts, including
    `actual_completion_date`, actual delivered quantity, confirmed coverage,
    and confirmed next due date. Phase 7 may display those facts but cannot
    create them.
26. A refill cadence chain has at most one outstanding due event. The next
    refill is not generated while the prior refill remains unexecuted.
27. The next refill anchor is the trusted actual completion date, extended by
    confirmed coverage. It is never based only on the old planned date.
28. During Phase 8 execution, the system should calculate and present proposed
    coverage and next date from actual delivered quantity divided by contracted
    quantity per cycle. The user confirms the proposal before it becomes
    authoritative.
29. A manual override of confirmed `next_due_date` requires a dedicated
    permission, non-empty reason, and immutable audit trail. Phase 7 does not
    provide an unaudited override path.
30. Calendar-settings permissions are dedicated:
    - `settings.calendar.view`;
    - `settings.calendar.edit`.
31. Calendar event permissions remain separate:
    - `calendar.view`;
    - `calendar.view_assigned`;
    - existing mutation permissions as accepted by their milestones.
32. Viewing calendar events never implicitly grants access to calendar
    settings.
33. Initial in-app reminder policies are:
    - at the start of the event working day;
    - at the start of the previous working day.
34. Both reminder policies are individually configurable in Calendar Settings.
35. Calendar is company-wide appointment management, not only contract due-date
    tracking.
36. Initial manual categories are:
    - customer visit;
    - internal meeting;
    - internal task/reminder;
    - internal activity/training;
    - custom.
37. Official holidays, company closures, and exceptional working days are
    working-calendar exceptions, not ordinary event types or agenda cards.
38. Meeting/activity participants use a dedicated participant relation and are
    distinct from the event's assigned/responsible employee.
39. An identity with `calendar.view_assigned` may read an event when they are
    the assigned employee or an explicit participant; the server enforces this
    scope for rows and counts.
40. M7A may use optional free-text team/location text. Structured departments,
    teams, meeting rooms, capacity, and room-conflict enforcement are deferred.
41. Overlap handling is warning-only in M7A. It must not hard-block valid
    business scheduling, and date-only events may coexist freely.
42. Manual events use cancel-with-reason and audit history; M7 does not expose
    hard delete. `calendar.delete` remains reserved for a later explicit policy.
43. A manual `task/reminder` category does not by itself create a new custom
    notification schedule. Notification timing requires a separately accepted
    reminder contract.
44. M7 is split into M7A (manual business events/internal appointments) and M7B
    (working-calendar holidays/exceptions). M8 remains responsible for
    assignment/reassignment and moving an event to another date.

---

## Hybrid Date and Optional-Time Scheduling Semantics

### Canonical Event Date

`calendar_events.scheduled_date` remains the canonical tenant-local calendar
date for every event.

Phase 7 APIs and UI must:

- require `scheduled_date`;
- keep legacy `scheduled_time = null` or omit it from public DTOs;
- return a nullable typed `time_window` only for explicitly timed manual events;
- expose canonical tenant-local `HH:mm` start/end display values plus the IANA
  timezone name in that typed wrapper;
- resolve submitted local date/time on the server using the tenant's confirmed
  IANA timezone, never the device or database-server timezone;
- preserve the IANA timezone snapshot used for the appointment;
- reject incomplete time triples, end-before-start, cross-date, and overnight
  windows in v1;
- never sort a day's events by a made-up time;
- sort explicitly timed manual events by their start time and use stable
  operational ordering for date-only items;
- display wording such as `خلال ساعات العمل` / `During working hours`;
- show the resolved work window separately from the event itself.

### Stable Daily Ordering

Within one selected date, the agenda should present:

1. `Timed appointments` / `مواعيد محددة الوقت`, ordered by start time then
   stable event id;
2. `Day tasks and due items` / `مهام واستحقاقات اليوم`, using:
   - urgent/overdue indicators;
   - event-type operational priority;
   - assigned employee name;
   - customer name;
   - service-location name;
   - stable event id as the final tie-breaker.

Do not use row creation time as a business priority.

If the business later requests manual visit ordering, add an explicit nullable
`day_sequence`/`route_position` field through a separate accepted change. Do not
misuse `scheduled_time` to store sequence.

### Working-Day Conflicts

An event can have one of these derived schedule states:

- `within_working_day`;
- `non_working_day`;
- `working_schedule_missing`;
- `working_schedule_override`.

This state is derived by the server read contract so every client sees the same
result.

### Rescheduling

M8 rescheduling means changing `scheduled_date`. Editing an optional manual
time window without changing the date belongs to M7A and must use the same
version/audit protections.

- Generated provenance and `source_key` remain immutable.
- The original generated contractual date must remain recoverable in audit or
  provenance metadata.
- Rescheduling requires a non-empty reason.
- Moving to a non-working day requires an explicit override flag plus reason.
- Drag-and-drop, if implemented on desktop, is only a UI gesture over the same
  audited reschedule RPC.
- Direct client updates to generated rows are not allowed.

Rescheduling is an operational planning action only. It does not clear overdue
state, change `original_due_date`, create an execution fact, or advance the
refill cadence chain.

### Overdue Until Actual Execution

A pending event is overdue when:

```text
status = pending
and original_due_date < tenant-local current date
and actual_completion_date is null
```

Required behavior:

- keep the event pending;
- derive and return `is_overdue = true`;
- return `overdue_days = tenant_local_today - original_due_date`;
- show the original due date and delay count;
- never move it to today automatically;
- never mark it done because another calendar date was reached;
- never generate the next refill solely because the old cadence date passed.

Example:

```text
original_due_date       = 2026-08-01
actual_completion_date = null
tenant-local today      = 2026-08-04
status                  = pending
is_overdue              = true
overdue_days            = 3
```

When Phase 8 confirms the visit on 2026-08-04, the trusted execution record
contains both dates. Phase 7 then displays completion but does not author it.

### Actual Completion, Coverage, and Next Refill

For refill/consumable events, the next due event depends on confirmed execution:

```text
coverage_ratio = actual_quantity_delivered / contracted_quantity_per_cycle
next_due_date  = actual_completion_date + confirmed coverage duration
```

Example:

```text
contracted quantity per monthly cycle = 500 ml
actual quantity delivered              = 1500 ml
proposed coverage                      = 3 months
actual completion date                 = 2026-08-04
proposed next due date                 = 2026-11-04
```

Rules:

- Phase 8 captures the actual quantity in the product's canonical unit.
- Unit conversion must use the existing unit-conversion foundation; raw
  quantities in incompatible units are not divided directly.
- The proposal shows its inputs and result before confirmation.
- Whole month-based coverage uses calendar-month arithmetic; day-based coverage
  uses days.
- The authoritative record stores the confirmed coverage and
  `next_due_date` used by Phase 7 generation.
- Fractional coverage presentation/rounding is finalized in the Phase 8
  execution contract; Phase 7 consumes only the trusted confirmed result and
  does not invent its own rounding.
- Manual next-date override requires permission, reason, actor, timestamp, old
  value, new value, and audit entry.
- No inventory is reduced and no actual delivered quantity is confirmed in
  Phase 7.
- Billing recurrence remains independent and may continue on its financial
  cadence; this rule changes refill/consumable generation only.

### Protected Phase 8 Execution Handoff

M1/M2 must prepare a protected persistence contract that Phase 8 can write only
through its trusted visit-completion RPC. The preferred direction is a
refill-specific execution-facts table linked one-to-one to the completed due
event rather than allowing Calendar clients to update execution columns.

The handoff must be able to preserve:

- tenant, calendar event, visit, contract, and contract-line identity;
- `original_due_date` from the due event;
- `actual_completion_date`;
- actual delivered quantity in canonical unit;
- snapshotted contracted quantity per cycle used by the calculation;
- confirmed `coverage_months` and/or `coverage_days`;
- confirmed `next_due_date`;
- proposal versus manual override indicator;
- override permission, reason, actor, old/new values, and timestamp.

During Phase 7:

- authenticated Calendar clients have no insert/update grant on execution
  facts;
- tests may seed a trusted fixture as `postgres` solely to prove M2 consumption;
- no stock movement or visit completion is performed;
- Phase 8 later owns the single atomic operation that writes execution facts,
  consumes stock, records proof, and advances the calendar chain.

---

## Working Days and Working Hours Foundation

### Why It Belongs In Phase 7

Working schedules are not merely future Settings polish. Phase 7 needs them to:

- label selected dates correctly;
- show the operational window for the day;
- detect day-off conflicts;
- compute reminder anchors;
- support mobile day planning;
- avoid inventing exact appointment times.

Therefore M1 must build the database model, validation, read/write RPCs, and a
focused settings surface. A broader Settings redesign may happen later, but
Phase 7 cannot depend on hard-coded hours.

### Proposed Weekly Model

Use one dedicated calendar-settings row plus a normalized seven-row weekday
table rather than seven groups of columns on `tenant_settings`.

Suggested shape, subject to M1 migration review:

```sql
create table tenant_calendar_settings (
  tenant_id uuid primary key,
  timezone_name text, -- valid IANA name; null/unconfirmed initially
  working_schedule_configured boolean not null default false,
  remind_event_workday_start boolean not null default true,
  remind_previous_workday_start boolean not null default true,
  configured_at timestamptz,
  configured_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table tenant_working_days (
  tenant_id uuid not null references tenant_calendar_settings(tenant_id),
  iso_weekday smallint not null, -- 1 Monday ... 7 Sunday
  day_mode text, -- null until reviewed; day_off | working_hours | 24_hours
  work_start time,
  work_end time,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (tenant_id, iso_weekday)
);
```

The two reminder booleans express the accepted initial policy defaults, but the
reminder engine remains disabled until `working_schedule_configured = true`.
The manager may turn either boolean off during initial configuration or later.

Required constraints:

- `iso_weekday` is between 1 and 7.
- An unreviewed row has:
  - `day_mode = null`;
  - null start/end.
- A day off has:
  - `day_mode = day_off`;
  - null start/end.
- A 24-hour day has:
  - `day_mode = 24_hours`;
  - null start/end.
- A limited working day has:
  - `day_mode = working_hours`;
  - non-null start/end;
  - `work_start < work_end`.
- Overnight and split windows are rejected in v1 with a clear validation error.
- Every tenant always resolves to exactly seven rows.

Use an explicitly manager-reviewed IANA timezone for calendar operations. The
existing `tenants.timezone = Asia/Kuwait` default is legacy data and must not by
itself make the schedule configured. Add `working_schedule_configured boolean
not null default false` (or an equivalently explicit reviewed state) to the
calendar settings model. Date/reminder logic must use the manager-confirmed
timezone, never infer one from country/locale and never use the database server
or device timezone implicitly.

### Seed and Unconfigured Behavior

Safe migration requirements:

- existing tenants receive exactly seven rows with no inferred day modes or
  hours;
- `working_schedule_configured` remains false;
- an inherited legacy timezone remains unconfirmed unless the manager explicitly
  adopts or changes it through Calendar Settings;
- no event is changed during backfill;
- unconfigured/missing/corrupt schedules produce a visible manager-facing
  setup warning, not silent assumptions;
- the calendar remains viewable while unconfigured, but displays that working
  windows and reminders are unavailable;
- no working-hours-based reminder is created until configuration is complete;
- a server helper returns the resolved working window for a given tenant/date.

No Phase 7 migration, seed, country, or locale may claim a weekend, working day,
or fixed `08:00-17:00` window as a default. The legacy `Asia/Kuwait` value may
be shown as an unconfirmed suggestion but cannot be silently adopted.
Configuration becomes complete only when one atomic manager action confirms a
valid IANA timezone and reviews all seven rows.

### Settings UI Requirement

Add a focused `Working Days & Hours` / `أيام وساعات العمل` settings page.

It requires `settings.calendar.view`; editing requires
`settings.calendar.edit`. Calendar event viewing permissions do not grant
either permission.

For each weekday, show:

- working/day-off toggle;
- 24-hour toggle;
- start time;
- end time;
- a human-readable summary;
- validation inline.
- IANA timezone selection;
- two independent in-app reminder toggles:
  - event working-day start;
  - previous working-day start;
- a persistent setup banner while `working_schedule_configured = false`.

Example:

```text
Sunday     Working   08:00 - 17:00
Monday     Working   08:00 - 17:00
Tuesday    Working   08:00 - 17:00
Wednesday  Working   08:00 - 17:00
Thursday   Half day  08:00 - 13:00
Friday     Day off
Saturday   24 hours
```

The word `Half day` is a presentation summary inferred from the duration. The
stored truth remains the configured start/end window.

### Working-Date Exceptions (M7B)

Public holidays, temporary company closures, Ramadan/special hours, and one-off
working days require date-specific overrides. M7B must add a dedicated model
such as `tenant_working_date_exceptions`; it must not overload weekly rows or
create fake calendar-event cards.

Required concepts:

- tenant and inclusive date range;
- localized title (`title_ar` / `title_en` with accepted fallback rules);
- exception kind: `official_holiday`, `company_closure`, or
  `exceptional_working_day`;
- optional notes;
- active/cancelled lifecycle, version, actor/timestamps, and audit;
- for exceptional working days only: working-hours/24-hours mode and validated
  same-day start/end when applicable.

Date-specific exceptions override the weekly schedule for affected dates.
Active overlapping exceptions are rejected deterministically. A closure never
silently deletes or moves an event; existing events are shown as conflicts and
authorized users decide whether to reschedule them. Changes recalculate only
pending date/working-day reminder anchors and preserve sent history.

---

## Reminder Semantics For Date-Only Events

The old concept `1 day + 1 hour before an appointment` assumes an exact event
time and is not valid for Phase 7.

### Locked Direction

- `reminder_offsets_minutes` is legacy compatibility data.
- Phase 7 reminder APIs must not interpret a null-time event as midnight and
  subtract minutes from it.
- Reminder rules are date/working-day based.
- Initial configurable in-app reminder policies are:
  - the start of the event's working day;
  - the start of the previous working day.
- Either policy may be disabled independently in Calendar Settings.
- If `working_schedule_configured = false` or timezone is missing, neither
  policy creates a reminder; the manager sees a setup-required warning.
- For a 24-hour day, the day anchor is `00:00` in the tenant timezone.
- For a non-working event date, the engine resolves the configured policy and
  records the resolution. It must not silently pretend the day is working.
- Repeated job runs must not create duplicate reminder deliveries.
- Changing assignment or date recalculates only pending reminders; sent history
  remains immutable.

### Proposed Reminder Foundation

M3 should introduce an idempotent delivery ledger rather than relying only on
`notifications.status`.

Suggested concepts:

- reminder rule key;
- event id;
- recipient user/employee;
- channel;
- resolved tenant-local anchor;
- UTC delivery timestamp;
- status;
- attempt count;
- sent/error timestamps;
- unique idempotency key.

Phase 7 guarantees in-app reminder creation. Email/WhatsApp/SMS delivery may be
enabled only when its credentials, consent, retry behavior, and external
delivery worker are explicitly accepted. A queued row is not proof that an
external message was delivered.

---

## Scope

### In Scope

1. Phase 7 decision reconciliation and safety checkpoint.
2. Weekly tenant working-day/hour foundation.
3. Tenant timezone foundation if missing.
4. Focused working-schedule settings read/edit surface.
5. Hybrid calendar invariants: generated/date-only items plus optional-time
   manual company appointments.
6. Contract-generated event hardening and scheduled batch synchronization.
7. Reminder idempotency foundation and in-app reminders.
8. Calendar read RPCs with bounded ranges and filters.
9. Flutter models, validators, mappers, repositories, controllers, and errors.
10. Guarded routes, navigation, Arabic/English localization, RTL/LTR.
11. Desktop upper-calendar/lower-agenda UI.
12. Company-wide manual event categories: customer visit, internal meeting,
    task/reminder, activity/training, and custom.
13. Optional manual time windows and participant management.
14. Official holidays, closures, and exceptional working days.
15. Assignment/reassignment.
16. Audited date rescheduling.
17. Manual cancellation with reason; no hard delete in M7.
18. Mobile responsive calendar and assigned-agenda view.
19. Display-only route map.
20. Native directions to service-location coordinates/link.
21. SQL, Dart, widget, integration, permission, performance, and manual
    acceptance tests.
22. Documentation updates and Phase 7 closure record.

### Out Of Scope

- Exact-time contract-generated events or fabricated times.
- Customer-facing appointment-slot selection.
- Overnight or multi-day timed appointments in M7A.
- Multiple shifts per weekday.
- Overnight shifts.
- Automatic route optimization.
- Traffic-aware ETAs.
- Automatic dispatch based on distance/capacity.
- GPS check-in/check-out.
- Photo proof.
- Actual refill confirmation.
- Consumable stock-out.
- Payment collection or voucher creation.
- Visit completion workflow.
- Offline field synchronization.
- Maintenance execution.
- WhatsApp/email delivery without separately accepted credentials and worker
  behavior.
- A complete redesign of every Settings module.
- Structured departments/teams, meeting-room inventory, room capacity, and
  hard room-conflict enforcement.
- Custom per-event notification timing unless separately designed and accepted.

---

## Permission Model

Calendar event and Calendar Settings permissions are deliberately separate:

| Permission | Intended Phase 7 behavior |
|------------|---------------------------|
| `calendar.view` | View all tenant calendar events allowed by read API |
| `calendar.view_assigned` | View events assigned to the current employee or listing them as an explicit participant |
| `calendar.create` | Create ordinary manual company events only |
| `calendar.edit` | Edit/cancel manual events, manage participants, assign/reschedule where their milestone permits, and call approved sync |
| `calendar.delete` | Reserved; no M7 hard-delete endpoint |
| `settings.calendar.view` | View weekly working schedule, selected IANA timezone, reminder policies, and working-date exceptions |
| `settings.calendar.edit` | Atomically configure/edit working days, timezone, reminder policies, holidays, closures, and exceptional working days |

Granting `calendar.view` or `calendar.view_assigned` does not grant Calendar
Settings access. Grant/revoke administration remains restricted to the manager
or an identity with the accepted user/permission-management authority.

Generated events must never become deletable merely because a user has
`calendar.delete`. Generated lifecycle changes go through trusted RPCs.

Every public RPC must:

- derive tenant/user identity server-side;
- reject cross-tenant ids;
- enforce permission and assigned scope server-side;
- avoid trusting a client-supplied tenant id;
- expose only fields needed by the calendar UI;
- use stable pagination/order;
- be executable only by the intended API roles.

---

## Proposed Event Mutation Rules

| Operation | Manual event | Contract-generated event |
|-----------|--------------|--------------------------|
| Create | Allowed through manual-event RPC | Trusted generation only |
| Edit title/notes | Allowed with permission | System title/provenance protected; limited operational note may be separate |
| Assign/reassign | Allowed | Allowed through audited RPC |
| Reschedule date | Allowed with reason | Allowed operationally with reason while preserving original due provenance |
| Mark done / close | Allowed through the audited manual lifecycle RPC as an informational appointment state only; it must not claim Phase 8 visit/service execution | Allowed only through the trusted execution/lifecycle path |
| Cancel | Allowed with reason | Controlled; must not corrupt contract generation/lifecycle semantics |
| Delete | No hard delete in M7; cancel with reason | Forbidden |
| Change source kind/key | Forbidden | Forbidden |

M1/M2 must settle whether operational reschedule state is stored directly on
the generated row or in a separate override table. The preferred design is the
one that preserves deterministic regeneration without overwriting an explicit
human reschedule.

Required invariant: re-running the generation engine must not erase an
authorized assignment or rescheduled operational date.

---

## Calendar Read Contract

The UI must not query `calendar_events` directly from widgets.

### Calendar Range Read

Provide one canonical bounded RPC for a date range and filters. The response
should include:

- event identity, type, status, and provenance;
- scheduled date;
- nullable explicit manual-event `time_window` with canonical display values
  and timezone name;
- localized/server-provided titles;
- assignment identity and display name;
- customer identity and display name;
- service-location identity and display name;
- contract identity and number;
- optional product/contract-line summary required by the agenda;
- whether directions are available;
- working-day state and resolved window;
- whether the event conflicts with a day off;
- permission-derived available actions;
- total/count metadata needed by month cells;
- stable cursor/page metadata where applicable.

### Query Limits

- Default calendar query: visible month plus leading/trailing grid dates.
- Hard server date-range limit must be defined and tested.
- Day agenda must be bounded/paginated for pathological event counts.
- Search/filter queries use indexes and avoid per-row follow-up calls.
- Counts and rows must come from one consistent read contract or documented
  companion endpoints.
- Assigned-only users must never infer counts for other employees.

### Recommended Filters

- date range;
- event type;
- event status;
- assigned employee;
- participant employee;
- unassigned only;
- customer;
- contract;
- service location;
- source kind;
- working-day conflict;
- free-text search over safe event/customer/contract/location identifiers.

---

## UI Design Principles

### Desktop Calendar Page

The canonical desktop page is vertically split.

```text
┌──────────────────────────────────────────────────────────────┐
│ Calendar / التقويم         Filters                 Actions  │
├──────────────────────────────────────────────────────────────┤
│                    UPPER SECTION                              │
│  ‹ Previous       July 2026       Today       Next ›          │
│  ┌────┬────┬────┬────┬────┬────┬────┐                        │
│  │Sun │Mon │Tue │Wed │Thu │Fri │Sat │                        │
│  │    │    │ 12 │ 13 │ 14 │ 15 │ 16 │  event counts/badges   │
│  └────┴────┴────┴────┴────┴────┴────┘                        │
├──────────────────────────────────────────────────────────────┤
│                    LOWER SECTION                              │
│ Sunday 12 July 2026                                           │
│ Working hours: 08:00-17:00     6 events     1 unassigned     │
│ [event card/row]                                               │
│ [event card/row]                                               │
│ [event card/row]                                               │
└──────────────────────────────────────────────────────────────┘
```

Required behavior:

- Default selected date is today.
- Clicking a day changes the lower agenda without route navigation.
- Month navigation keeps filter state.
- Returning from an event/customer/contract detail restores selected date and
  filters when practical.
- Today, selected date, day off, and conflict states are visually distinct.
- Month cells show compact counts/badges, not unreadable full event cards.
- The lower section owns detailed event rows/cards.
- The selected-day header always shows working status.
- A day off displays `يوم إجازة` / `Day off` clearly.
- A 24-hour day displays `24 ساعة` / `24 hours`.
- A limited day displays the configured window.
- Month cells never display clock times. The agenda displays a time range only
  for an explicitly timed manual event.
- Empty days have a useful empty state and permission-aware create action.
- Loading, retry, partial failure, and permission-denied states are explicit.

### Day, Week, and Month Interpretation

The owner's split Month + Agenda experience is the primary Phase 7 surface.

- Month: upper month grid + lower selected-day agenda.
- Week: optional upper seven-day strip/summary + lower selected-day agenda.
- Day: lower agenda expanded for the selected day.

M6 may deliver Month + Agenda first, then Day/Week only after the primary flow
passes acceptance. Do not delay the useful calendar for a complex generic
calendar component.

### Event Row/Card

Each agenda item should show only operationally useful information:

- type/status;
- title;
- optional manual-event time range;
- customer;
- service location;
- contract number when linked;
- assigned employee or `Unassigned`;
- generated/manual indicator where useful;
- day-off conflict warning;
- directions availability;
- permission-aware action menu.

Do not show internal source keys or raw UUIDs.

### Mobile Calendar

Mobile uses the same hybrid domain contract.

- stacked compact month/date strip above agenda;
- selected-day agenda optimized for touch;
- assigned-only default for field employees;
- large Directions action;
- no desktop drag-and-drop dependency;
- reassignment controls hidden unless permitted;
- no Phase 8 completion controls in Phase 7.

---

## Milestone Overview

| Milestone | Name | Result |
|-----------|------|--------|
| M0 | Decisions, Scope Lock, and Reconciliation | Phase 7 rules are canonical and conflicts are resolved |
| M0.5 | Safety Snapshot and Rollback | Verified Phase 6 baseline and rollback evidence |
| M1 | Calendar and Working-Schedule Data Model | Generated/date-only events and per-weekday working windows are safely represented |
| M2 | Event Generation Engine | Contract events stay complete, idempotent, and operationally stable |
| M3 | Reminder Foundation | Date/working-day reminders are idempotent and timezone-safe |
| M4 | Calendar Read APIs | Bounded, filtered, permission-safe calendar data is available |
| M5 | Flutter Domain, Repository, Routes, and Navigation | Application layer is ready without widget-level database access |
| M6 | Desktop Calendar UI | Upper calendar and lower selected-day agenda work professionally |
| M7A | Manual Business Events & Internal Appointments | Company visits, meetings, tasks, activities, custom items, optional time, and participants are managed safely |
| M7B | Working Calendar Holidays & Exceptions | Holidays, closures, and exceptional working days override the weekly calendar safely |
| M8 | Assignment and Rescheduling | Employees can be assigned and dates moved through audited RPCs |
| M9 | Mobile Calendar | Touch-friendly assigned calendar works in Arabic and English |
| M10 | Route View and Directions | Daily geography is visible and native maps can open locations |
| M11 | Integration, Performance, and Hardening | Cross-module, concurrency, accessibility, and scale risks are closed |
| M12 | Verification and Phase Close | Automated and manual acceptance passes and Phase 7 closes |

---

## M0 - Decisions, Scope Lock, and Reconciliation

> Status: **Complete (2026-07-12).** Documentation/decision milestone only;
> no schema or application implementation was started.

### Goal

Make this file the canonical Phase 7 execution plan before schema or UI work.

### Work

1. Verify Phase 6 closure at migration `092`.
2. Confirm the current SQL, Dart, Flutter, and manual acceptance baseline.
3. Update older documents that still describe exact-time reminders or a broader
   conflicting MVP:
   - `BUILD_PLAN.md`;
   - `CONTRACTS_LOGIC.md`;
   - `DATABASE_SCHEMA.md`;
   - `MVP_SCOPE.md` if owner-approved scope exceeds view-only;
   - `RPC_SPEC.md` once RPC signatures are accepted.
4. Lock the original generated/date-only semantics and working-day rules in
   this file. The later 2026-07-15 owner revision extends manual events only.
5. Lock that tenant timezone is an owner-selected IANA setting with no inferred
   default.
6. Lock unconfigured seven-row schedule backfill with
   `working_schedule_configured = false` and no inferred values.
7. Lock dedicated `settings.calendar.view` and `settings.calendar.edit`
   permissions.
8. Lock initial configurable in-app reminder policies:
   - same working day;
   - previous working day;
   - in-app channel as the guaranteed Phase 7 channel.
9. Lock original-due/overdue/actual-execution semantics and require M1/M2
   storage so regeneration cannot erase a human override.
10. Lock one-outstanding-refill cadence and actual-completion/confirmed-coverage
    anchoring for the next refill.
11. Lock Month + selected-day Agenda as the M6 closure-critical desktop view;
    Day/Week presentations may follow within Phase 7 after that primary flow.
12. Record the first Phase 7 migration number: `093` (`092` already belongs to
    Phase 6 M13 covered-rental-month reads).
13. Defer map provider/package selection to its explicit M10 gate; display-only
    scope and privacy constraints are already locked.

### Acceptance

- At M0 closure, no exact-time requirement existed. This historical acceptance
  is superseded only for explicitly timed manual events by the 2026-07-15 M7A
  expansion; generated events remain date-only.
- Working-day behavior and day-off override behavior are explicit.
- Reminder rules no longer depend on a fabricated event time.
- Phase 7 versus Phase 8 boundaries are explicit.
- Unconfigured schedule/timezone behavior is recorded without defaults.
- Dedicated Calendar Settings permissions are recorded.
- Overdue events remain pending until trusted Phase 8 execution.
- Next refill generation is anchored to actual completion and confirmed
  coverage, not the missed planned date.
- Documentation sources no longer contradict the accepted scope.
- No schema implementation starts with unresolved generated-event reschedule
  semantics.

### Closure Record (2026-07-12)

- Phase 6 M13 closure evidence remains the functional baseline: SQL suites,
  Flutter analysis, 852 Flutter tests, AR/EN manual acceptance, and pollution
  cleanup were recorded green before Phase 7 planning.
- Repository inspection corrected the migration boundary: existing migration
  `092_phase_6_list_covered_rental_months_rpc.sql` belongs to Phase 6 M13, so
  Phase 7 starts at `093`.
- Owner-configured/unconfigured working schedule behavior is locked.
- Overdue and actual-execution refill cadence behavior is locked.
- Dedicated Calendar Settings permissions and configurable in-app reminder
  policies are locked.
- Canonical and supporting documentation conflicts were reconciled.
- Only Markdown documentation changed in M0; no SQL, Dart, Flutter, dependency,
  or generated file changed.
- M0.5 was the mandatory next gate and is now closed in the section below.

---

## M0.5 - Safety Snapshot and Rollback

> Status: **Complete (2026-07-12).** Safety artifacts are local/ignored under
> `supabase/.temp`; no Phase 7 migration or application implementation started.

### Goal

Create a trustworthy rollback point before the first Phase 7 migration.

### Work

1. Capture migration inventory through `092`.
2. Capture schema-only database dump when local tooling permits.
3. Record relevant row counts:
   - tenants;
   - tenant settings;
   - calendar events by source/type/status;
   - notifications;
   - contracts contributing future schedule rows.
4. Run the full Phase 6 SQL suite and final pollution gate.
5. Run Flutter analysis and the full Flutter test suite.
6. Write migration-by-migration rollback notes for planned Phase 7 migrations.
7. Confirm no manual or generated calendar rows have invalid tenant/customer/
   location relationships before M1.

### Acceptance

- The exact pre-Phase-7 state is reproducible.
- Rollback notes exist before applying Phase 7 migration `093`.
- Existing Phase 6 generated schedules are preserved.
- Baseline failures are resolved or documented before Phase 7 changes.

### Closure Record (2026-07-12)

- Database and filesystem migration inventories match: 92 migrations through
  `092_phase_6_list_covered_rental_months_rpc.sql`.
- Captured schema-only pre-093 dump:
  - `supabase/.temp/phase_7_m0_5_schema_pre_093.sql`;
  - 38,071 lines / 1,200,515 bytes;
  - SHA-256
    `4a598551128f6d3164ac4f8885710b79db84e1cb77d1e85378cc22233c00ed8e`.
- Captured migration inventory, database counts, integrity checks, and
  migration-by-migration rollback notes under `supabase/.temp`.
- Pre-test database counts:
  - tenants: 2;
  - tenant settings: 2;
  - calendar events: 0;
  - notifications: 0;
  - contracts contributing future schedule: 0.
- Calendar contract/customer/service-location/contract-line orphan checks: all
  zero.
- Full SQL regression passed, including concurrency, M12 handoff, M13 migration
  `092`, and final pollution gate.
- Post-test counts remained clean: migrations 92; calendar events,
  notifications, contracts, rental collection operations, orphan checks, and
  suspicious M11 test templates all zero.
- `flutter analyze`: no issues.
- `flutter test`: 888 passed.
- `git diff --check`: clean.
- M1 and migrations `093`–`094` are complete (2026-07-12).

---

## M1 - Calendar and Working-Schedule Data Model

**Status:** [x] Complete (2026-07-12). Migrations `093` and `094`; SQL Phase O;
Calendar Settings Flutter slice; route guards and nav.

### Goal

Represent date-only scheduling, tenant working windows, timezone behavior, and
future operational overrides safely.

### Work

1. Add normalized `tenant_working_days` with exactly seven weekday rows per
   tenant.
2. Add or confirm canonical tenant IANA timezone storage.
3. Add checks for day-off, limited-window, and 24-hour modes.
4. Backfill all existing tenants deterministically.
5. Add tenant-safe RLS and ACL.
6. Add read/update RPCs for the complete weekly schedule.
7. Ensure weekly updates are atomic: either all seven valid rows save or none.
8. Add server helper(s) to resolve a date into:
   - ISO weekday;
   - working/day-off state;
   - start/end window;
   - 24-hour state;
   - tenant-local label inputs.
9. Define the future date-override extension point without prematurely building
   holiday management UI. M7B later adopts that extension point.
10. Preserve `calendar_events.scheduled_time` as nullable legacy compatibility,
    and keep the M1-M6 paths date-only. M7A must use the separate optional
    start/end/timezone contract rather than repurposing this legacy field.
11. Add any schema needed to preserve original contractual date versus human
    operational reschedule.
12. Add `original_due_date` as required schedule provenance and prepare a
    trusted Phase 8 execution-fact handoff for `actual_completion_date`, actual
    delivered quantity, confirmed coverage, and confirmed `next_due_date`.
    Phase 7 must not write the execution facts.
13. Add reason/override fields or an operation ledger for day-off exceptions.
14. Add dedicated `settings.calendar.view` and `settings.calendar.edit`
    permissions without coupling them to event-view permissions.
15. Add a focused working-schedule settings repository/controller/screen or
    schedule it as the first vertical slice immediately after the RPC.
16. Audit every working-schedule update.
17. Document the final schema in `DATABASE_SCHEMA.md` and RPCs in `RPC_SPEC.md`.

### Acceptance

- [x] Every tenant has exactly seven weekday rows, initially unreviewed.
- [x] No weekday, weekend, time window, or timezone is inferred.
- [x] Configuration remains false until a manager atomically selects a valid IANA
  timezone and reviews all seven rows.
- [x] Friday/Saturday or any other day can independently be off, limited, or 24h;
  no weekend is hard-coded in application logic.
- [x] Half-day and full-day windows validate correctly.
- [x] Invalid/overnight/split windows are rejected clearly.
- [x] A date resolves in the tenant timezone consistently in SQL tests.
- [x] A working schedule can be read/updated only with accepted permissions.
- [x] Calendar viewers without settings permission cannot read Calendar Settings.
- [x] No working-hours reminder exists while configuration is incomplete.
- [x] Existing calendar events are not moved or deleted.
- [x] New Phase 7 events contain no fabricated time.
- [x] `original_due_date` is forced from `scheduled_date` on insert and is
  immutable; `calendar_refill_execution_facts` is internal-only in M1.

---

## M2 - Event Generation Engine

### Goal

Complete and harden the server-side generation pipeline needed by the calendar
without weakening Phase 6 provenance or idempotency.

**Status: complete (2026-07-13).** Migration
`095_phase_7_calendar_event_generation_engine.sql` applied; SQL Phase P and
concurrency suites registered. Final independent hardening expanded Phase P to
16 cases and covered deferred failure/retry, helper ACL, no-fact chain stops,
Rule 1 regeneration, multi-month `on_activation` billing, and queued-oil
reactivation materialization.

### Work

1. Reuse and extend M12 generation rather than replace it.
2. Preserve deterministic contract-generated source keys.
3. Ensure daily/batch generation maintains the accepted horizon.
4. Define the actual scheduled mechanism:
   - Supabase cron/pg_cron where supported; or
   - a secured scheduled Edge Function calling the tenant sync RPC.
5. Make scheduled execution observable:
   - run id;
   - started/completed timestamps;
   - tenant counts;
   - inserted/updated/removed counts;
   - error status without leaking sensitive payloads.
6. Verify generation after:
   - rental creation;
   - trial creation/extension/conversion/return;
   - contract suspension/reactivation/closure;
   - consumable schedule change;
   - rental collection coverage.
7. Ensure generation never overwrites assignment or authorized operational
   reschedule data.
8. Define how contractual due date and operational scheduled date coexist.
9. Change refill generation from blind future recurrence materialization to a
   confirmed-execution chain:
   - keep one outstanding refill event per cadence chain;
   - keep it pending/overdue until actual Phase 8 execution;
   - do not create the next refill from the missed planned date;
   - create the next refill only from trusted confirmed `next_due_date`.
10. Keep financial billing generation independent from refill execution.
11. Detect day-off conflicts but do not silently shift contractual dates.
12. Keep stock/accounting/payment side effects impossible.
13. Add concurrency contract tests for lifecycle, future trusted Phase 8
    confirmation, and batch generation.
14. Add cleanup/pollution gates for permanent SQL fixtures.

### Acceptance

- [x] Re-running generation creates no duplicates.
- [x] A generation retry after partial failure converges safely.
- [x] Generated rows retain assignment/reschedule overrides.
- [x] Contract suspension/reactivation/closure behavior remains correct.
- [x] Non-working-day due dates are visible as conflicts, not silently changed (M3 reminders still deferred).
- [x] A missed refill stays pending/overdue and blocks the next refill in that
  cadence chain.
- [x] Trusted actual completion plus confirmed coverage becomes the only next-refill
  anchor.
- [x] No invoice, voucher, journal, inventory movement, or visit completion is
  caused by generation.
- [x] Scheduled job execution is secured and observable (`run_scheduled_calendar_generation`, postgres-only).

---

## M3 - Reminder Foundation

### Goal

Create reliable date-based reminders anchored to working schedules.

### Work

1. Define reminder rules for date-only events.
2. Deprecate minute-offset interpretation for null-time Phase 7 events.
3. Add an idempotent reminder delivery/operation ledger.
4. Resolve tenant-local working anchors to UTC safely.
5. Generate enabled in-app reminders for:
   - event working-day start;
   - previous working-day start, if enabled.
6. Create no working-hours reminder while
   `working_schedule_configured = false` or timezone is absent; expose a clear
   setup-required state instead.
7. Recalculate pending reminders when date or assignment changes.
8. Preserve sent reminder history.
9. Cancel pending reminders when an event is completed/cancelled as appropriate.
10. Enforce recipient scope and active-user/employee relationships.
11. Add a scheduled reminder job with a short polling interval and overlap-safe
    locking/idempotency.
12. Define retry/backoff for failed delivery creation.
13. Keep external email/WhatsApp/SMS delivery behind accepted configuration and
    explicit later gates.
14. Test timezone boundaries, DST-capable IANA zones, 24-hour days, days off,
    and consecutive days off even if the initial tenant does not use DST.

### Acceptance

- A date-only event never becomes a midnight-based fake appointment.
- An unconfigured tenant receives no fabricated working-hours reminder.
- Either initial reminder policy can be disabled independently.
- The same reminder job can run twice without duplicates.
- Assignment/reschedule updates only pending reminder plans.
- A 24-hour day anchors consistently at tenant-local midnight.
- Consecutive days off resolve the previous working day correctly.
- In-app reminder rows are permission/tenant safe.
- External queued/sent status is not misrepresented.

### M3 closure (2026-07-13)

Migration `096_phase_7_calendar_reminders.sql` delivered the occurrence ledger,
cursor-paginated reconcile queue, DST-safe anchors, recipient-scoped notification
RLS, subtransaction delivery scheduler, and trigger-only settings enqueue. Final
hardening prevents stale promotion/delivery while a tenant cursor is incomplete,
revalidates event and recipient facts at delivery, preserves retry backoff during
refresh, isolates tenant reconcile failures, and records retry/failure counters
in the run ledger. SQL Phase Q (82 cases) plus parallel scheduler and reconcile
concurrency scripts are registered in `run_sql_suites.sh` / `.ps1`.

---

## M4 - Calendar Read APIs

### Goal

Expose one canonical, bounded, filterable calendar read model for desktop and
mobile.

### Status

**Closed (2026-07-13)** — migration `097_phase_7_calendar_read_rpc.sql`, SQL
Phase R (`phase_7_calendar_read_rpc.sql`, 68 cases).

### Work

1. Add range/count read RPC(s) with a documented maximum range.
2. Add selected-day agenda RPC or a shared range endpoint optimized for one day.
3. Enforce `calendar.view` versus `calendar.view_assigned` on the server.
4. Join safe display data for employee, customer, location, and contract.
5. Return resolved working-window/conflict state.
6. Return `original_due_date`, derived `is_overdue`, and `overdue_days`.
7. Return trusted actual-completion, confirmed-coverage, and next-date facts
   when Phase 8 has supplied them.
8. Include overdue pending events even when their due date is before the visible
   current/future range, using a documented overdue query/filter contract.
9. Return permission-derived available actions where practical.
10. Add filters listed in this plan.
11. Add stable ordering and pagination.
12. Avoid raw broad table exposure and N+1 client fetching.
13. Mask internal provenance metadata not needed by the UI.
14. Add indexes only after query-plan evidence.
15. Add tenant isolation, assigned scope, filter combination, range-limit, and
    pagination SQL tests.
16. Document JSON response contracts in `RPC_SPEC.md`.

### Implementation notes (M4)

- Public RPCs: `get_calendar_range_summary`, `list_calendar_events`.
- Shared core: `calendar_read_scoped_events` (set-based, static SQL).
- Max range 62 days; page size default 50, max 100.
- Dual-bucket cursors (`in_range`, `overdue_outside_range`) with
  `filters_hash` binding.
- Overdue uses `tenant_local_today` only; unconfigured schedule surfaces
  `schedule_unconfigured` without treating events as overdue.
- `REVOKE SELECT` on `calendar_events` for API roles; hardened
  `list_contract_upcoming_events_json` (internal).
- Phase R EXPLAIN gate on scoped read; no new `calendar_events` index required
  at current fixture volume.

### Acceptance

- [x] Manager/global and assigned-only results differ correctly.
- [x] Month counts do not leak other employees' events.
- [x] Selected-day rows and month counts are consistent.
- [x] Date limits and pagination are deterministic.
- [x] Overdue events remain visible with accurate tenant-local delay counts.
- [x] Arabic/English titles and linked display names are complete.
- [x] No widget will need direct Supabase table access.

---

## M5 - Flutter Domain, Repository, Routes, and Navigation

### Goal

Build the application layer and reachability before complex widgets.

### Status

**Closed / accepted (2026-07-14)** — Flutter domain/mappers/repository/
controllers/routes/navigation accepted after final acceptance correction.
No migration `098`.

### Corrective + final acceptance notes (M5)

Fixed gaps found after the initial land and final acceptance correction:
- Unconfigured `working_day` payloads after `jsonb_strip_nulls` (null mode /
  omitted boolean flags) map to unreviewed without `malformedResponse`.
- Logout/tenant identity change invalidates all request generations before reset.
- Independent in-range vs overdue pagination generations and error state.
- First `tenant_local_today` hydrates selected date (and month if needed) until
  explicit user selection.
- DST-safe inclusive day span via UTC ordinal components.
- Frozen filter/list collections on domain and state.
- Localized event type/status/schedule labels on the M5 shell.
- Strict present `execution_summary` per migrations 094/097:
  required non-null `calculated_next_due_date`; exactly one of
  `coverage_months` / `coverage_days` with value `> 0`; wrapper remains
  nullable.
- Initial overdue load failures expose independent `overdueErrorCode` (cleared
  on retry/success); pagination gens and stale-response protection preserved.
- Repository tests assert exact RPC names and parameter maps for
  `get_calendar_range_summary` and `list_calendar_events`.

### Deliverables

- Permission helpers: `canAccessCalendar`, tenant/assigned view, create/edit;
  settings helpers remain separate.
- Immutable date-only domain models + filters/validators matching `097`.
- Strict RPC mappers for `get_calendar_range_summary` / `list_calendar_events`.
- `CalendarRepository` + `CalendarException`; widgets never call Supabase.
- KeepAlive `CalendarController` with separate stale gens; single-day agenda;
  non-blocking setup warning; independent overdue error surface.
- Route `/calendar`, Field Ops nav after Today; office/field home split.
- EN/AR localization for shell, enums, filters, errors.

### Closure record (M5)

**Closed 2026-07-14** after final acceptance correction.
- Verification: `dart format` clean; focused calendar/routing/nav/exception
  suites **253** passed; `flutter analyze` clean; full `flutter test` **1030**
  passed; `git diff --check` clean.
- No migration `098`. No commit/push in the acceptance session. M6 later closed.

### Work

1. Add immutable domain models for:
   - calendar event summary/detail;
   - calendar range/day result;
   - filters;
   - working-day resolution;
   - weekly working schedule;
   - permissions/actions;
   - reminder summary where displayed.
2. Add strict RPC mappers with malformed-payload tests.
3. Add repository providers; widgets must not call Supabase directly.
4. Add validators for manual event, assignment, reschedule, and working schedule.
5. Add controllers/states for:
   - visible calendar range;
   - selected date;
   - filters;
   - selected-day agenda;
   - working-schedule settings;
   - mutation outcomes.
6. Add calendar-specific error mapping.
7. Add `/calendar` and settings route(s).
8. Add permission-aware route guards.
9. Add Calendar under Field Operations navigation.
10. Add ARB strings in Arabic and English; no hard-coded UI text.
11. Preserve selected date/filter state through navigation where practical.
12. Add controller, mapper, route, permission, and localization tests.

### Acceptance

- Calendar is reachable only with the correct view permission.
- Assigned-only users can reach the appropriate calendar surface.
- Working-schedule settings are guarded separately from calendar viewing.
- Domain/controller tests pass without rendering the full screen.
- No raw database maps escape the repository layer.
- No widget-level Supabase access exists.

---

## M6 - Desktop Calendar UI

**Status: closed / accepted (2026-07-15)** after the owner-approved visual/UX
corrective pass. The compact search/filter toolbar, filter popover, event
action menu, and direct month/year selectors are accepted. No migration `098`.
Next: M7A Manual Business Events & Internal Appointments (subsequently closed /
accepted on 2026-07-15 through migrations `098`/`099`).

### Goal

Deliver the professional upper-calendar/lower-agenda desktop experience.

### Work

1. Build the split page described in this plan.
2. Implement month navigation and Today action.
3. Default selected date to today.
4. Update the lower agenda when a date is selected.
5. Show compact event counts/status markers in month cells.
6. Show selected-day working status/window.
7. Highlight day-off events/conflicts.
8. Build filter controls appropriate for desktop density.
9. Build event rows/cards with linked customer/contract/location navigation.
10. Add permission-aware actions and unassigned indicators.
11. Add loading, retry, empty, blocked, and partial-error states.
12. Ensure keyboard navigation and visible focus.
13. Ensure Arabic RTL and English LTR layouts.
14. Add Day/Week presentation only after Month + Agenda acceptance, unless M0
    makes them mandatory for the same milestone.
15. Add widget tests at normal and narrow desktop widths.
16. Add screenshot/golden coverage only under the repository's accepted golden
    policy.

### Acceptance

- Clicking a calendar day updates the lower agenda in place.
- The page clearly shows day off, limited hours, full-day hours, and 24 hours.
- No fabricated appointment time appears; M6 predates optional-time manual
  creation and therefore continues to show only the accepted date-only data.
- Month navigation does not lose filters unexpectedly.
- Arabic and English layouts remain readable.
- Large event counts do not overflow the month grid or agenda.
- Back navigation from linked detail screens is safe.

**Delivered (including corrective acceptance):**
- Collision-safe `CalendarFilters` identity via deterministic sorted JSON
  (`canonicalQueryKey`) with adversarial delimiter/equals/Arabic tests.
- DST-safe calendar-day arithmetic (`addCalendarDays` / UTC ordinal spans);
  month-grid iteration and dense-summary validation no longer use
  `Duration(days:)`.
- Tenant-wide filter visibility from `canViewTenantCalendar(session)`;
  assigned-only users never see agent/unassigned filters while scope is
  loading; employee lookup requires tenant calendar + `warehouses.view`;
  forbidden fields stripped on scope/identity change.
- Customer-scoped service-location filter (customers.view; disabled until
  draft customer selected; cleared on customer change).
- Lookup lifecycle: identity resets, debounce cancel on dispose/identity
  change, request generations, slow-old/fast-new + tenant-switch races.
- Month-grid roving keyboard focus (arrows / Enter / Space) with gold focus
  ring; RTL-aware Prev/Next chevrons; Semantics EN/LTR + AR/RTL tests.
- Draft-only filters, `loadedSummaryQuery` alignment, dense summary
  validation, scoped retries + `isLoadingOverdue`, overdue panel, EN/AR chrome.
- Presentation split: controller / section loader / pagination / filter bar
  chips / lookup field under the ~350-line target.
- Clickable month and year selectors provide direct navigation while clamping
  the selected day for shorter target months.

**Prior automated verification (retained as history):**
`dart format` + `flutter gen-l10n` clean; focused calendar **212** passed;
routing + AppShell nav **93** passed; `flutter analyze` **0** issues; full
`flutter test` **1091** passed; `git diff --check` clean. No `098`.

**Final owner visual acceptance (2026-07-15):** compact search + funnel
popover; lookup rows removed; exact-ID filters sanitized; clickable event
action menu; direct month/year selection; screenshots in
`build/screenshots/calendar_*.png`. Final verification: calendar **223**,
screenshot harness **5**, routing/AppShell **93**, full Flutter **1102**,
analyze 0, diff check clean. **M6 closed / accepted.** No commit/push unless
requested.
---

## M7A - Manual Business Events and Internal Appointments

**Status: closed / accepted (2026-07-15).** Migration `098` is the enum-only
barrier; migration `099` contains the manual-event body, RPC/read/reminder
extensions, and lifecycle contracts. Flutter implementation, complete SQL and
Flutter regressions, and owner AR/EN visual acceptance are complete.

### Goal

Expand Calendar from contract due-date viewing into controlled company-wide
appointment management without weakening generated-event provenance or pulling
Phase 8 execution into Phase 7.

### Work

1. Add atomic, idempotent manual-event create/edit/cancel RPCs.
2. Support the initial categories:
   - customer visit;
   - internal meeting;
   - internal task/reminder;
   - internal activity/training;
   - custom.
3. Require `scheduled_date`, category, and bilingual/fallback title rules;
   support optional notes and optional free-text team/location.
4. Support optional customer, service location, and contract relationships with
   strict same-tenant and parent/child alignment validation. Reading linked
   customer/contract detail still requires that module's own view permission.
5. Add optional `Set time` / `تحديد وقت` behavior for manual events only:
   - date-only: start/end/timezone are all null;
   - timed: start/end/timezone are all non-null;
   - resolve local input on the server using the tenant-confirmed IANA timezone;
   - require end after start and the same local `scheduled_date`;
   - reject overnight windows in v1;
   - keep legacy `scheduled_time = null`.
6. Return nullable typed `time_window` data; do not leak raw device-local time or
   make Flutter infer timezone conversions independently.
7. Add `calendar_event_participants` (or reviewed equivalent) for meetings and
   activities. Participants are not the event's assigned/responsible employee.
8. Provide a permission-safe active-employee participant lookup owned by
   Calendar; do not reuse unrelated `warehouses.view` as appointment authority.
9. Extend assigned-only reads so an employee sees events assigned to them or
   explicitly listing them as a participant, including counts and pagination.
10. Detect participant/time overlaps and return a warning requiring explicit
    confirmation; do not hard-block. Do not implement room conflict checks.
11. Warn/require explicit recorded override for creation on a resolved closure
    or non-working day.
12. Protect lifecycle and provenance:
    - only `source_kind = manual` is mutable through these RPCs;
    - generated rows cannot use manual mutation paths;
    - cancel requires a non-empty reason;
    - no hard delete in M7;
    - category is immutable after creation unless a separately reviewed safe
      transition matrix is accepted;
    - version/optimistic-concurrency and audit are mandatory.
13. Editing time within the same date belongs to M7A. Moving the event to a
    different date and assignment/reassignment remain M8.
14. Build desktop create/edit/detail/action UI with date-only as the default and
    optional-time/participants shown only when enabled and permitted.
15. Update the agenda to separate timed appointments from date-only tasks/due
    items. Month cells continue to show counts only.
16. Treat `task/reminder` as an event category only; do not add custom
    notification timing without a separate accepted reminder design.
17. Add SQL/Dart/widget tests covering tenant isolation, permissions,
    idempotency, DST/timezone boundaries, malformed time triples, overlap
    warnings, participant visibility, lifecycle, generated-row protection, and
    absence of financial/stock/visit side effects.

### Acceptance

- Each accepted company event category can be created as a date-only item.
- A manual event may optionally carry a valid same-day tenant-timezone time
  window; disabling time clears the complete time triple atomically.
- A timed item is ordered/shown only in the agenda, never as clock text in a
  month cell.
- Participant and assigned-employee concepts remain separate and tenant-safe.
- Assigned-only visibility includes assignment or explicit participation and
  leaks no counts for unrelated employees.
- Cross-tenant or misaligned customer/location/contract/employee combinations
  are rejected.
- Retry/double-submit does not duplicate the event.
- Conflict warnings require explicit confirmation but do not become a hard
  scheduling engine.
- Cancellation preserves audit history; no M7 hard delete exists.
- Manual mutations create no financial, stock, GPS, photo, payment, or visit
  completion effects.

### Delivered and closure evidence

- Accepted categories: customer visit, internal meeting, internal task/reminder,
  internal activity/training, and custom event.
- Manual events support date-only scheduling or an explicit same-day time
  window; generated events never receive fabricated clock times.
- Customer/location/contract alignment, participant lookup/visibility,
  assigned-only participation, warning-only overlap confirmation, and
  non-working-day confirmation are permission- and tenant-safe.
- Internal meetings support physical/online modes, optional HTTPS join link,
  organizer-controlled lifecycle, participant notices, and idempotent retries.
- Create/update/cancel/mark-done or close flows use optimistic concurrency,
  cancellation reasons, immutable audit snapshots, and generated-row
  protection. No hard delete or Phase 8 execution side effects were added.
- Reminder reconciliation preserves plan identity and immutable delivery
  history; meeting-notice emission is atomic and concurrency-tested.
- Desktop UI includes create/edit forms, customer-visit relations, participant
  selection, timed/date-only agenda grouping, permission-aware event actions,
  join meeting, close/done confirmation, destructive cancellation, and AR/EN
  RTL/LTR plus narrow-layout support.
- Final gates: screenshot harness **24** passed; focused Calendar + AppShell
  **264** passed; routing guards **71** passed; full Flutter **1121** passed;
  `flutter analyze` clean; complete SQL suite passed; `git diff --check` clean.
- The owner accepted the corrected visual evidence on 2026-07-15. Live
  authenticated AR/EN captures remain a preferred pre-release smoke check, not
  a milestone blocker. A partially visible participant row in one harness image
  is retained only as non-blocking polish if scrolling has no overflow.
- M7B, migration `100`, M8 mutations, and Phase 8 execution were not started.

---

## M7B - Working Calendar Holidays and Exceptions

**Status:** **CLOSED / ACCEPTED (2026-07-17).** Migration
`100_phase_7_working_date_exceptions.sql`, automated SQL/Flutter gates, the
12-frame screenshot harness, and owner visual acceptance are complete.

**Corrective pass (2026-07-17):** revoked all five public RPCs from
`PUBLIC`/`anon`; made unconfigured schedules retain date-exception warnings;
aligned server validation with table limits and strict JSON/date/cursor
contracts; made kind editable under the same versioned update RPC; added an
explicit year selector; froze first-page bounds/limit for pagination; added
load/pagination/mutation generations so stale tenant/logout requests cannot
overwrite current state; froze state collections and expanded regression tests.

### Goal

Let authorized settings users represent real company non-working and exceptional
working dates without misclassifying them as ordinary appointments.

### Work

1. Add a tenant-safe `tenant_working_date_exceptions` model with RLS/ACL,
   versioning, audit, and active/cancelled lifecycle.
2. Support inclusive date ranges, localized title/fallback, optional notes, and
   these kinds:
   - official holiday;
   - company closure;
   - exceptional working day.
3. For exceptional working days, support validated working-hours or 24-hour
   mode; reject split and overnight windows in v1.
4. Make a date exception override the tenant weekly schedule for date
   resolution, calendar labels, conflicts, and reminder anchors.
5. Reject active overlapping exceptions deterministically.
6. Keep event facts unchanged: adding a holiday/closure never deletes, cancels,
   or silently reschedules an event; affected events display conflicts.
7. Recalculate pending reminders only; sent history remains immutable.
8. Require `settings.calendar.view/edit` rather than event-view permissions.
9. Build a focused settings UI to list, create, edit, cancel, and inspect
   exception ranges in Arabic/English.
10. Add SQL/Flutter tests for range boundaries, precedence, overlaps,
    timezone/DST behavior, permission separation, reminder recalculation,
    conflicts, audit, and tenant isolation.

### Acceptance

- A holiday or company closure overrides the weekly schedule and is visibly
  distinct from an ordinary day off.
- An exceptional working day can reopen a weekly day off with accepted hours.
- Exceptions never appear as fake appointment cards.
- Active overlaps are rejected; cancellation restores deterministic resolution.
- Existing events remain in place and show conflicts until an authorized user
  chooses a later M8 reschedule action.
- Only Calendar Settings permissions can manage exceptions.

---

## M8 - Assignment and Rescheduling

### Goal

Support professional office dispatch while preserving event provenance.

### Work

1. Add assign/reassign RPC with tenant-safe active employee validation.
2. Add audited date-reschedule RPC with mandatory reason; preserve or validate
   an existing manual time window against the target tenant-local date.
3. Add day-off override behavior.
4. Preserve original contractual/generated due date.
5. Protect source kind/key and generated metadata.
6. Make mutations idempotent where retries are possible.
7. Add optimistic concurrency/version protection so stale screens do not
   overwrite newer assignments/reschedules.
8. Recalculate pending reminders atomically.
9. Preserve sent reminders and audit history.
10. Add desktop assignment and reschedule dialogs.
11. Optional drag-and-drop may call the same RPC after a confirmation/reason
    flow; it must not bypass validation.
12. Add simultaneous assignment/reschedule concurrency tests.

### Acceptance

- Reassignment is visible to old/new assigned scopes correctly.
- Rescheduling changes the operational date only and records a reason.
- Regeneration does not erase the change.
- Stale concurrent updates fail clearly rather than silently winning.
- Pending reminders move; sent history remains.
- Drag-and-drop, if included, has identical server behavior to the dialog.

---

## M9 - Mobile Calendar

### Goal

Provide a touch-friendly date and assigned-agenda experience without pulling
Phase 8 execution into Phase 7.

### Work

1. Reuse M4 APIs and M5 domain models.
2. Build compact mobile month/date navigation above the agenda.
3. Default field users to assigned events and today.
4. Show customer, service location, contract, status, and directions action.
5. Show working-day label/window and show a clock range only for explicitly
   timed manual events.
6. Provide filters appropriate to permission and screen width.
7. Hide office mutations from users without permission.
8. Support refresh/retry and session/permission changes.
9. Test small Android widths, Arabic RTL, English LTR, text scaling, and touch
   targets.
10. Keep GPS/photo/refill/payment/completion controls out of this milestone.

### Acceptance

- Assigned employees see only their permitted events.
- Today and another selected date work without layout overflow.
- Directions availability is clear.
- Day-off conflicts are visible.
- No Phase 8 action is implied or accidentally available.

**Closure (2026-07-19):** final automated and owner visual gates passed after
the content-width responsive correction, non-overlapping mobile create control,
assigned-only evidence correction, and regenerated 12-frame M9 screenshot set.
M9 is **CLOSED / ACCEPTED**. M10 subsequently closed on 2026-07-19; see its
implementation and closure record below.

---

## M10 - Route View and Directions

### Goal

Help users understand daily geography and open reliable native directions.

### Work

1. Select a minimal maintained map package after license/platform review.
2. Add direct `url_launcher` dependency for supported native directions if
   selected.
3. Build a display-only daily map for one employee/date.
4. Plot only events with resolved service-location coordinates.
5. Provide a list fallback for missing coordinates or map failure.
6. Clearly label missing/unresolved locations.
7. Avoid exposing unrelated customer locations to assigned-only users.
8. Open native directions using validated coordinates first, with accepted
   Google Maps URL fallback.
9. Do not claim route optimization or draw a misleading optimized path.
10. Add platform-safe URI tests and widget/controller tests.
11. Document privacy, API-key, tile-provider, attribution, and offline behavior.

### Acceptance

- The map contains only events visible to the current user.
- A location with coordinates opens native directions.
- Missing coordinates degrade gracefully.
- Route View is explicitly display-only.
- No customer/location data leaks through markers, counts, or map bounds.

### Implementation record (2026-07-19)

**Status: `M10 CLOSED / ACCEPTED` (2026-07-19).**

Delivered:

- Migration `102_phase_7_calendar_route_view.sql` with
  `get_calendar_route_day`, `list_calendar_route_employees`,
  `get_calendar_event_directions`, and a forward replace of
  `calendar_read_scoped_events` so `directions_available` /
  `can_open_directions` cover mapped **or** allowlisted URL (`url_only`)
  without exposing coords/URL in `list_calendar_events`.
- Route membership = assignee or participant only (not creator-only /
  unassigned). Caller ACL via `assert_calendar_event_view`; managers with
  `tenant_wide` do not need the assigned-only visibility helper for
  directions.
- Flutter Route View at `/calendar/route?date=YYYY-MM-DD`,
  `flutter_map` 8.3.1 + `latlong2` 0.10.1, FakeCalendarMapSurface screenshots,
  Directions launcher + on-demand directions RPC.
- Map provider / tile policy: `docs/PHASE_7_M10_MAP_PROVIDER.md`.
- Migrations `093`–`101` unchanged. No Phase 8. No Operations Map for
  rented/trial devices (Phase 10).

Final closure evidence:

- Owner accepted the final 17-frame M10 visual evidence set after the
  micro-corrective pass.
- `flutter analyze` clean; full `flutter test` **1366 passed**; M10 SQL suite
  `phase_7_calendar_route_view.sql` passed; `git diff --check` clean.
- Apple Maps uses its official HTTPS destination URL and is always offered on
  iOS; `url_only` offers Browser only; Arabic RTL day arrows and tile Retry
  contrast were corrected.
- iOS/Android installed-app smoke was skipped because no device session was
  available; it remains a pre-production smoke check, not an M10 closure
  blocker.
- The full SQL runner still reaches a pre-existing, unrelated reminder-suite
  FK failure (`fk_calendar_events_assigned_agent` / `v_cross_employee`); retain
  it as a known issue for M11/M12. No M10 SQL regression was observed.

---

## M11 - Integration, Performance, and Hardening

### Status

**`M11 CLOSED / ACCEPTED` (2026-07-19).**

Automated gates completed: Case 26 reminders (FK + Assignment RPC), Phase U
assignment wired into full SQL runner, cross-module + performance + pollution
suites (pre baseline before Phase 6/7 + post after Phase W with negative
self-test), CalendarRouteScope deep links, session identity hardening,
a11y/visual evidence. Migration `103` created from Gate D/F evidence (unbound
`calendar_read_scoped_events` JSON fan-out exceeded range-summary P95 ceiling;
lightweight summary facts + date bounds + `(tenant_id, scheduled_date)` index).
List P95≈1023ms (corrective re-measure; was ≈1017ms) passes hard ceiling 3000ms
but misses optimization target 800ms (documented; no additional migration in
the Final Corrective Pass; `103` unchanged).

**Final Corrective Pass (2026-07-19):** invalid-scope zero reads; date-only
without empty banner; session URL clear on identity switch; mutation identity
guards + delayed tests; single customer/contract entries; 13 production
screenshot PNGs; real pre/post pollution gate. Verification: analyze clean;
full Flutter **1417**; SQL runner green; perf 2+20 passed; `093`–`102`
checksums unchanged. **Pollution micro-corrective (same day):** strict count
equality for all 11 tables, Phase W.5 audit-journal reclaim, baseline table
dropped after success + runner EXIT/finally cleanup. The owner explicitly
accepted M11 on 2026-07-19. M8 Flutter was later accepted independently
(**`M8 FLUTTER CLOSED / ACCEPTED`**, Gate D **PASS / OWNER ACCEPTED**,
2026-07-19).

### Goal

Close cross-module, scale, security, concurrency, and usability gaps before
final acceptance.

### Work

1. Verify contract lifecycle to calendar propagation end to end.
2. Verify working-schedule changes and reminder recalculation behavior.
3. Verify Customer 360/contract links into calendar and safe return navigation.
4. Verify assigned permissions after employee reassignment/deactivation.
5. Benchmark month range and selected-day reads with realistic row counts.
6. Inspect query plans and add justified indexes only.
7. Test concurrent generation, manual create retry, assignment, reschedule, and
   reminder polling.
8. Test timezone/date boundaries.
9. Test non-working day, 24-hour day, half-day, missing schedule, and consecutive
   days off.
10. Test event counts and filters for information leakage.
11. Run accessibility checks:
    - keyboard;
    - screen-reader labels;
    - contrast;
    - text scaling;
    - touch targets.
12. Verify no direct generated-row mutation path exists.
13. Verify no scheduled action creates financial/stock/visit side effects.
14. Add cleanup scripts and final baseline-pollution gate.

### Acceptance

- Calendar reads remain responsive at accepted scale.
- No tenant or assigned-scope leakage exists.
- Concurrent operations converge or fail clearly.
- Accessibility and bilingual layout gates pass.
- Phase 6 regressions remain green.
- No hidden Phase 8 behavior has entered Phase 7.

---

## M12 - Verification and Phase Close

### Goal

Prove the complete Phase 7 workflow in automated and manual Arabic/English
acceptance, then close the phase.

### Required SQL Tests

- weekly working-schedule constraints and atomic update;
- unconfigured seven-row schedule, absent timezone, and zero reminder creation;
- dedicated Calendar Settings permissions independent from event viewing;
- timezone resolution;
- generated/date-only enforcement and optional manual-time invariants;
- tenant isolation;
- global versus assigned-only reads;
- contract generation idempotency;
- lifecycle propagation;
- overdue derivation from `original_due_date` in tenant-local date;
- one-outstanding-refill enforcement;
- no next refill before trusted actual completion;
- actual-completion/confirmed-coverage next-date anchoring contract;
- manual next-date override permission/reason/audit contract;
- generation/reschedule coexistence;
- day-off conflict behavior;
- company manual-event category, idempotency, alignment, time-window,
  participant, lifecycle, and conflict-warning behavior;
- holiday/closure/exceptional-working-day precedence, overlap rejection, and
  settings-permission separation;
- assignment/reassignment;
- reschedule audit and optimistic concurrency;
- reminder deduplication and recalculation;
- cancelled/completed reminder behavior;
- read filters, counts, bounds, ordering, and pagination;
- no financial/inventory/visit side effects;
- concurrency suites;
- fixture cleanup and pollution gate.

### Required Flutter Tests

- strict mappers;
- validators;
- repository argument/response contracts;
- controller loading/error/retry/mutation states;
- route and permission guards;
- navigation visibility;
- working-schedule settings UI;
- desktop calendar date selection;
- month navigation and filters;
- selected-day agenda;
- day-off/half-day/full-day/24-hour labels;
- manual company-event form, optional time window, participant picker, and
  cancel-with-reason lifecycle;
- working-date exception settings and precedence states;
- assignment/reschedule flows;
- mobile assigned agenda;
- directions availability and URI behavior;
- Arabic/English and RTL/LTR;
- narrow widths and text scaling;
- back navigation/state restoration.

### Required Manual Acceptance

Run the same core story in English and Arabic:

1. Configure seven independent weekdays, including:
   - one day off;
   - one half-day;
   - one normal day;
   - one 24-hour day.
2. Before configuration, verify the setup-required banner and absence of
   working-hours reminders.
3. Open Calendar and verify the split upper/lower layout.
4. Select multiple dates and verify the lower agenda changes.
5. Create/activate a contract and observe generated events.
6. Verify generated and untimed events show no fabricated time; create one
   explicitly timed manual event and verify its range appears only in the
   selected-day agenda.
7. Verify selected-day working labels.
8. Create examples of the accepted company event categories, including an
   internal meeting with participants and a date-only task/reminder.
9. Create/cancel a holiday or closure and verify it overrides weekly resolution
   without becoming an appointment card.
10. Attempt an event on the exception date and confirm the conflict/override
    trail.
11. Verify participant overlap is warning-only and assigned-only visibility
    includes assignment or participation.
12. Assign and reassign an employee.
13. Reschedule a generated event with a reason.
14. Re-run generation and verify the reschedule/assignment is preserved.
15. Let a refill due date pass; verify it stays pending/overdue with the original
    due date and delay count, and verify no later refill is generated.
16. Simulate the trusted Phase 8 handoff contract with 500 ml per cycle, 1500 ml
    delivered, completion on 2026-08-04, and confirmed three-month coverage;
    verify the next due proposal/confirmed date is 2026-11-04 without Phase 7
    stock mutation.
17. Verify the assigned employee's mobile view.
18. Verify enabled reminder creation without duplicates and disabled policies
    create none.
19. Open native directions for a resolved service location.
20. Verify missing coordinates degrade safely.
21. Verify calendar actions did not alter stock, invoices, vouchers, journals,
    or visit completion.

### Closure Gates

- clean database reset;
- all SQL suites green;
- concurrency suites green;
- Dart format clean;
- Flutter analysis clean;
- all Flutter tests green;
- manual AR/EN acceptance green;
- no permanent test pollution;
- documentation updated;
- `ai_memory.md` closure record written;
- Phase 7 status updated in `BUILD_PLAN.md` only after every gate passes.

### Acceptance

- All M0-M12 criteria pass.
- The owner accepts the desktop split calendar and selected-day agenda.
- The phase is not marked complete with skipped reminder, permission, timezone,
  or bilingual gates.
- Phase 8 receives reliable assigned/participating schedule data, including
  explicit manual time windows where present, without inheriting hidden Phase 7
  inconsistencies.

---

## Planned Migration Sequence

Final filenames are locked milestone-by-milestone. The expected sequence starts
after Phase 6 migration `092`:

| Expected migration | Milestone | Purpose |
|--------------------|-----------|---------|
| `093_phase_7_calendar_working_schedule.sql` | M1 | Weekly schedule, timezone, constraints, RLS/ACL |
| `094_phase_7_calendar_event_model.sql` | M1 | Date-only/reschedule/override model hardening |
| `095_phase_7_calendar_event_generation_engine.sql` | M2 | Confirmed-execution refill chain, deferred lifecycle reconcile, batch ledger |
| `096_phase_7_calendar_reminders.sql` | M3 | Reminder rules/ledger/job foundation |
| `097_phase_7_calendar_read_rpc.sql` | M4 | Range/day/filter read contracts |
| `098_phase_7_manual_business_event_types.sql` | M7A | Enum ADD VALUE only (`customer_visit`, `internal_meeting`, `internal_task`, `internal_activity`) |
| `099_phase_7_manual_business_events.sql` | M7A | Optional time windows, participants, lifecycle RPCs, read/reminder extensions |
| `100_phase_7_working_date_exceptions.sql` | M7B | Holidays, company closures, exceptional working days, resolution precedence |
| `101_phase_7_calendar_assignment_rpc.sql` | M8 | Assignment/reschedule/concurrency behavior |
| `102_phase_7_calendar_route_view.sql` | M10 | Route View + directions RPCs (shipped) |
| `103_phase_7_calendar_m11_hardening.sql` | M11 | Evidence-gated: composite `(tenant_id, scheduled_date)` index; date-bounded `calendar_read_scoped_events`; `calendar_read_summary_facts` + range `get_calendar_range_summary`; list/route_day pass date bounds |

Do not reserve empty migrations merely to preserve this table. If one milestone
needs multiple transaction boundaries or enum commits, update the plan before
implementation.

---

## Risk Register

### Risk 1 - Time Ambiguity or Fabricated Generated Times

Mitigation:

- `scheduled_date` is canonical;
- generated and untimed events keep all optional time fields null;
- legacy `scheduled_time` remains null;
- timed manual events require an explicit start/end/timezone triple resolved by
  the server from the tenant's confirmed IANA timezone;
- no device-timezone inference, overnight windows, or time text in month cells;
- date-only reminders continue to use working-day anchors.

### Risk 2 - Working-Hour Settings Become Hard-Coded

Mitigation:

- seven normalized tenant rows;
- no fixed weekend assumptions;
- server-side date resolution;
- focused settings UI in M1.

### Risk 3 - Regeneration Erases Human Rescheduling

Mitigation:

- separate contractual/original date from operational date or use a protected
  override record;
- preserve source key;
- concurrency and regeneration tests.

### Risk 4 - Calendar Event Is Mistaken For Completed Work

Mitigation:

- no stock/accounting/payment effects;
- Phase 8 owns proof and completion;
- explicit UI language;
- negative SQL assertions.

### Risk 5 - Reminder Duplication

Mitigation:

- unique delivery idempotency key;
- overlap-safe job;
- immutable sent history;
- retry/concurrency tests.

### Risk 6 - Tenant or Assigned-Scope Leakage

Mitigation:

- server-side scope enforcement;
- no client tenant ids;
- scoped counts and map markers;
- adversarial SQL/widget tests.

### Risk 7 - Calendar UI Becomes A Generic Component Project

Mitigation:

- primary Month + selected-day agenda first;
- compact month cells;
- detailed data only in lower agenda;
- Day/Week modes follow operational need.

### Risk 8 - Map Scope Expands Into Routing Platform

Mitigation:

- display-only markers;
- native directions per location;
- no optimization/ETA promise;
- explicit fallback list.

### Risk 9 - Settings Scope Expands Uncontrollably

Mitigation:

- build only working days/hours, required timezone, and M7B date exceptions;
- keep broader company settings redesign out of Phase 7;
- keep leave management, room inventory, and general HR scheduling out.

### Risk 10 - Date/Timezone Drift

Mitigation:

- IANA tenant timezone;
- server-side conversion;
- no implicit device/server timezone;
- boundary and DST-capable-zone tests.

### Risk 11 - Direct Mutation Of Generated Rows

Mitigation:

- trusted provenance guard remains;
- assignment/reschedule through dedicated security-definer RPCs;
- source fields immutable;
- delete forbidden for generated rows.

### Risk 12 - Missed Refills Spawn False Future Cycles

Mitigation:

- preserve `original_due_date`;
- derive overdue without automatic move/completion;
- one outstanding refill per cadence chain;
- advance only from trusted actual completion and confirmed coverage;
- keep billing recurrence independent;
- negative generation and Phase 8 handoff contract tests.

---

## Estimated Delivery

Approximate focused effort after M0 decisions are accepted:

| Work | Estimate |
|------|----------|
| M0-M0.5 | 1-2 days |
| M1 | 3-5 days |
| M2 | 3-5 days |
| M3 | 3-5 days |
| M4 | 3-5 days |
| M5 | 2-4 days |
| M6 | 4-7 days |
| M7A | 5-8 days |
| M7B | 3-5 days |
| M8 | 3-5 days |
| M9 | 3-5 days |
| M10 | 3-6 days |
| M11 | 3-5 days |
| M12 | 3-5 days |

Total: approximately **42-70 focused development days** before contingency.

This is larger than the older two-week roadmap estimate because professional
delivery includes working schedules, timezone-safe reminders, permission-scoped
read APIs, desktop/mobile UI, mutation concurrency, map privacy, bilingual
acceptance, and regression protection. Milestones may close faster when the M12
Phase 6 foundation can be reused without corrective work.

---

## Starting Point For Implementation

M0–M12 are closed/accepted for their scopes, including
**`M8 FLUTTER CLOSED / ACCEPTED`** (Gate D **PASS / OWNER ACCEPTED**,
2026-07-19). **M11 is `CLOSED / ACCEPTED`** (2026-07-19).
Migrations `093`–`103` remain byte-unchanged / checksummed; M12 adds evidence-
gated **`104`** (route event contract fix for Item 20).
**M12 and Phase 7 status:** `CLOSED / ACCEPTED`.
Gates D/E/F are **`PASS / OWNER ACCEPTED`**; Gate G and Final Gate H are
**PASS** through migration `104`. Gate F acceptance is based on physical iOS
and Android Emulator evidence. Physical Android smoke remains a required
pre-production obligation and is not claimed by this packet. Phase 8 is not
started.
Operations Map for rented/trial devices remains Phase 10.

Do not begin external reminder delivery until:

- in-app reminder idempotency passes;
- recipient mapping is accepted;
- credentials and retry behavior are explicitly approved.

Do not begin route-map implementation until:

- calendar visibility scope is proven;
- the map package/provider and privacy terms are accepted;
- missing-coordinate fallback is designed.

The M7A enum/key names, time schema, participant lookup contract, and lifecycle
RPC shapes are implemented and accepted. M7B migration `100` and M8 migration
`101` are on disk with SQL/Flutter coverage. M9 adds the mobile calendar
surface without new SQL.
