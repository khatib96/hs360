# CUSTOMER_LEDGER.md — Customer Ledger & WhatsApp Communications

> The customer ledger is the single page where everything about one customer lives: contracts, invoices, payments, balance, history, and direct messaging.
> WhatsApp integration enables broadcast messaging to one customer, a segment, or all customers.
> Updated 2026-05-16 to resolve conflicts: KWD examples use the tenant's default currency at runtime.

---

## 1. The Customer Ledger Concept

Each customer has a comprehensive **ledger** — a single screen showing complete financial and operational history. This is the most-used screen for Managers and users with customer-ledger permissions.

### 1.1 Why It Matters
- Answers: "Does this customer owe us money?" in one glance
- Answers: "When did they last pay?"
- Answers: "What's their service history?"
- Answers: "How profitable is this customer overall?"

### 1.2 What's on the Ledger Screen

```
┌──────────────────────────────────────────────────────────────┐
│  ← Cafe Bloom (CUST-0042)              [Edit]  [⋯ More]      │
├──────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────┐ │
│  │ Outstanding      │  │ Total invoiced   │  │ Lifetime    │ │
│  │ KWD 87.500       │  │ KWD 1,250.000    │  │ profit      │ │
│  │ (3 overdue)      │  │ since Jan 2024   │  │ KWD 425.000 │ │
│  └──────────────────┘  └──────────────────┘  └─────────────┘ │
│                                                              │
│  Contact: +965 9XXX XXXX   ✉ bloom@example.com               │
│  WhatsApp:  Verified ✓   [Send message]                      │
│  Location:  Salmiya Block 5  [Open map]                      │
│                                                              │
│  [📜 Contracts] [💰 Ledger] [📄 Invoices] [💵 Vouchers]      │
│  [📅 Visits]    [📊 Statement]  [💬 Messages]                │
│                                                              │
│  ────────────────────────────────────────────────────────    │
│                                                              │
│  TAB: Ledger (default)                                       │
│                                                              │
│  Date        Type         Ref          Debit    Credit   Bal │
│  ────────────────────────────────────────────────────────    │
│  01 Jan 24   Opening      -            0.000    0.000   0    │
│  15 Jan 24   Sale Invoice INV-0012     50.000   -       50   │
│  20 Jan 24   Receipt      RV-0034      -        50.000  0    │
│  01 Feb 24   Rental       INV-0089     12.500   -       12.5 │
│  03 Feb 24   Refill       INV-0091     0.000    -       12.5 │
│  10 Feb 24   Receipt      RV-0067      -        12.500  0    │
│  01 Mar 24   Rental       INV-0145     12.500   -       12.5 │
│  ... (paginated, newest first by default) ...                │
│                                                              │
│  [Filter: All  Date range  Type]   [Export PDF] [Export CSV] │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Database Implementation

### 2.1 Customer Balance — Live View

The customer's balance is **never stored** — it's always computed live from the journal:

```sql
create or replace view v_customer_balances as
select
  c.id as customer_id,
  c.tenant_id,
  c.name_ar,
  c.code,
  c.account_id,
  coalesce(sum(jl.debit - jl.credit), 0) as balance,
  count(distinct case when i.status in ('confirmed','partially_paid') and i.due_date < current_date then i.id end) as overdue_count,
  sum(case when i.status in ('confirmed','partially_paid') and i.due_date < current_date then (i.total - i.paid_amount) else 0 end) as overdue_amount
from customers c
left join journal_lines jl on jl.account_id = c.account_id
left join invoices i on i.customer_id = c.id
group by c.id, c.tenant_id, c.name_ar, c.code, c.account_id;
```

This gives `balance > 0` means the customer owes us; `balance < 0` means we owe them (credit balance).

### 2.2 Customer Ledger Entries — Live View

```sql
create or replace view v_customer_ledger_entries as
select
  c.id as customer_id,
  c.tenant_id,
  je.date,
  je.entry_number,
  je.source,
  je.source_id,
  je.description_ar,
  je.description_en,
  jl.debit,
  jl.credit,
  -- Running balance computed by application via window function
  sum(jl.debit - jl.credit) over (
    partition by c.id
    order by je.date, je.entry_number
    rows between unbounded preceding and current row
  ) as running_balance
from customers c
join journal_lines jl on jl.account_id = c.account_id
join journal_entries je on je.id = jl.journal_entry_id
where je.is_posted = true
order by je.date desc, je.entry_number desc;
```

The Flutter app queries with `.eq('customer_id', X)`, paginates, and displays as a table.

### 2.3 Customer Statement

A printable PDF derived from the ledger entries. Includes:
- Customer header (name, code, contact)
- Date range (default: current fiscal year, customizable)
- Opening balance + all transactions + closing balance
- Aging summary at the bottom (0–30, 31–60, 61–90, 91+)
- Bank details footer

Generated via Edge Function using a PDF template. Sent to customer via email/WhatsApp on request.

---

## 3. The Ledger UI — Desktop Tabs

### 3.1 Contracts Tab
List of all contracts for this customer:
- Active, suspended, completed, terminated
- Quick stats: total contracts, currently active, monthly recurring revenue from this customer

### 3.2 Ledger Tab (Default)
The detailed account ledger view shown above.

### 3.3 Invoices Tab
- Filterable by status (draft, confirmed, paid, partially paid, overdue)
- Quick view of outstanding amounts
- Bulk actions: "Send reminders for all overdue"

### 3.4 Vouchers Tab
All receipt vouchers (payments) for this customer, sorted by date desc.
Quick stats: total collected this year, average days to pay.

### 3.5 Visits Tab
All service visits to this customer's location. Useful for:
- Service history audit
- "When was the last refill?"
- Visit photos gallery view

### 3.6 Statement Tab
- Date range selector
- Live preview of statement
- "Generate PDF" button
- "Send to customer" button (WhatsApp + email)

### 3.7 Messages Tab (NEW)
WhatsApp / email conversation history with this customer. See section 5.

---

## 4. Customer Profile — Beyond Money

The customer record also tracks softer info:

```sql
alter table customers add column
  preferred_contact_method text default 'whatsapp',     -- whatsapp | email | phone | sms
  preferred_language text default 'ar',
  receive_marketing boolean default true,
  receive_invoices boolean default true,
  receive_receipts boolean default true,
  receive_reminders boolean default true,
  tags text[],                                          -- ['vip', 'cafes', 'salmiya']
  notes_internal text;                                  -- staff notes, not visible to customer
```

### 4.1 Tags
Customers can be tagged for segmentation:
- `vip` — special handling
- `cafes`, `hotels`, `offices` — by sector
- `salmiya`, `sharq`, `salwa` — by area
- Custom tags per tenant

Used for filtering, reports, and bulk messaging.

### 4.2 Communication Preferences
A customer can opt out of marketing while still receiving invoices. The notification engine respects these flags.

---

## 5. WhatsApp Integration

### 5.1 The Goal
- Send individual messages (receipts, reminders)
- Send broadcast messages (announcements, promotions)
- Conversation history visible in customer profile
- Two-way: customer replies appear in the system

### 5.2 Architecture: Meta WhatsApp Cloud API

```
Tenant's app
   │
   │  (sends message via Edge Function)
   ▼
Edge Function (TS)
   │
   │  https://graph.facebook.com/v18.0/{phone_id}/messages
   │  Bearer <WhatsApp permanent token>
   ▼
Meta WhatsApp Cloud API
   │
   ▼
Customer's phone
```

For receiving messages, Meta sends webhooks to the tenant's server.

### 5.3 Setup Per Tenant
Each tenant has their **own WhatsApp Business Account**:
1. Apply at business.facebook.com
2. Verify business
3. Get a phone number (or migrate existing)
4. Obtain `phone_number_id` and `permanent_access_token`
5. Configure in `tenant_settings`:
   ```
   whatsapp_phone_id = '...'
   whatsapp_token_vault_ref = '...' -- stored in Supabase Vault
   whatsapp_webhook_secret = '...'
   ```

### 5.4 Verified WhatsApp Number
A column on `customers`:
```sql
alter table customers add column
  whatsapp_verified boolean default false,
  whatsapp_verified_at timestamptz;
```

When a customer's number first receives a message and the read receipt comes back, mark verified.

---

## 6. Message Templates

WhatsApp Business requires pre-approved templates for outbound messages outside the 24-hour customer service window.

### 6.1 Template Catalog

Created in Meta Business Manager, then registered in the system:

```sql
create table whatsapp_templates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  template_name text not null,        -- as approved by Meta
  category text not null,             -- utility | marketing | authentication
  language_code text not null,        -- 'ar' | 'en'
  body_ar text not null,
  body_en text,
  variable_names text[],              -- e.g. ['customer_name', 'amount', 'date']
  is_active boolean default true,
  meta_status text,                   -- pending | approved | rejected
  created_at timestamptz default now(),
  unique(tenant_id, template_name, language_code)
);
```

### 6.2 Standard Templates (Pre-Built)

| Template Key | Purpose | Variables |
|--------------|---------|-----------|
| `receipt_voucher` | Confirm payment received | name, amount, voucher_number |
| `invoice_notification` | New invoice issued | name, amount, due_date, invoice_number |
| `payment_reminder` | Friendly debt reminder | name, amount, days_overdue |
| `payment_reminder_firm` | Firm reminder (60+ days overdue) | name, amount |
| `refill_reminder` | Tomorrow's refill heads-up | name, date, time |
| `refill_completed` | Confirm visit done | name, oil_name, next_refill_date |
| `contract_created` | Welcome new contract | name, contract_number, start_date |
| `contract_ending_soon` | Renewal nudge | name, end_date |
| `trial_ending` | Trial conversion nudge | name, days_left |
| `seasonal_greeting` | Eid, holidays | name |
| `promotional_offer` | Marketing campaigns | name, offer_details |

### 6.3 Template Variables
Use `{{1}}, {{2}}, {{3}}` etc. in template body. The system substitutes them when sending.

Example template body (Arabic):
```
مرحباً {{1}}،
تم استلام دفعتكم بقيمة {{2}} د.ك.
رقم سند القبض: {{3}}
شكراً لاختياركم حياة سكرت 🌹
```

---

## 7. Sending Messages

### 7.1 Single Message — From Customer Profile

```
┌──────────────────────────────────────┐
│  Send WhatsApp — Cafe Bloom          │
├──────────────────────────────────────┤
│  Type: ● Template  ○ Free text       │
│                                      │
│  Template: [ Payment reminder ▼ ]    │
│                                      │
│  Preview:                            │
│  ┌────────────────────────────────┐ │
│  │ مرحباً Cafe Bloom،              │ │
│  │ نود تذكيركم بأن لديكم مستحقات   │ │
│  │ بقيمة 87.500 د.ك متأخرة عن      │ │
│  │ سدادها منذ 15 يوماً.             │ │
│  └────────────────────────────────┘ │
│                                      │
│           [Cancel]   [Send]          │
└──────────────────────────────────────┘
```

Free text is only allowed within the 24-hour customer-initiated conversation window.

### 7.2 Broadcast Message — Mass Send

```
┌──────────────────────────────────────────────┐
│  Broadcast WhatsApp Message                  │
├──────────────────────────────────────────────┤
│  Audience:                                   │
│    ○ All customers (147)                     │
│    ○ Active contracts only (115)             │
│    ● By tag: [cafes] [salmiya]  (24)        │
│    ○ Custom filter...                        │
│    ○ Manual selection...                     │
│                                              │
│  Exclude customers who opted out: ✓          │
│                                              │
│  Template: [ Seasonal greeting ▼ ]           │
│                                              │
│  Schedule:                                   │
│    ● Send now                                │
│    ○ Schedule for: [_____] at [____]         │
│                                              │
│  Estimated cost: 24 conversations            │
│  At $0.03 each ≈ $0.72                       │
│                                              │
│  ⚠ Marketing templates count toward          │
│    monthly limit per Meta policies.          │
│                                              │
│  [Cancel]  [Save as draft]  [Send]           │
└──────────────────────────────────────────────┘
```

### 7.3 Mass Send Flow (Backend)

```sql
create table whatsapp_campaigns (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  name text not null,
  template_id uuid not null references whatsapp_templates(id),
  audience_filter jsonb,                  -- the saved query
  recipient_count int default 0,
  scheduled_for timestamptz,
  status text default 'draft',            -- draft | scheduled | sending | completed | cancelled
  sent_count int default 0,
  failed_count int default 0,
  created_at timestamptz default now(),
  created_by uuid references auth.users(id),
  started_at timestamptz,
  completed_at timestamptz
);

create table whatsapp_campaign_recipients (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  campaign_id uuid not null references whatsapp_campaigns(id) on delete cascade,
  customer_id uuid not null references customers(id),
  status text default 'pending',          -- pending | sent | failed | read
  sent_at timestamptz,
  read_at timestamptz,
  error_message text,
  meta_message_id text
);
```

Edge Function `process_whatsapp_campaign` runs:
1. Pulls next batch of pending recipients (rate-limited per Meta API limits — ~80 messages/sec for high-tier accounts)
2. Sends each message via WhatsApp API
3. Updates status
4. Records `meta_message_id` for tracking

### 7.4 Status Tracking via Webhooks

Meta sends webhooks for:
- `sent` — message dispatched
- `delivered` — reached the phone
- `read` — customer opened it
- `failed` — couldn't deliver

```sql
create table whatsapp_message_log (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  customer_id uuid references customers(id),
  meta_message_id text unique,
  direction text not null,                -- outbound | inbound
  template_id uuid references whatsapp_templates(id),
  campaign_id uuid references whatsapp_campaigns(id),
  body text,
  status text default 'sent',
  status_updates jsonb default '[]',      -- array of {status, at}
  related_entity_table text,
  related_entity_id uuid,
  sent_at timestamptz,
  delivered_at timestamptz,
  read_at timestamptz,
  failed_at timestamptz,
  failure_reason text,
  created_at timestamptz default now()
);
```

This log powers the **Messages tab** on the customer profile.

---

## 8. Incoming Messages

When a customer replies via WhatsApp:

```
Meta webhook → /webhooks/whatsapp (Edge Function)
   │
   ├─ Verify signature with webhook_secret
   ├─ Identify which tenant by phone_number_id
   ├─ Find or create customer by phone
   ├─ Insert into whatsapp_message_log (direction='inbound')
   ├─ Trigger in-app notification to assigned account manager
   └─ Open 24-hour customer service window (free-form replies allowed)
```

A small badge appears next to the customer's name in the customers list if they have unread messages.

### 8.1 Replying to Customers

Free-form replies are allowed within 24 hours of customer's last message. The system has a **Conversations** screen showing active conversations:

```
┌──────────────────────────────────────────────────┐
│  Conversations (3 unread)                        │
├──────────────────────────────────────────────────┤
│  ● Cafe Bloom              2 min ago             │
│    "Can we reschedule the refill?"               │
│                                                  │
│  ● Pearl Tower             1 hr ago              │
│    "Where can I download the invoice?"           │
│                                                  │
│  ● Mr. Khalid              3 hrs ago             │
│    "Thanks for the receipt"                      │
│                                                  │
│  Sahara Restaurant        yesterday              │
│  Adel Holding             2 days ago             │
└──────────────────────────────────────────────────┘
```

Each conversation opens a chat-like view with full history.

---

## 9. Smart Automation Triggers

The system can auto-send messages based on events:

| Event | Action |
|-------|--------|
| Receipt voucher created | Auto-send `receipt_voucher` template to customer |
| Invoice confirmed (rental) | Auto-send `invoice_notification` if tenant setting enabled |
| Invoice 7 days overdue | Auto-send `payment_reminder` |
| Invoice 60 days overdue | Auto-send `payment_reminder_firm` + notify manager |
| Refill due tomorrow | Auto-send `refill_reminder` |
| Refill completed | Auto-send `refill_completed` with next date |
| Trial 7 days from expiry | Auto-send `trial_ending` |
| Customer's contract ending in 30 days | Auto-send `contract_ending_soon` |

Each of these is **configurable per tenant** (on/off, exact timing) and **per customer** (via their notification preferences).

---

## 10. Cost & Compliance

### 10.1 Meta Pricing (Approximate)
- Utility messages (receipts, reminders, transactional): ~$0.015–$0.03 per conversation
- Marketing messages: ~$0.04–$0.09 per conversation
- Customer service window: free responses for 24 hours after customer's last message
- A "conversation" is 24 hours of message exchange, not per message

### 10.2 Quality Score
Meta tracks template quality. High-frequency / low-engagement messages tank the score. Best practices:
- Don't spam
- Respect opt-out
- Keep templates relevant and well-formatted
- Monitor the dashboard regularly

### 10.3 Compliance
- Always offer opt-out in marketing templates ("Reply STOP to unsubscribe")
- Honor stops within 24 hours
- Don't message customers who haven't given consent

The system enforces these:
```sql
-- Cannot send marketing to opted-out customers
create policy "marketing_respect_optout" on whatsapp_message_log
  for insert with check (
    not (
      (select template.category from whatsapp_templates template where template.id = new.template_id) = 'marketing'
      and (select c.receive_marketing from customers c where c.id = new.customer_id) = false
    )
  );
```

---

## 11. Email Channel (Same Pattern)

The same concepts apply to email via Resend:

- Per-tenant Resend API key in vault
- Email templates (HTML) stored in `email_templates` table
- `email_message_log` similar to WhatsApp log
- Auto-triggers same events
- Bounce handling via Resend webhooks

Customers with `email` populated and `receive_*` flags set get both WhatsApp and email. Many tenants enable both for receipts, only WhatsApp for reminders, only email for invoices.

---

## 12. Per-Customer Communication Panel

On the customer ledger, a side panel shows quick communication tools:

```
┌──────────────────────────┐
│  Quick Actions           │
├──────────────────────────┤
│  📧 Send invoice copy    │
│  💵 Send statement       │
│  ⏰ Send payment reminder│
│  📅 Send refill reminder │
│  💬 Custom WhatsApp      │
│  ✉ Custom email          │
│                          │
│  Communication prefs:    │
│  WhatsApp: ✓             │
│  Email: ✓                │
│  Marketing: ✓            │
│  [Edit]                  │
└──────────────────────────┘
```

This makes customer-facing actions one click away from the ledger.
