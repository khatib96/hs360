-- Phase 1B: audit log (section 18). tenant_id has no FK per schema.

create table audit_log (
  id bigint generated always as identity primary key,
  tenant_id uuid not null,
  at timestamptz default now(),
  actor_id uuid references auth.users (id),
  actor_account_type text,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_json jsonb,
  after_json jsonb,
  reason text,
  ip_address inet,
  user_agent text
);

create index idx_audit_tenant on audit_log (tenant_id);
create index idx_audit_at on audit_log (at desc);
create index idx_audit_entity on audit_log (entity_type, entity_id);
