# FIELD_OPS.md — Mobile App, Field Operations & Calendar

> This document covers everything the field agent does, from the moment they wake up to the moment they reconcile their van at end of day.
> Updated 2026-05-16 to resolve conflicts: field access is permission-based, not fixed-label-based; KWD examples use the tenant's default currency at runtime.

---

## 1. Who Uses the Mobile App?

Only users with field-operation permissions, such as `visits.view_assigned`, `visits.complete_refill`, or `contracts.create_mobile`.

**Managers usually do not use the mobile app for daily work.** They use desktop. They may install mobile for occasional checks but their primary tools are on desktop.

The mobile app enables data entry only for users with the required mobile permissions. Other users see only the screens their permissions allow.

---

## 2. Bottom Navigation (Field Agent)

5 tabs:

| Tab | Icon | Purpose |
|-----|------|---------|
| **Today** | calendar-day | List of today's tasks |
| **Calendar** | calendar | Day/week/month views, future planning |
| **Customers** | users | Search & view customer details |
| **Van Stock** | box | Current stock in agent's van |
| **More** | dots | Profile, settings, sign out |

---

## 3. The "Today" Screen — The Default Home

This is what the agent sees first thing in the morning.

```
┌─────────────────────────────────────────┐
│  ← Hayat Secret                     ⚙   │
├─────────────────────────────────────────┤
│                                         │
│  Today — Friday, 15 May 2026            │
│                                         │
│  ✅ 3 of 7 visits completed             │
│  💰 KWD 87.500 collected                │
│  📜 1 new contract                       │
│                                         │
│  ────────────────────────────────────   │
│                                         │
│  📍 Cafe Bloom · Refill                 │
│      Salmiya Block 5                    │
│      [ Start ]                          │
│                                         │
│  📍 10:00  Mr. Khalid · Collection      │
│      Salwa Block 2                      │
│      [ Start ]                          │
│                                         │
│  📍 Pearl Tower Hotel · Refill          │
│      Sharq                              │
│      [ Start ]                          │
│                                         │
│  ✓ 12:30  Sahara Restaurant · Done     │
│  ✓ 14:00  Adel Holding · Done           │
│                                         │
└─────────────────────────────────────────┘
│ 🏠   📅   👤   📦   ⋯                   │
```

### 3.1 Visit Card Anatomy
- Time
- Customer name
- Visit type (Refill / Collection / New Contract / etc.)
- Area / address
- Status indicator (pending / in progress / done)
- Tap → opens visit screen

### 3.2 Sort Order
1. In-progress visits first
2. Then upcoming, by scheduled time
3. Then completed (collapsed at bottom; tap to expand)

---

## 4. The Refill Flow — Most Common Daily Task

```
[Tap a refill visit card]
        │
        ▼
┌─────────────────────────────────────────┐
│  ← Refill — Cafe Bloom                  │
├─────────────────────────────────────────┤
│  Customer: Cafe Bloom                   │
│  Site: Salmiya branch                   │
│  Contract: CON-2026-00042 (active)      │
│                                         │
│  Address: Salmiya Block 5, Street 8     │
│  📍 [Open in maps]                       │
│                                         │
│  ──────────────────────────────────     │
│  Device: Diffuser Model X               │
│  S/N: HS-DEV-00027                      │
│  Last refill: 03 Apr 2026                │
│                                         │
│  Outstanding balance: KWD 25.000  ⚠     │
│  (2 unpaid invoices)                    │
│                                         │
│             [ Begin visit ]             │
└─────────────────────────────────────────┘
```

### 4.1 Step 1: Begin Visit
Tap "Begin visit" → app:
1. Requests GPS permission if not granted
2. Captures `check_in_lat`, `check_in_lng`
3. Compares against the visit's `service_location_id` coordinates, falling back to the contract location snapshot when needed
4. Uses tenant `gps_accuracy_threshold_m` plus the captured device accuracy to decide match
5. If within range: verified
6. If outside range: warning shown, reason required to proceed, and Manager sees the flag in reports

Visit detail should also expose a "Directions" action that opens the native maps app using the service-location coordinates. This is a `url_launcher` deep link, separate from the later internal operations map.

### 4.2 Step 2: Refill Form

```
┌─────────────────────────────────────────┐
│  ← Refill — Cafe Bloom                  │
├─────────────────────────────────────────┤
│  📍 GPS verified ✓ (32m from contract)  │
│  ⏱  Started at 09:32                    │
│                                         │
│  Oil:     [ Hilton ▼ ]                  │
│  Qty:     [ 500 ml ]                    │
│                                         │
│  Photo of device:                       │
│     [   📷 Take photo   ]               │
│  (camera only — gallery disabled)       │
│                                         │
│  Notes (optional):                      │
│  [_______________________________]      │
│                                         │
│  Customer signature (optional):         │
│     [✍ Sign on screen]                  │
│                                         │
│  ──────────────────────────────────     │
│  Collect payment now?                   │
│  ○ No — leave as charge                 │
│  ● Yes — receipt voucher                │
│                                         │
│  [If yes, collection form expands]      │
│                                         │
│             [ Complete visit ]          │
└─────────────────────────────────────────┘
```

### 4.3 Oil Selection
- Dropdown defaults to the **currently active oil** for this contract (from `contract_oil_changes`)
- Agent can change it
- If changed, after tapping "Complete visit", confirmation dialog: *"Switch to {new oil} starting today? This will be the oil used going forward."*
- On confirm: closes the old `contract_oil_changes` row, opens a new one

### 4.4 Photo
- Camera opens directly — gallery picker is disabled
- EXIF timestamp must be within 1 hour of visit time, or visit flagged
- Photo uploaded to `visit_photos` bucket under `{tenant_id}/{visit_id}/refill.jpg`

### 4.5 Collection Block (Optional)

If "Yes — collect payment now" selected:

```
Amount:    [____] KWD
Method:    ○ Cash  ● KNET  ○ Transfer
Ref no:    [_____] (for KNET/Transfer)

Allocate to invoices:
  ☑ INV-2026-00045    12.500
  ☑ INV-2026-00067    12.500
  ☐ INV-2026-00089    12.500

Total allocated: 25.000

Send receipt to customer?
  ☑ WhatsApp   ☑ Email
```

### 4.6 Complete Visit
Tap **Complete visit** → fires `record_refill_visit` RPC, which:

1. Inserts/updates visit row (with `customer_id`, `service_location_id`, photo URL, GPS, timestamps, oil info)
2. Updates inventory: van warehouse `qty_available -= 500 ml` of the oil
3. Inserts inventory_movement (`type = refill`)
4. **If no payment:** generates an open invoice (charge) for this refill
5. **If payment collected:** generates the invoice AND a receipt voucher, allocates voucher to invoices
6. If oil was switched: updates `contract_oil_changes` accordingly
7. If receipt is requested: queues notifications (WhatsApp + email)
8. Marks visit as `completed`
9. Returns success → mobile shows success screen

### 4.7 Offline Behavior
If no signal:
- All data stored locally in Drift SQLite
- Photo stays on device until upload succeeds
- Visit shows badge "Pending sync"
- Background sync uploads when online (RPC is idempotent on `client_id`)

---

## 5. New Contract Flow (Mobile)

Sales agents can create contracts in the field. Same multi-step flow as desktop (see `CONTRACTS_LOGIC.md` section 11), but optimized for one-handed phone use:

1. **Customer** - pick existing or quick-create (name + phone required)
2. **Service location** - auto-select the only active location, require a choice when multiple exist, or quick-create a site/address
3. **Type & term** - Trial or Rental, dates
4. **Products** - scan device barcode to auto-fill; add oil + qty
5. **Pricing** - single number (monthly rental value)
6. **Location snapshot** - auto-fills from the selected service location and may capture current GPS for that site
7. **Signature** - customer signs on screen
8. **Review & save**

If the entered price triggers min-profit warning, the agent gets two options:
- "Request Manager approval" (saves as draft + pending)
- "Discuss with Manager and try again later" (saves as draft)

---

## 6. Collections Flow (Mobile)

Sometimes an agent visits purely to collect (no refill). The Today screen shows visits of `type = collection`.

```
[Tap collection visit]
        │
        ▼
┌─────────────────────────────────────────┐
│  ← Collection — Mr. Khalid              │
├─────────────────────────────────────────┤
│  Outstanding balance: KWD 50.000        │
│                                         │
│  Open invoices:                         │
│    INV-2026-00012   25.000              │
│    INV-2026-00056   25.000              │
│                                         │
│  Amount collected: [____] KWD           │
│  Method: ○ Cash ● KNET ○ Transfer       │
│                                         │
│  Allocation:                            │
│    Auto-FIFO  /  Manual                 │
│                                         │
│  Send receipt: ☑ WhatsApp ☑ Email       │
│                                         │
│         [ Confirm collection ]          │
└─────────────────────────────────────────┘
```

A collection visit doesn't require a photo (no service rendered) but still requires GPS check-in.

---

## 7. Van Stock Screen

```
┌─────────────────────────────────────────┐
│  ← Van Stock — Ahmed                    │
├─────────────────────────────────────────┤
│  Last reconciled: yesterday 17:48 ✓     │
│                                         │
│  Oils:                                  │
│   Hilton            8.500 L             │
│   Vanilla           2.250 L             │
│   Oud Royal         1.000 L             │
│                                         │
│  Devices:                               │
│   Diffuser Model X       3 units        │
│   Diffuser Model Y       1 unit         │
│                                         │
│   Tap a row to see history              │
│                                         │
│         [ Request refill ]              │
│         [ End-of-day reconcile ]        │
└─────────────────────────────────────────┘
```

### 7.1 Request Refill
Agent realizes they're running low on Hilton oil. Tap "Request refill" → submits a transfer request from main warehouse. Warehouse keeper sees it on desktop, fulfills it, agent picks up next time at HQ.

### 7.2 End-of-Day Reconcile
Tap "End-of-day reconcile" → app shows current expected stock based on movements, agent confirms actual physical count.

```
┌─────────────────────────────────────────┐
│  End-of-day reconcile                   │
├─────────────────────────────────────────┤
│  Hilton oil                             │
│    Expected: 8.500 L                    │
│    Actual:   [_____] L                  │
│                                         │
│  Vanilla oil                            │
│    Expected: 2.250 L                    │
│    Actual:   [_____] L                  │
│                                         │
│  ... (all stock items) ...              │
│                                         │
│  Any discrepancy → require note         │
│                                         │
│  Cash collected today:                  │
│    Per visits:    KWD 87.500            │
│    Actual cash:   [_____] KWD           │
│                                         │
│         [ Submit reconciliation ]       │
└─────────────────────────────────────────┘
```

Discrepancies are flagged in Manager reports. Repeated discrepancies trigger an alert.

---

## 8. Calendar Screen (Mobile)

```
┌─────────────────────────────────────────┐
│  ← Calendar                             │
├─────────────────────────────────────────┤
│  [ Day | Week | Month ]                 │
│                                         │
│   May 2026                              │
│   ────────────────────────────────      │
│   Sun  Mon  Tue  Wed  Thu  Fri  Sat     │
│                          ●  ●●●  ●●     │
│   ●●   ●●●  ●●   ●    ●●  [15] ●        │
│   ●    ●    ●    ●●   ●●  ●●●  ●        │
│                                         │
│  Today, 15 May:                         │
│   Cafe Bloom · Refill                   │
│   10:00  Mr. Khalid · Collection        │
│   Pearl Tower · Refill                  │
│   Sahara Rest. · Refill ✓               │
│   Adel Holding · Refill ✓               │
│   Al Manara · Refill                    │
│   Cafe Mood · Sales pitch               │
│                                         │
└─────────────────────────────────────────┘
```

Tap a day → opens that day's schedule.

---

## 9. The Calendar System (Both Mobile & Desktop)

### 9.1 What Lives in the Calendar

| Event Type | Source | Auto-generated? |
|------------|--------|-----------------|
| Refill due | Active rental contracts / confirmed field execution | Initial due from contract cadence; later due from actual completion + confirmed coverage |
| Contract end | Fixed-term contracts | Yes |
| Trial ending | Trial periods | Yes — 7 days before `trial_end_date` |
| Maintenance due | High-use devices | Yes — triggered by maintenance rules |
| Payment due | Overdue invoices | Yes — generated when invoice goes overdue |
| Follow-up | Manual | No — sales agent sets |
| Custom | Manual | No |

### 9.2 How Refill Events Are Generated

A secured scheduled job maintains refill events in tenant time. The Phase 7 M0
rule is one outstanding refill per cadence chain:

```
For each active refill cadence chain:
  If an outstanding event exists:
    keep it pending; derive overdue from original_due_date when late
    do not create another refill event
  Else if trusted Phase 8 execution confirmed next_due_date:
    create the next event for confirmed next_due_date
  Else:
    create only the initial contract-cadence event
```

This way:
- missed work remains visible rather than disappearing into a false future cycle;
- `original_due_date` and overdue days remain available;
- Phase 8 actual completion and confirmed coverage determine the next refill;
- manual reassignment/date-only rescheduling does not claim execution;
- financial billing cadence remains independent.

### 9.3 Reminders

Phase 7 appointments are date-only. The old minute-offset field is legacy and
must not create a fabricated midnight appointment.

The manager explicitly reviews an IANA timezone and all seven weekday working
schedules. Until `working_schedule_configured` is true, no working-hours-based
reminder is created.

The two initial in-app policies are independently configurable:

```
At the start of the event working day, if enabled
At the start of the previous working day, if enabled
```

The worker uses an idempotent delivery ledger. External email/WhatsApp/SMS
delivery is not guaranteed by Phase 7 without its separately accepted channel
configuration.

### 9.4 Reassignment

Users with `calendar.reassign` can reassign a calendar event (move from agent A to agent B). The mobile app receives a realtime update; agent A's Today list removes the visit, agent B's adds it.

### 9.5 Manual Events

Sales agents can add:
- Follow-up reminders ("call customer next Tuesday")
- Sales meetings
- Custom tasks

These are personal to the agent unless `assigned_agent_id` is set.

---

## 10. The Calendar Screen (Desktop)

A richer view than mobile. Three modes:

### 10.1 Month View
A full calendar grid. Each day cell shows:
- Number of events as a dot row
- Color-coded by type (gold = refill, green = collection, blue = sales, red = overdue, etc.)
- Tap a day → opens day detail panel on right

### 10.2 Week View
7-column grid, 24 rows (hours). Events appear as colored blocks. Drag-and-drop to reschedule.

### 10.3 Day View
Detailed list with hour-by-hour breakdown. Sidebar shows unassigned events that can be dragged onto an agent's column.

### 10.4 Agent Columns (Desktop)
On Day and Week views, users with `calendar.view_all_agents` can split by agent — multi-column view, one per agent. This shows workload distribution at a glance.

### 10.5 Filters
- By agent
- By event type
- By customer
- By service location
- By area
- By status (pending / done / missed / etc.)

---

## 11. Notifications & Reminders to Customer

When refill day approaches, the customer can receive a heads-up message via WhatsApp.

### 11.1 Customer Refill Reminder Template (WhatsApp)

> مرحباً {{customer_name}}،
> هذه رسالة تذكير بأن موعد تبديل الزيت لجهازك سيكون يوم {{date}}. سيمر مندوبنا في الموعد المتفق عليه.
> شكراً لاختياركم حياة سكرت.

Tenant can edit template in settings.

### 11.2 When Sent
Configurable per tenant:
- 1 day before refill day, OR
- 2 hours before scheduled visit, OR
- Both, OR
- Never

---

## 12. End-of-Day Summary

When the agent taps "End of day" or at a configured time (e.g. 18:00):

```
┌─────────────────────────────────────────┐
│  Today's summary                        │
├─────────────────────────────────────────┤
│  ✓ 6 visits completed                   │
│  ⚠ 1 visit missed (will reschedule)    │
│  📜 1 new contract signed                │
│  💰 KWD 125.500 collected                │
│                                         │
│  Pending sync: 0 visits                 │
│                                         │
│  Stock movements:                       │
│   - Hilton oil:   used 3 L              │
│   - Vanilla:      used 0.5 L            │
│                                         │
│         [ Reconcile van stock ]         │
│                                         │
│  Have a great evening 🌙                │
└─────────────────────────────────────────┘
```

The missed visit appears in tomorrow's Today screen, with a note "Rescheduled from yesterday."

---

## 13. Edge Cases

### 13.1 Customer Not Home
Agent taps "Customer unavailable":
- Records visit as `missed`
- Photo not required
- Optional note
- System auto-schedules a follow-up calendar event for 2 days later

### 13.2 Device Broken at Site
Agent taps "Device issue":
- Selects from: needs_cleaning, mechanical_failure, missing, customer_complaint
- Photo required (of the issue)
- Creates a `maintenance_records` entry
- Updates device status to `maintenance`
- Inventory: qty_rented decreases, qty_maintenance increases
- Customer gets a notification (per tenant settings)

### 13.3 GPS Outside Allowed Range
If GPS is outside the configured radius from the service location or contract snapshot:
- App shows warning: "You appear to be far from {service location}. Are you sure?"
- Agent must enter a reason to proceed
- Visit gets a `location_match = false` flag
- The captured `check_in_accuracy_m` is stored so weak GPS accuracy can be reviewed fairly
- Admin sees it highlighted in reports

### 13.4 Wrong Customer
Agent realizes they're at the wrong location, taps "Wrong customer":
- Visit is cancelled (not missed)
- No data saved
- Calendar reschedule prompt
