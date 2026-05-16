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
│  📍 09:30  Cafe Bloom · Refill         │
│      Salmiya Block 5                    │
│      [ Start ]                          │
│                                         │
│  📍 10:00  Mr. Khalid · Collection      │
│      Salwa Block 2                      │
│      [ Start ]                          │
│                                         │
│  📍 11:00  Pearl Tower Hotel · Refill   │
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
3. Compares against contract location
4. If within `gps_accuracy_threshold_m` (tenant setting): ✓ verified
5. If outside: warning shown but visit can proceed (Manager sees flag in report)

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

1. Inserts visit row (with photo URL, GPS, timestamps, oil info)
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

1. **Customer** — pick existing or quick-create (name + phone required)
2. **Type & term** — Trial or Rental, dates
3. **Products** — scan device barcode → auto-fills; add oil + qty
4. **Pricing** — single number (monthly rental value)
5. **Location** — auto-fills with current GPS
6. **Signature** — customer signs on screen
7. **Review & save**

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
│   09:30  Cafe Bloom · Refill            │
│   10:00  Mr. Khalid · Collection        │
│   11:00  Pearl Tower · Refill           │
│   13:00  Sahara Rest. · Refill ✓        │
│   14:00  Adel Holding · Refill ✓        │
│   15:30  Al Manara · Refill             │
│   17:00  Cafe Mood · Sales pitch        │
│                                         │
└─────────────────────────────────────────┘
```

Tap a day → opens that day's schedule.

---

## 9. The Calendar System (Both Mobile & Desktop)

### 9.1 What Lives in the Calendar

| Event Type | Source | Auto-generated? |
|------------|--------|-----------------|
| Refill due | Active rental contracts | Yes — based on `refill_day` |
| Contract end | Fixed-term contracts | Yes |
| Trial ending | Trial contracts | Yes — 7 days before `trial_end_date` |
| Maintenance due | High-use devices | Yes — triggered by maintenance rules |
| Payment due | Overdue invoices | Yes — generated when invoice goes overdue |
| Follow-up | Manual | No — sales agent sets |
| Custom | Manual | No |

### 9.2 How Refill Events Are Generated

A daily Edge Function `daily_calendar_seed_job()` runs at 00:30 tenant time:

```
For each active rental contract with refill_day set:
  Look at next 30 days
  For each day where day_of_month = contract.refill_day:
    If no calendar_event exists yet for that date/contract:
      INSERT calendar_events (
        type = 'refill_due',
        contract_id = contract.id,
        customer_id = contract.customer_id,
        scheduled_date = that_date,
        assigned_agent_id = (default refill agent for this customer, configurable),
        is_recurring = true,
        recurrence_rule = 'FREQ=MONTHLY;BYMONTHDAY=' || refill_day
      )
```

This way:
- Calendar always shows next 30 days populated
- Agents see what's coming
- Manual reassignment is allowed (move a visit to a different agent or date)

### 9.3 Reminders

Each event has `reminder_offsets_minutes` (default `{1440, 60}` — 1 day and 1 hour before).

A `reminders_job()` runs every 15 minutes:

```
For each pending calendar_event:
  Compute reminder times = scheduled_date + scheduled_time - offsets
  If any reminder time is in [now - 15min, now]:
    Queue notification:
      - Push to agent's mobile (if assigned)
      - Email to agent
      - WhatsApp to customer (if configured per template)
```

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

### 13.3 GPS Way Off
If GPS is more than 5km from contract location:
- App shows hard warning: "You appear to be far from {contract location}. Are you sure?"
- Agent must enter a reason to proceed
- Visit gets a `location_match = false` flag
- Admin sees it highlighted in reports

### 13.4 Wrong Customer
Agent realizes they're at the wrong location, taps "Wrong customer":
- Visit is cancelled (not missed)
- No data saved
- Calendar reschedule prompt
