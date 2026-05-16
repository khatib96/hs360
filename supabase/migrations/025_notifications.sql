-- Phase 1B: notifications (section 17).

create table notifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id),
  channel notification_channel not null,
  recipient_type text not null,
  recipient_id uuid not null,
  recipient_address text not null,
  subject text,
  body_ar text,
  body_en text,
  template_key text,
  status notification_status default 'pending',
  sent_at timestamptz,
  error_message text,
  related_entity_table text,
  related_entity_id uuid,
  created_at timestamptz default now()
);

create index idx_notifs_tenant on notifications (tenant_id);
create index idx_notifs_status on notifications (status);
