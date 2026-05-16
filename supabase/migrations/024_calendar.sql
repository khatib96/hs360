-- Phase 1B: calendar events (section 16).

create table calendar_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  type calendar_event_type not null,
  status calendar_event_status default 'pending',

  scheduled_date date not null,
  scheduled_time time,
  reminder_offsets_minutes int[] default '{1440, 60}',

  assigned_agent_id uuid references employees (id),
  contract_id uuid references contracts (id),
  customer_id uuid references customers (id),
  product_unit_id uuid references product_units (id),
  visit_id uuid references visits (id),

  title_ar text,
  title_en text,
  notes text,

  completed_at timestamptz,
  completed_by uuid references auth.users (id),

  is_recurring boolean default false,
  recurrence_rule text,
  parent_event_id uuid references calendar_events (id),

  created_at timestamptz default now(),
  created_by uuid references auth.users (id)
);

create index idx_calevents_tenant on calendar_events (tenant_id);
create index idx_calevents_agent on calendar_events (assigned_agent_id);
create index idx_calevents_date on calendar_events (scheduled_date);
create index idx_calevents_contract on calendar_events (contract_id);
create index idx_calevents_status on calendar_events (status);
