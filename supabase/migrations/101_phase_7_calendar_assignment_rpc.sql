-- Phase 7 M8: assignment and rescheduling.
-- Adds tenant-safe active-employee assignment, audited date rescheduling with
-- mandatory reason and day-off override handling, optimistic concurrency via
-- schedule_version, and idempotent retries through a dedicated schedule ledger.
-- Do not edit sources 093-100; supersede via CREATE OR REPLACE / ALTER here.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Section A: Preflight — required objects
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regprocedure(
    'public.calendar_manual_available_actions_json(public.calendar_events, boolean)'
  ) is null then
    raise exception 'm8_preflight_failed: missing calendar_manual_available_actions_json';
  end if;

  if to_regprocedure('public.resolve_tenant_working_window(uuid, date)') is null then
    raise exception 'm8_preflight_failed: missing resolve_tenant_working_window';
  end if;

  if to_regprocedure('public.refresh_calendar_event_reminder_plans(uuid)') is null then
    raise exception 'm8_preflight_failed: missing refresh_calendar_event_reminder_plans';
  end if;

  if not exists (
    select 1
    from pg_trigger tg
    join pg_class c on c.oid = tg.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'calendar_events'
      and tg.tgname = 'trg_calendar_events_reminder_refresh'
      and not tg.tgisinternal
  ) then
    raise exception 'm8_preflight_failed: missing calendar_events reminder-refresh trigger';
  end if;

  if to_regprocedure(
    'public.emit_calendar_meeting_notice(uuid, uuid, text, uuid, uuid, uuid, public.calendar_events)'
  ) is null then
    raise exception 'm8_preflight_failed: missing emit_calendar_meeting_notice';
  end if;

  if to_regprocedure(
    'public.calendar_read_scoped_events(uuid, text, uuid, public.calendar_read_filter_bundle, date)'
  ) is null then
    raise exception 'm8_preflight_failed: missing calendar_read_scoped_events';
  end if;

  if to_regclass('public.ux_employees_tenant_id_id') is null then
    raise exception 'm8_preflight_failed: missing ux_employees_tenant_id_id';
  end if;

  if to_regclass('public.ux_calendar_events_tenant_id') is null then
    raise exception 'm8_preflight_failed: missing ux_calendar_events_tenant_id';
  end if;

  if to_regprocedure('public.acquire_finance_idempotency_lock(uuid)') is null then
    raise exception 'm8_preflight_failed: missing acquire_finance_idempotency_lock';
  end if;

  if to_regprocedure('public.build_manual_calendar_event_response(uuid)') is null then
    raise exception 'm8_preflight_failed: missing build_manual_calendar_event_response';
  end if;

  if to_regprocedure(
    'public.detect_manual_calendar_schedule_warnings(uuid, date, timestamptz, timestamptz)'
  ) is null then
    raise exception 'm8_preflight_failed: missing detect_manual_calendar_schedule_warnings';
  end if;

  if to_regprocedure(
    'public.detect_manual_calendar_overlap_warnings(uuid, date, timestamptz, timestamptz, uuid[], uuid)'
  ) is null then
    raise exception 'm8_preflight_failed: missing detect_manual_calendar_overlap_warnings';
  end if;

  if to_regprocedure(
    'public.manual_calendar_conflict_requires_confirmation(jsonb, int, jsonb)'
  ) is null then
    raise exception 'm8_preflight_failed: missing manual_calendar_conflict_requires_confirmation';
  end if;

  if to_regprocedure('public.manual_calendar_extract_acknowledgements(jsonb)') is null then
    raise exception 'm8_preflight_failed: missing manual_calendar_extract_acknowledgements';
  end if;

  if to_regprocedure(
    'public.resolve_appointment_time_window(text, date, text, text)'
  ) is null then
    raise exception 'm8_preflight_failed: missing resolve_appointment_time_window';
  end if;

  if to_regprocedure('public.snapshot_manual_calendar_event_audit(uuid)') is null then
    raise exception 'm8_preflight_failed: missing snapshot_manual_calendar_event_audit';
  end if;

  if to_regprocedure(
    'public.user_has_calendar_event_visibility(uuid, uuid, uuid)'
  ) is null then
    raise exception 'm8_preflight_failed: missing user_has_calendar_event_visibility';
  end if;

  if to_regprocedure('public.manual_calendar_business_payload_hash(jsonb)') is null then
    raise exception 'm8_preflight_failed: missing manual_calendar_business_payload_hash';
  end if;

  if to_regprocedure('public.calendar_event_participants_json(uuid, uuid)') is null then
    raise exception 'm8_preflight_failed: missing calendar_event_participants_json';
  end if;

  if to_regprocedure('public.acquire_calendar_conflict_locks(uuid, date, uuid[])') is null then
    raise exception 'm8_preflight_failed: missing acquire_calendar_conflict_locks';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section B: Integrity — no dangling assigned agents before composite FK
-- ---------------------------------------------------------------------------
do $$
declare
  v_bad int;
begin
  select count(*)
  into v_bad
  from public.calendar_events ce
  where ce.assigned_agent_id is not null
    and not exists (
      select 1
      from public.employees e
      where e.tenant_id = ce.tenant_id
        and e.id = ce.assigned_agent_id
    );

  if v_bad > 0 then
    raise exception
      'm8_preflight_failed: % calendar_events rows have an assigned_agent_id without a matching tenant employee',
      v_bad;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section C: Composite tenant-safe assignee FK
-- ---------------------------------------------------------------------------
-- Drop any single-column FK on assigned_agent_id (legacy inline references
-- employees(id)); a composite (tenant_id, assigned_agent_id) FK replaces it.
do $$
declare
  r record;
begin
  for r in
    select con.conname
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'calendar_events'
      and con.contype = 'f'
      and (
        select array_agg(a.attname::text order by k.ord)
        from unnest(con.conkey) with ordinality k(attnum, ord)
        join pg_attribute a
          on a.attrelid = con.conrelid
          and a.attnum = k.attnum
      ) = array['assigned_agent_id']
  loop
    execute format('alter table public.calendar_events drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.calendar_events
  drop constraint if exists fk_calendar_events_assigned_agent;

-- NULL assigned_agent_id is permitted: PostgreSQL (MATCH SIMPLE) skips the FK
-- check when any referencing column is NULL.
alter table public.calendar_events
  add constraint fk_calendar_events_assigned_agent
  foreign key (tenant_id, assigned_agent_id)
  references public.employees (tenant_id, id);

-- ---------------------------------------------------------------------------
-- Section D: Schedule operations idempotency ledger
-- ---------------------------------------------------------------------------
create table public.calendar_schedule_operations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  operation_type text not null,
  idempotency_key uuid not null,
  business_payload_hash text not null,
  result_status text not null,
  result_event_id uuid,
  result_jsonb jsonb,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  constraint chk_calendar_schedule_operations_type check (
    operation_type in ('assign', 'reschedule')
  ),
  constraint chk_calendar_schedule_operations_status check (
    result_status in ('ok')
  ),
  constraint chk_calendar_schedule_operations_result_complete check (
    result_event_id is not null
    and result_jsonb is not null
    and jsonb_typeof(result_jsonb) = 'object'
    and coalesce(result_jsonb ->> 'status', '') = 'ok'
    and (result_jsonb -> 'changed') is not null
    and jsonb_typeof(result_jsonb -> 'changed') = 'boolean'
    and (result_jsonb -> 'event') is not null
    and jsonb_typeof(result_jsonb -> 'event') = 'object'
  ),
  constraint ux_calendar_schedule_operations_idem
    unique (tenant_id, operation_type, idempotency_key),
  constraint fk_calendar_schedule_operations_event
    foreign key (tenant_id, result_event_id)
    references public.calendar_events (tenant_id, id)
    on delete restrict
);

create index if not exists idx_calendar_schedule_operations_event
  on public.calendar_schedule_operations (tenant_id, result_event_id);

alter table public.calendar_schedule_operations enable row level security;

revoke all on table public.calendar_schedule_operations
  from public, anon, authenticated, service_role;

comment on table public.calendar_schedule_operations is
  'M8: idempotency ledger for assignment/reschedule mutations. '
  'confirmation_required soft-returns are never persisted.';

-- ---------------------------------------------------------------------------
-- Section E: Meeting notices — dual operation provenance (manual + schedule)
-- ---------------------------------------------------------------------------
alter table public.calendar_meeting_notices
  drop constraint if exists ux_calendar_meeting_notices_recipient_op;

alter table public.calendar_meeting_notices
  drop constraint if exists fk_calendar_meeting_notices_operation;

alter table public.calendar_meeting_notices
  alter column operation_id drop not null;

alter table public.calendar_meeting_notices
  add column if not exists schedule_operation_id uuid;

alter table public.calendar_meeting_notices
  drop constraint if exists fk_calendar_meeting_notices_schedule_operation;

alter table public.calendar_meeting_notices
  add constraint fk_calendar_meeting_notices_schedule_operation
  foreign key (schedule_operation_id)
  references public.calendar_schedule_operations (id)
  on delete restrict;

alter table public.calendar_meeting_notices
  drop constraint if exists chk_calendar_meeting_notices_operation_xor;

-- Exactly one operation provenance per notice row. Existing rows already carry
-- operation_id, so the XOR is satisfied on add.
alter table public.calendar_meeting_notices
  add constraint chk_calendar_meeting_notices_operation_xor check (
    (operation_id is not null and schedule_operation_id is null)
    or (operation_id is null and schedule_operation_id is not null)
  );

-- Re-add the manual operation FK (now nullable; skipped when NULL).
alter table public.calendar_meeting_notices
  add constraint fk_calendar_meeting_notices_operation
  foreign key (operation_id)
  references public.calendar_manual_event_operations (id)
  on delete restrict;

-- Partial unique indexes replace the former full unique constraint so the
-- manual and schedule fan-outs each stay idempotent.
create unique index if not exists ux_calendar_meeting_notices_recipient_manual_op
  on public.calendar_meeting_notices (
    tenant_id, calendar_event_id, notice_kind, recipient_user_id, operation_id
  )
  where operation_id is not null;

create unique index if not exists ux_calendar_meeting_notices_recipient_schedule_op
  on public.calendar_meeting_notices (
    tenant_id, calendar_event_id, notice_kind, recipient_user_id, schedule_operation_id
  )
  where schedule_operation_id is not null;

-- ---------------------------------------------------------------------------
-- Section F: emit_calendar_meeting_notice — infer the manual partial index
-- ---------------------------------------------------------------------------
create or replace function public.emit_calendar_meeting_notice(
  p_tenant_id uuid,
  p_event_id uuid,
  p_notice_kind text,
  p_recipient_user_id uuid,
  p_recipient_employee_id uuid,
  p_operation_id uuid,
  p_event public.calendar_events
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notice_id uuid;
  v_notification_id uuid;
  v_subject text;
  v_body_ar text;
  v_body_en text;
begin
  if p_recipient_user_id is null or p_operation_id is null then
    return;
  end if;

  -- Atomic reservation: unique winner inserts the notice row first. The
  -- partial index predicate is inferred so the manual conflict target matches.
  insert into public.calendar_meeting_notices (
    tenant_id, calendar_event_id, notice_kind,
    recipient_user_id, recipient_employee_id, operation_id, schedule_operation_id,
    notification_id
  ) values (
    p_tenant_id, p_event_id, p_notice_kind,
    p_recipient_user_id, p_recipient_employee_id, p_operation_id, null,
    null
  )
  on conflict (
    tenant_id, calendar_event_id, notice_kind, recipient_user_id, operation_id
  ) where operation_id is not null do nothing
  returning id into v_notice_id;

  if v_notice_id is null then
    return; -- loser
  end if;

  begin
    v_subject := coalesce(p_event.title_ar, p_event.title_en, 'اجتماع داخلي');
    v_body_ar := format(
      '%s — %s — %s',
      coalesce(p_event.title_ar, p_event.title_en, ''),
      p_notice_kind,
      to_char(p_event.scheduled_date, 'YYYY-MM-DD')
    );
    v_body_en := format(
      '%s — %s — %s',
      coalesce(p_event.title_en, p_event.title_ar, ''),
      p_notice_kind,
      to_char(p_event.scheduled_date, 'YYYY-MM-DD')
    );

    insert into public.notifications (
      tenant_id, channel, recipient_type, recipient_id, recipient_address,
      subject, body_ar, body_en, template_key, status, sent_at,
      related_entity_table, related_entity_id
    ) values (
      p_tenant_id,
      'in_app'::public.notification_channel,
      'user',
      p_recipient_user_id,
      p_recipient_user_id::text,
      v_subject, v_body_ar, v_body_en,
      'calendar_' || p_notice_kind,
      'sent'::public.notification_status,
      now(),
      'calendar_events',
      p_event_id
    )
    returning id into v_notification_id;

    update public.calendar_meeting_notices n
    set notification_id = v_notification_id
    where n.id = v_notice_id;
  exception
    when others then
      delete from public.calendar_meeting_notices n where n.id = v_notice_id;
      raise;
  end;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section G: schedule-operation meeting notice fan-out
-- ---------------------------------------------------------------------------
create or replace function public.emit_calendar_meeting_notice_for_schedule_operation(
  p_tenant_id uuid,
  p_event_id uuid,
  p_notice_kind text,
  p_recipient_user_id uuid,
  p_recipient_employee_id uuid,
  p_schedule_operation_id uuid,
  p_event public.calendar_events
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notice_id uuid;
  v_notification_id uuid;
  v_subject text;
  v_body_ar text;
  v_body_en text;
begin
  if p_recipient_user_id is null or p_schedule_operation_id is null then
    return;
  end if;

  insert into public.calendar_meeting_notices (
    tenant_id, calendar_event_id, notice_kind,
    recipient_user_id, recipient_employee_id, operation_id, schedule_operation_id,
    notification_id
  ) values (
    p_tenant_id, p_event_id, p_notice_kind,
    p_recipient_user_id, p_recipient_employee_id, null, p_schedule_operation_id,
    null
  )
  on conflict (
    tenant_id, calendar_event_id, notice_kind, recipient_user_id, schedule_operation_id
  ) where schedule_operation_id is not null do nothing
  returning id into v_notice_id;

  if v_notice_id is null then
    return; -- loser
  end if;

  begin
    v_subject := coalesce(p_event.title_ar, p_event.title_en, 'اجتماع داخلي');
    v_body_ar := format(
      '%s — %s — %s',
      coalesce(p_event.title_ar, p_event.title_en, ''),
      p_notice_kind,
      to_char(p_event.scheduled_date, 'YYYY-MM-DD')
    );
    v_body_en := format(
      '%s — %s — %s',
      coalesce(p_event.title_en, p_event.title_ar, ''),
      p_notice_kind,
      to_char(p_event.scheduled_date, 'YYYY-MM-DD')
    );

    insert into public.notifications (
      tenant_id, channel, recipient_type, recipient_id, recipient_address,
      subject, body_ar, body_en, template_key, status, sent_at,
      related_entity_table, related_entity_id
    ) values (
      p_tenant_id,
      'in_app'::public.notification_channel,
      'user',
      p_recipient_user_id,
      p_recipient_user_id::text,
      v_subject, v_body_ar, v_body_en,
      'calendar_' || p_notice_kind,
      'sent'::public.notification_status,
      now(),
      'calendar_events',
      p_event_id
    )
    returning id into v_notification_id;

    update public.calendar_meeting_notices n
    set notification_id = v_notification_id
    where n.id = v_notice_id;
  exception
    when others then
      delete from public.calendar_meeting_notices n where n.id = v_notice_id;
      raise;
  end;
end;
$$;

create or replace function public.emit_meeting_notices_for_schedule_operation(
  p_event public.calendar_events,
  p_schedule_operation_id uuid,
  p_notice_kind text,
  p_employee_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_emp record;
begin
  if p_event.type is distinct from 'internal_meeting'::public.calendar_event_type then
    return;
  end if;

  for v_emp in
    select e.id as employee_id, e.user_id
    from public.employees e
    where e.tenant_id = p_event.tenant_id
      and e.id = any (coalesce(p_employee_ids, array[]::uuid[]))
      and e.user_id is not null
  loop
    perform public.emit_calendar_meeting_notice_for_schedule_operation(
      p_event.tenant_id,
      p_event.id,
      p_notice_kind,
      v_emp.user_id,
      v_emp.employee_id,
      p_schedule_operation_id,
      p_event
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section H: schedule ledger helpers
-- ---------------------------------------------------------------------------
create or replace function public.calendar_schedule_payload_hash(p_business jsonb)
returns text
language sql
stable
set search_path = public, extensions
as $$
  select encode(
    extensions.digest(convert_to(coalesce(p_business, '{}'::jsonb)::text, 'UTF8'), 'sha256'),
    'hex'
  );
$$;

create or replace function public.resolve_calendar_schedule_idempotency(
  p_operation_type text,
  p_idempotency_key uuid,
  p_payload_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_row public.calendar_schedule_operations%rowtype;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_idempotency_key is null then
    return null;
  end if;

  select *
  into v_row
  from public.calendar_schedule_operations op
  where op.tenant_id = v_tenant_id
    and op.operation_type = p_operation_type
    and op.idempotency_key = p_idempotency_key;

  if not found then
    return null;
  end if;

  if v_row.business_payload_hash is distinct from p_payload_hash then
    raise exception 'idempotency_payload_mismatch';
  end if;

  return v_row.result_jsonb;
end;
$$;

create or replace function public.record_calendar_schedule_operation(
  p_operation_type text,
  p_idempotency_key uuid,
  p_payload_hash text,
  p_result_event_id uuid,
  p_result_jsonb jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'validation_failed';
  end if;

  insert into public.calendar_schedule_operations (
    tenant_id,
    operation_type,
    idempotency_key,
    business_payload_hash,
    result_status,
    result_event_id,
    result_jsonb,
    created_by
  )
  values (
    public.current_tenant_id(),
    p_operation_type,
    p_idempotency_key,
    p_payload_hash,
    'ok',
    p_result_event_id,
    p_result_jsonb,
    auth.uid()
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- Strict canonical YYYY-MM-DD parser. Rejects noncanonical spellings that
-- PostgreSQL's ::date cast would silently normalize ('2026-7-1', '2026/07/01',
-- timestamps, padded whitespace) as well as impossible dates ('2026-02-30').
create or replace function public.calendar_schedule_parse_strict_date(
  p_value text
)
returns date
language plpgsql
immutable
as $$
declare
  v_date date;
begin
  if p_value is null or p_value !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'validation_failed';
  end if;
  begin
    v_date := p_value::date;
  exception
    when others then
      raise exception 'validation_failed';
  end;
  if to_char(v_date, 'YYYY-MM-DD') is distinct from p_value then
    raise exception 'validation_failed';
  end if;
  return v_date;
end;
$$;

create or replace function public.assert_calendar_schedule_edit_capability()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_manager() and not public.user_has_permission('calendar.edit') then
    raise exception 'permission_denied';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section I: eligibility predicates
-- ---------------------------------------------------------------------------
-- Assignable: pending, non-meeting, manual or contract_generated.
create or replace function public.calendar_event_is_assignable(
  p_event public.calendar_events
)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    p_event.status = 'pending'::public.calendar_event_status
    and p_event.type <> 'internal_meeting'::public.calendar_event_type
    and p_event.source_kind in (
      'manual'::public.calendar_event_source_kind,
      'contract_generated'::public.calendar_event_source_kind
    );
$$;

-- Reschedulable: pending, manual or contract_generated. Internal meetings are
-- restricted to their organizer.
create or replace function public.calendar_event_is_reschedulable(
  p_event public.calendar_events
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_event.status = 'pending'::public.calendar_event_status
    and p_event.source_kind in (
      'manual'::public.calendar_event_source_kind,
      'contract_generated'::public.calendar_event_source_kind
    )
    and (
      p_event.type <> 'internal_meeting'::public.calendar_event_type
      or p_event.created_by is not distinct from auth.uid()
    );
$$;

-- ---------------------------------------------------------------------------
-- Section J: audit snapshot — extended with reschedule/override provenance
-- ---------------------------------------------------------------------------
create or replace function public.snapshot_manual_calendar_event_audit(p_event_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', ce.id,
    'tenant_id', ce.tenant_id,
    'type', ce.type,
    'status', ce.status,
    'source_kind', ce.source_kind,
    'scheduled_date', ce.scheduled_date,
    'original_due_date', ce.original_due_date,
    'title_ar', ce.title_ar,
    'title_en', ce.title_en,
    'notes', ce.notes,
    'customer_id', ce.customer_id,
    'service_location_id', ce.service_location_id,
    'contract_id', ce.contract_id,
    'assigned_agent_id', ce.assigned_agent_id,
    'scheduled_start_at', ce.scheduled_start_at,
    'scheduled_end_at', ce.scheduled_end_at,
    'scheduled_timezone_name', ce.scheduled_timezone_name,
    'free_text_team', ce.free_text_team,
    'free_text_location', ce.free_text_location,
    'meeting_mode', ce.meeting_mode,
    'meeting_url', ce.meeting_url,
    'schedule_version', ce.schedule_version,
    'created_by', ce.created_by,
    'cancellation_reason', ce.cancellation_reason,
    'completed_at', ce.completed_at,
    'completed_by', ce.completed_by,
    'reschedule_reason', ce.reschedule_reason,
    'rescheduled_at', ce.rescheduled_at,
    'rescheduled_by', ce.rescheduled_by,
    'day_off_override_reason', ce.day_off_override_reason,
    'day_off_override_at', ce.day_off_override_at,
    'day_off_override_by', ce.day_off_override_by,
    'participants', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object('employee_id', p.employee_id)
          order by p.employee_id
        )
        from public.calendar_event_participants p
        where p.tenant_id = ce.tenant_id
          and p.event_id = ce.id
      ),
      '[]'::jsonb
    )
  )
  from public.calendar_events ce
  where ce.id = p_event_id;
$$;

-- ---------------------------------------------------------------------------
-- Section K: available actions — manager OR calendar.edit capability
-- ---------------------------------------------------------------------------
create or replace function public.calendar_manual_available_actions_json(
  p_event public.calendar_events,
  p_directions_available boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_edit_cap boolean;
  v_is_manual boolean;
  v_pending boolean;
  v_is_organizer boolean;
  v_is_meeting boolean;
  v_can_manage boolean;
  v_can_open boolean;
  v_visible boolean;
begin
  -- Every event-specific action requires the caller's current row visibility,
  -- using the same predicate the mutation RPCs enforce. This keeps flags
  -- server-authoritative after e.g. an assigned-only user reassigns the event
  -- away from themselves. can_create_manual stays a global permission flag.
  v_visible :=
    auth.uid() is not null
    and public.user_has_calendar_event_visibility(
      p_event.tenant_id, auth.uid(), p_event.id
    );

  -- is_manager() short-circuits user_has_permission, but keep the explicit
  -- disjunction so mutation flags stay consistent with manager capability.
  v_edit_cap := public.is_manager() or public.user_has_permission('calendar.edit');
  v_is_manual := p_event.source_kind = 'manual'::public.calendar_event_source_kind;
  v_pending := p_event.status = 'pending'::public.calendar_event_status;
  v_is_organizer := p_event.created_by is not distinct from auth.uid();
  v_is_meeting := p_event.type = 'internal_meeting'::public.calendar_event_type;

  if v_is_meeting then
    v_can_manage := v_edit_cap and v_is_manual and v_pending and v_is_organizer;
  else
    v_can_manage := v_edit_cap and v_is_manual and v_pending;
  end if;

  v_can_open :=
    v_is_meeting
    and p_event.meeting_mode = 'online'::public.calendar_meeting_mode
    and p_event.status <> 'cancelled'::public.calendar_event_status
    and public.calendar_is_safe_https_url(p_event.meeting_url);

  return jsonb_build_object(
    'can_view_customer', v_visible and public.user_has_permission('customers.view'),
    'can_view_contract', v_visible and public.user_has_permission('contracts.view'),
    'can_assign',
      v_visible and v_edit_cap and public.calendar_event_is_assignable(p_event),
    'can_reschedule',
      v_visible and v_edit_cap and public.calendar_event_is_reschedulable(p_event),
    'can_create_manual', public.user_has_permission('calendar.create'),
    'can_open_directions', v_visible and coalesce(p_directions_available, false),
    'can_edit_manual', v_visible and v_can_manage,
    'can_cancel_manual', v_visible and v_can_manage,
    'can_mark_manual_done', v_visible and v_can_manage,
    'can_open_meeting_link', v_visible and v_can_open
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section L: participant candidates — app/tenant/calendar reachability
-- ---------------------------------------------------------------------------
create or replace function public.list_calendar_participant_candidates(
  p_search text default null,
  p_limit int default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_search text;
  v_limit int;
  v_rows jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.is_manager()
    and not public.user_has_permission('calendar.create')
    and not public.user_has_permission('calendar.edit') then
    raise exception 'permission_denied';
  end if;

  v_search := nullif(lower(btrim(coalesce(p_search, ''))), '');
  v_limit := greatest(least(coalesce(p_limit, 50), 100), 1);

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'employee_id', e.id,
        'name_ar', e.name_ar,
        'name_en', e.name_en,
        'is_active', e.is_active,
        'has_app_account', e.user_id is not null,
        'has_active_tenant_account', e.has_active_tenant_account,
        'has_calendar_access', e.has_calendar_access
      )
      order by e.name_ar, e.id
    ),
    '[]'::jsonb
  )
  into v_rows
  from (
    select
      emp.*,
      case
        when emp.has_active_tenant_account then (
          public.user_has_permission_for_tenant_user(
            v_tenant_id, emp.user_id, 'calendar.view'
          )
          or public.user_has_permission_for_tenant_user(
            v_tenant_id, emp.user_id, 'calendar.view_assigned'
          )
        )
        else false
      end as has_calendar_access
    from (
      select
        e2.*,
        (
          e2.user_id is not null
          and exists (
            select 1
            from public.tenant_users tu
            where tu.tenant_id = v_tenant_id
              and tu.user_id = e2.user_id
              and tu.is_active = true
          )
        ) as has_active_tenant_account
      from public.employees e2
      where e2.tenant_id = v_tenant_id
        and e2.is_active = true
        and (
          v_search is null
          or lower(coalesce(e2.name_ar, '')) like '%' || v_search || '%'
          or lower(coalesce(e2.name_en, '')) like '%' || v_search || '%'
          or lower(coalesce(e2.code, '')) like '%' || v_search || '%'
        )
      order by e2.name_ar, e2.id
      limit v_limit
    ) emp
  ) e;

  return jsonb_build_object('rows', coalesce(v_rows, '[]'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------------
-- Section M: read scoped events — resolve working window (M7B precedence)
-- ---------------------------------------------------------------------------
create or replace function public.calendar_read_scoped_events(
  p_tenant_id uuid,
  p_scope text,
  p_employee_id uuid,
  p_filters public.calendar_read_filter_bundle,
  p_v_today date
)
returns table (
  event_id uuid,
  scheduled_date date,
  original_due_date date,
  scheduled_start_at timestamptz,
  time_bucket int,
  assigned_agent_id uuid,
  event_status public.calendar_event_status,
  is_overdue boolean,
  overdue_days int,
  overdue_state text,
  schedule_state text,
  type_rank int,
  event_json jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  with settings as (
    select
      tcs.tenant_id,
      tcs.working_schedule_configured,
      tcs.timezone_name
    from public.tenant_calendar_settings tcs
    where tcs.tenant_id = p_tenant_id
  ),
  scoped as (
    select
      ce.id,
      ce.scheduled_date,
      ce.original_due_date,
      ce.scheduled_start_at,
      ce.scheduled_end_at,
      ce.scheduled_timezone_name,
      case when ce.scheduled_start_at is not null then 0 else 1 end as time_bucket_calc,
      ce.assigned_agent_id,
      ce.status,
      ce.type,
      ce.source_kind,
      ce.title_ar,
      ce.title_en,
      ce.notes,
      ce.rescheduled_at,
      ce.customer_id,
      ce.service_location_id,
      ce.contract_id,
      ce.contract_line_id,
      ce.day_off_override_at,
      ce.free_text_team,
      ce.free_text_location,
      ce.meeting_mode,
      ce.meeting_url,
      ce.schedule_version,
      ce.created_by,
      ce.cancellation_reason,
      e.name_ar as assigned_agent_name_ar,
      e.name_en as assigned_agent_name_en,
      cu.name_ar as customer_name_ar,
      cu.name_en as customer_name_en,
      csl.name as service_location_name,
      csl.governorate as location_governorate,
      csl.area as location_area,
      csl.latitude,
      csl.longitude,
      c.contract_number,
      cl.qty_per_refill,
      p.name_ar as product_name_ar,
      p.name_en as product_name_en,
      p.unit_primary as qty_unit,
      case
        when ce.status <> 'pending'::public.calendar_event_status then false
        when exists (
          select 1 from public.calendar_refill_execution_facts f
          where f.calendar_event_id = ce.id
        ) then false
        when p_v_today is null then false
        when ce.original_due_date < p_v_today then true
        else false
      end as is_overdue_calc,
      case
        when ce.status <> 'pending'::public.calendar_event_status then 'not_applicable'
        when exists (
          select 1 from public.calendar_refill_execution_facts f
          where f.calendar_event_id = ce.id
        ) then 'not_applicable'
        when p_v_today is null then 'schedule_unconfigured'
        when ce.original_due_date < p_v_today then 'overdue'
        else 'not_overdue'
      end as overdue_state_calc,
      public.calendar_event_schedule_state(
        coalesce((rw.w ->> 'schedule_configured')::boolean, false),
        case
          when rw.w ->> 'day_mode' is null then null
          else (rw.w ->> 'day_mode')::public.tenant_working_day_mode
        end,
        ce.day_off_override_at
      ) as schedule_state_calc,
      public.calendar_event_type_sort_rank(ce.type) as type_rank_calc,
      f.actual_completion_date,
      f.actual_quantity_delivered,
      f.quantity_unit,
      f.contracted_quantity_per_cycle,
      f.coverage_months,
      f.coverage_days,
      f.calculated_next_due_date,
      f.confirmed_next_due_date,
      f.next_due_overridden,
      ce.source_metadata,
      rw.w as working_day_json,
      public.calendar_event_participants_json(ce.tenant_id, ce.id) as participants_json,
      public.calendar_event_time_window_json(
        ce.scheduled_start_at, ce.scheduled_end_at, ce.scheduled_timezone_name
      ) as time_window_json
    from public.calendar_events ce
    cross join settings s
    left join lateral (
      select public.resolve_tenant_working_window(ce.tenant_id, ce.scheduled_date) as w
    ) rw on true
    left join public.employees e
      on e.id = ce.assigned_agent_id and e.tenant_id = ce.tenant_id
    left join public.customers cu
      on cu.id = ce.customer_id and cu.tenant_id = ce.tenant_id
    left join public.customer_service_locations csl
      on csl.id = ce.service_location_id
      and csl.tenant_id = ce.tenant_id
      and csl.customer_id = ce.customer_id
    left join public.contracts c
      on c.id = ce.contract_id and c.tenant_id = ce.tenant_id
    left join public.contract_lines cl
      on cl.id = ce.contract_line_id and cl.tenant_id = ce.tenant_id
    left join public.products p
      on p.id = cl.product_id and p.tenant_id = ce.tenant_id
    left join public.calendar_refill_execution_facts f
      on f.calendar_event_id = ce.id and f.tenant_id = ce.tenant_id
    where ce.tenant_id = p_tenant_id
      and (
        p_scope = 'tenant_wide'
        or (
          p_scope = 'assigned_only'
          and (
            ce.assigned_agent_id = p_employee_id
            or exists (
              select 1 from public.calendar_event_participants ep
              where ep.tenant_id = ce.tenant_id
                and ep.event_id = ce.id
                and ep.employee_id = p_employee_id
            )
            or (
              ce.source_kind = 'manual'::public.calendar_event_source_kind
              and ce.created_by = auth.uid()
            )
          )
        )
      )
      and (p_filters.event_types is null or ce.type = any (p_filters.event_types))
      and (p_filters.statuses is null or ce.status = any (p_filters.statuses))
      and (
        not coalesce(p_filters.unassigned_only, false)
        or ce.assigned_agent_id is null
      )
      and (
        p_filters.assigned_agent_id is null
        or ce.assigned_agent_id = p_filters.assigned_agent_id
      )
      and (
        p_filters.customer_id is null
        or (
          ce.customer_id = p_filters.customer_id
          and exists (
            select 1 from public.customers cx
            where cx.id = p_filters.customer_id and cx.tenant_id = p_tenant_id
          )
        )
      )
      and (
        p_filters.contract_id is null
        or (
          ce.contract_id = p_filters.contract_id
          and exists (
            select 1 from public.contracts cx
            where cx.id = p_filters.contract_id and cx.tenant_id = p_tenant_id
          )
        )
      )
      and (
        p_filters.service_location_id is null
        or (
          ce.service_location_id = p_filters.service_location_id
          and exists (
            select 1 from public.customer_service_locations cx
            where cx.id = p_filters.service_location_id and cx.tenant_id = p_tenant_id
          )
        )
      )
      and (p_filters.source_kind is null or ce.source_kind = p_filters.source_kind)
      and (
        not coalesce(p_filters.working_day_conflict, false)
        or public.calendar_event_schedule_state(
          coalesce((rw.w ->> 'schedule_configured')::boolean, false),
          case
            when rw.w ->> 'day_mode' is null then null
            else (rw.w ->> 'day_mode')::public.tenant_working_day_mode
          end,
          ce.day_off_override_at
        ) in ('non_working_day', 'day_off_overridden')
      )
      and (
        not coalesce(p_filters.overdue_only, false)
        or (
          ce.status = 'pending'::public.calendar_event_status
          and p_v_today is not null
          and ce.original_due_date < p_v_today
          and not exists (
            select 1 from public.calendar_refill_execution_facts fx
            where fx.calendar_event_id = ce.id
          )
        )
      )
      and (
        p_filters.search is null
        or lower(coalesce(ce.title_ar, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(ce.title_en, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(cu.name_ar, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(cu.name_en, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(c.contract_number, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(csl.name, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(e.name_ar, '')) like '%' || p_filters.search || '%'
        or lower(coalesce(e.name_en, '')) like '%' || p_filters.search || '%'
      )
  )
  select
    s.id,
    s.scheduled_date,
    s.original_due_date,
    s.scheduled_start_at,
    s.time_bucket_calc,
    s.assigned_agent_id,
    s.status,
    s.is_overdue_calc,
    case
      when s.is_overdue_calc and p_v_today is not null
        then (p_v_today - s.original_due_date)
      else 0
    end,
    s.overdue_state_calc,
    s.schedule_state_calc,
    s.type_rank_calc,
    (
      jsonb_strip_nulls(
        jsonb_build_object(
          'id', s.id,
          'type', s.type,
          'status', s.status,
          'source_kind', s.source_kind,
          'scheduled_date', s.scheduled_date,
          'original_due_date', s.original_due_date,
          'title_ar', s.title_ar,
          'title_en', s.title_en,
          'notes', s.notes,
          'is_rescheduled', s.rescheduled_at is not null,
          'assigned_agent_id', s.assigned_agent_id,
          'assigned_agent_name_ar', s.assigned_agent_name_ar,
          'assigned_agent_name_en', s.assigned_agent_name_en,
          'customer_id', s.customer_id,
          'customer_name_ar', s.customer_name_ar,
          'customer_name_en', s.customer_name_en,
          'service_location_id', s.service_location_id,
          'service_location_name', s.service_location_name,
          'location_governorate', s.location_governorate,
          'location_area', s.location_area,
          'contract_id', s.contract_id,
          'contract_number', s.contract_number,
          'contract_line_id', s.contract_line_id,
          'product_name_ar', s.product_name_ar,
          'product_name_en', s.product_name_en,
          'qty_per_refill', s.qty_per_refill,
          'qty_unit', s.qty_unit,
          'free_text_team', s.free_text_team,
          'free_text_location', s.free_text_location,
          'meeting_mode', s.meeting_mode,
          'meeting_url', s.meeting_url,
          'cancellation_reason', s.cancellation_reason,
          'operational_metadata', jsonb_strip_nulls(
            jsonb_build_object(
              'action_kind', s.source_metadata ->> 'action_kind',
              'coverage_month_key', s.source_metadata ->> 'coverage_month_key'
            )
          ),
          'directions_available',
            s.latitude is not null and s.longitude is not null,
          'schedule_state', s.schedule_state_calc,
          'working_day', s.working_day_json,
          'is_overdue', s.is_overdue_calc,
          'overdue_days',
            case
              when s.is_overdue_calc and p_v_today is not null
                then (p_v_today - s.original_due_date)
              else 0
            end,
          'overdue_state', s.overdue_state_calc,
          'available_actions', public.calendar_manual_available_actions_json(
            (select ce from public.calendar_events ce where ce.id = s.id),
            s.latitude is not null and s.longitude is not null
          )
        )
      )
      || jsonb_build_object(
        'time_window', s.time_window_json,
        'participants', coalesce(s.participants_json, '[]'::jsonb),
        'schedule_version', s.schedule_version,
        'execution_summary',
          case
            when s.actual_completion_date is null then null
            else jsonb_build_object(
              'actual_completion_date', s.actual_completion_date,
              'actual_quantity_delivered', s.actual_quantity_delivered,
              'quantity_unit', s.quantity_unit,
              'contracted_quantity_per_cycle', s.contracted_quantity_per_cycle,
              'coverage_months', s.coverage_months,
              'coverage_days', s.coverage_days,
              'calculated_next_due_date', s.calculated_next_due_date,
              'confirmed_next_due_date', s.confirmed_next_due_date,
              'next_due_overridden', s.next_due_overridden
            )
          end
      )
    )
  from scoped s;
$$;

-- ---------------------------------------------------------------------------
-- Section N: assign_calendar_event
-- ---------------------------------------------------------------------------
create or replace function public.assign_calendar_event(
  p_event_id uuid,
  p_expected_version int,
  p_data jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_event public.calendar_events%rowtype;
  v_emp public.employees%rowtype;
  v_requested_agent uuid;
  v_key text;
  v_hash text;
  v_replay jsonb;
  v_result jsonb;
  v_before jsonb;
  v_after jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_calendar_schedule_edit_capability();

  if p_event_id is null or p_expected_version is null or p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  if auth.uid() is null then
    raise exception 'validation_failed';
  end if;

  -- Normalize p_data: exactly the assigned_agent_id key, explicitly present.
  -- {} is rejected; {"assigned_agent_id": null} is an explicit unassignment.
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;
  for v_key in select jsonb_object_keys(p_data) loop
    if v_key <> 'assigned_agent_id' then
      raise exception 'validation_failed';
    end if;
  end loop;
  if not (p_data ? 'assigned_agent_id') then
    raise exception 'validation_failed';
  end if;
  v_requested_agent := public.manual_calendar_parse_optional_uuid(p_data, 'assigned_agent_id');

  v_hash := public.calendar_schedule_payload_hash(
    jsonb_build_object(
      'op', 'assign',
      'event_id', p_event_id,
      'expected_version', p_expected_version,
      'assigned_agent_id', v_requested_agent
    )
  );

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_replay := public.resolve_calendar_schedule_idempotency('assign', p_idempotency_key, v_hash);
  if v_replay is not null then
    return v_replay;
  end if;

  select * into v_event
  from public.calendar_events ce
  where ce.id = p_event_id
    and ce.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if not public.user_has_calendar_event_visibility(v_tenant_id, auth.uid(), p_event_id) then
    raise exception 'permission_denied';
  end if;

  if v_event.schedule_version is distinct from p_expected_version then
    raise exception 'stale_version';
  end if;

  if v_event.type = 'internal_meeting'::public.calendar_event_type then
    raise exception 'calendar_assignment_not_applicable';
  end if;

  if v_event.status is distinct from 'pending'::public.calendar_event_status then
    raise exception 'validation_failed';
  end if;

  if v_event.source_kind not in (
    'manual'::public.calendar_event_source_kind,
    'contract_generated'::public.calendar_event_source_kind
  ) then
    raise exception 'validation_failed';
  end if;

  -- No-op: requested assignment equals current. Ledger it (changed=false)
  -- without an audit entry or a version bump.
  if v_event.assigned_agent_id is not distinct from v_requested_agent then
    v_result := jsonb_build_object(
      'status', 'ok',
      'changed', false,
      'event', public.build_manual_calendar_event_response(p_event_id)
    );

    perform public.record_calendar_schedule_operation(
      'assign', p_idempotency_key, v_hash, p_event_id, v_result
    );

    return v_result;
  end if;

  -- Validate a non-null assignee against active tenant employees.
  if v_requested_agent is not null then
    select * into v_emp
    from public.employees e
    where e.tenant_id = v_tenant_id
      and e.id = v_requested_agent
    for update;

    if not found then
      raise exception 'validation_failed';
    end if;

    if v_emp.tenant_id is distinct from v_tenant_id or not v_emp.is_active then
      raise exception 'validation_failed';
    end if;
  end if;

  v_before := public.snapshot_manual_calendar_event_audit(p_event_id);

  update public.calendar_events ce
  set
    assigned_agent_id = v_requested_agent,
    schedule_version = ce.schedule_version + 1
  where ce.id = p_event_id;

  v_after := public.snapshot_manual_calendar_event_audit(p_event_id);

  v_result := jsonb_build_object(
    'status', 'ok',
    'changed', true,
    'event', public.build_manual_calendar_event_response(p_event_id)
  );

  perform public.record_calendar_schedule_operation(
    'assign', p_idempotency_key, v_hash, p_event_id, v_result
  );

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'assign', 'calendar_events', p_event_id,
    v_before, v_after
  );

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section O: reschedule_calendar_event
-- ---------------------------------------------------------------------------
create or replace function public.reschedule_calendar_event(
  p_event_id uuid,
  p_expected_version int,
  p_data jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_event public.calendar_events%rowtype;
  v_acks jsonb;
  v_stripped jsonb;
  v_key text;
  v_new_date date;
  v_reason text;
  v_hash text;
  v_replay jsonb;
  v_result jsonb;
  v_op_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_is_timed boolean;
  v_start_local text;
  v_end_local text;
  v_time record;
  v_new_start timestamptz;
  v_new_end timestamptz;
  v_new_tz text;
  v_participants uuid[];
  v_schedule_warnings jsonb;
  v_overlap jsonb;
  v_window jsonb;
  v_is_day_off boolean;
  v_has_non_working boolean;
  v_ack_non_working boolean;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_calendar_schedule_edit_capability();

  if p_event_id is null or p_expected_version is null or p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  if auth.uid() is null then
    raise exception 'validation_failed';
  end if;

  -- Acknowledgements never participate in the idempotency hash.
  v_acks := public.manual_calendar_extract_acknowledgements(p_data);

  -- Hashed business fields: scheduled_date + reason only.
  v_stripped := public.manual_calendar_strip_ack_keys(p_data);
  for v_key in select jsonb_object_keys(v_stripped) loop
    if v_key not in ('scheduled_date', 'reason') then
      raise exception 'validation_failed';
    end if;
  end loop;

  if not (v_stripped ? 'scheduled_date')
    or jsonb_typeof(v_stripped -> 'scheduled_date') <> 'string' then
    raise exception 'validation_failed';
  end if;
  -- Strict canonical YYYY-MM-DD: PostgreSQL's permissive ::date normalization
  -- (e.g. '2026-7-1', '2026/07/01', timestamps, padded whitespace) is not
  -- accepted; the string must round-trip exactly.
  v_new_date := public.calendar_schedule_parse_strict_date(
    v_stripped ->> 'scheduled_date'
  );

  if not (v_stripped ? 'reason')
    or jsonb_typeof(v_stripped -> 'reason') <> 'string' then
    raise exception 'validation_failed';
  end if;
  v_reason := btrim(v_stripped ->> 'reason');
  if v_reason = '' or length(v_reason) > 1000 then
    raise exception 'validation_failed';
  end if;

  v_hash := public.calendar_schedule_payload_hash(
    jsonb_build_object(
      'op', 'reschedule',
      'event_id', p_event_id,
      'expected_version', p_expected_version,
      'scheduled_date', to_char(v_new_date, 'YYYY-MM-DD'),
      'reason', v_reason
    )
  );

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_replay := public.resolve_calendar_schedule_idempotency(
    'reschedule', p_idempotency_key, v_hash
  );
  if v_replay is not null then
    return v_replay;
  end if;

  select * into v_event
  from public.calendar_events ce
  where ce.id = p_event_id
    and ce.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if not public.user_has_calendar_event_visibility(v_tenant_id, auth.uid(), p_event_id) then
    raise exception 'permission_denied';
  end if;

  if v_event.schedule_version is distinct from p_expected_version then
    raise exception 'stale_version';
  end if;

  -- Eligibility: pending (never the legacy 'rescheduled' status), manual or
  -- contract_generated; internal meetings are organizer-only.
  if v_event.status is distinct from 'pending'::public.calendar_event_status then
    raise exception 'validation_failed';
  end if;

  if v_event.source_kind not in (
    'manual'::public.calendar_event_source_kind,
    'contract_generated'::public.calendar_event_source_kind
  ) then
    raise exception 'validation_failed';
  end if;

  if v_event.type = 'internal_meeting'::public.calendar_event_type
    and v_event.created_by is distinct from auth.uid() then
    raise exception 'permission_denied';
  end if;

  -- No-op: target date equals current. Ledger it (changed=false) without
  -- touching reschedule_* provenance.
  if v_event.scheduled_date is not distinct from v_new_date then
    v_result := jsonb_build_object(
      'status', 'ok',
      'changed', false,
      'event', public.build_manual_calendar_event_response(p_event_id)
    );

    perform public.record_calendar_schedule_operation(
      'reschedule', p_idempotency_key, v_hash, p_event_id, v_result
    );

    return v_result;
  end if;

  v_is_timed :=
    v_event.scheduled_start_at is not null
    and v_event.scheduled_end_at is not null
    and v_event.scheduled_timezone_name is not null;

  if v_is_timed then
    v_start_local := to_char(
      v_event.scheduled_start_at at time zone v_event.scheduled_timezone_name, 'HH24:MI'
    );
    v_end_local := to_char(
      v_event.scheduled_end_at at time zone v_event.scheduled_timezone_name, 'HH24:MI'
    );

    -- Propagates calendar_timezone_unconfigured / validation_failed /
    -- calendar_time_window_cross_date on failure.
    select * into v_time
    from public.resolve_appointment_time_window(
      v_event.scheduled_timezone_name, v_new_date, v_start_local, v_end_local
    );

    v_new_start := v_time.start_at;
    v_new_end := v_time.end_at;
    v_new_tz := v_time.timezone_name;
  else
    v_new_start := null;
    v_new_end := null;
    v_new_tz := null;
  end if;

  v_schedule_warnings := public.detect_manual_calendar_schedule_warnings(
    v_tenant_id, v_new_date, v_new_start, v_new_end
  );

  select coalesce(array_agg(p.employee_id order by p.employee_id), array[]::uuid[])
  into v_participants
  from public.calendar_event_participants p
  where p.tenant_id = v_tenant_id
    and p.event_id = p_event_id;

  if v_is_timed and coalesce(array_length(v_participants, 1), 0) > 0 then
    perform public.acquire_calendar_conflict_locks(v_tenant_id, v_new_date, v_participants);
    v_overlap := public.detect_manual_calendar_overlap_warnings(
      v_tenant_id, v_new_date, v_new_start, v_new_end, v_participants, p_event_id
    );
  else
    v_overlap := jsonb_build_object(
      'overlap_warnings', '[]'::jsonb,
      'overlap_total_count', 0
    );
  end if;

  if public.manual_calendar_conflict_requires_confirmation(
    v_schedule_warnings,
    coalesce((v_overlap ->> 'overlap_total_count')::int, 0),
    v_acks
  ) then
    return jsonb_build_object(
      'status', 'confirmation_required',
      'code', 'calendar_conflict_confirmation_required',
      'conflicts', jsonb_build_object(
        'schedule_warnings', v_schedule_warnings,
        'overlap_warnings', v_overlap -> 'overlap_warnings',
        'overlap_total_count', v_overlap -> 'overlap_total_count'
      )
    );
  end if;

  v_window := public.resolve_tenant_working_window(v_tenant_id, v_new_date);
  v_is_day_off := coalesce((v_window ->> 'is_day_off')::boolean, false);
  v_has_non_working := exists (
    select 1
    from jsonb_array_elements(v_schedule_warnings) w
    where w.value ->> 'code' = 'non_working_day'
  );
  v_ack_non_working := coalesce((v_acks ->> 'acknowledge_non_working_day')::boolean, false);

  v_before := public.snapshot_manual_calendar_event_audit(p_event_id);

  update public.calendar_events ce
  set
    scheduled_date = v_new_date,
    scheduled_start_at = v_new_start,
    scheduled_end_at = v_new_end,
    scheduled_timezone_name = v_new_tz,
    reschedule_reason = v_reason,
    rescheduled_at = now(),
    rescheduled_by = auth.uid(),
    day_off_override_reason = case
      when v_has_non_working and v_ack_non_working then v_acks ->> 'day_off_override_reason'
      when not v_is_day_off then null
      else ce.day_off_override_reason
    end,
    day_off_override_at = case
      when v_has_non_working and v_ack_non_working then now()
      when not v_is_day_off then null
      else ce.day_off_override_at
    end,
    day_off_override_by = case
      when v_has_non_working and v_ack_non_working then auth.uid()
      when not v_is_day_off then null
      else ce.day_off_override_by
    end,
    schedule_version = ce.schedule_version + 1
  where ce.id = p_event_id;

  select * into v_event from public.calendar_events where id = p_event_id;

  v_after := public.snapshot_manual_calendar_event_audit(p_event_id);

  v_result := jsonb_build_object(
    'status', 'ok',
    'changed', true,
    'event', public.build_manual_calendar_event_response(p_event_id)
  );

  v_op_id := public.record_calendar_schedule_operation(
    'reschedule', p_idempotency_key, v_hash, p_event_id, v_result
  );

  perform public.emit_meeting_notices_for_schedule_operation(
    v_event, v_op_id, 'meeting_updated', v_participants
  );

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'reschedule', 'calendar_events', p_event_id,
    v_before, v_after
  );

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section P: Grants / revokes
-- ---------------------------------------------------------------------------
revoke all on function public.calendar_schedule_payload_hash(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.resolve_calendar_schedule_idempotency(text, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.record_calendar_schedule_operation(text, uuid, text, uuid, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.assert_calendar_schedule_edit_capability()
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_schedule_parse_strict_date(text)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_event_is_assignable(public.calendar_events)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_event_is_reschedulable(public.calendar_events)
  from public, anon, authenticated, service_role;
revoke all on function public.snapshot_manual_calendar_event_audit(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_manual_available_actions_json(
  public.calendar_events, boolean
) from public, anon, authenticated, service_role;
revoke all on function public.emit_calendar_meeting_notice(
  uuid, uuid, text, uuid, uuid, uuid, public.calendar_events
) from public, anon, authenticated, service_role;
revoke all on function public.emit_calendar_meeting_notice_for_schedule_operation(
  uuid, uuid, text, uuid, uuid, uuid, public.calendar_events
) from public, anon, authenticated, service_role;
revoke all on function public.emit_meeting_notices_for_schedule_operation(
  public.calendar_events, uuid, text, uuid[]
) from public, anon, authenticated, service_role;
revoke all on function public.calendar_read_scoped_events(
  uuid, text, uuid, public.calendar_read_filter_bundle, date
) from public, anon, authenticated, service_role;
revoke all on function public.list_calendar_participant_candidates(text, int)
  from public, anon, authenticated, service_role;
revoke all on function public.assign_calendar_event(uuid, int, jsonb, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.reschedule_calendar_event(uuid, int, jsonb, uuid)
  from public, anon, authenticated, service_role;

-- Public surface: only the two mutation RPCs and the re-created candidate list.
grant execute on function public.assign_calendar_event(uuid, int, jsonb, uuid)
  to authenticated;
grant execute on function public.reschedule_calendar_event(uuid, int, jsonb, uuid)
  to authenticated;
grant execute on function public.list_calendar_participant_candidates(text, int)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Section Q: Postflight
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.calendar_schedule_operations') is null then
    raise exception 'm8_postflight_failed: missing schedule operations ledger';
  end if;

  if not (
    select relrowsecurity
    from pg_class
    where oid = 'public.calendar_schedule_operations'::regclass
  ) then
    raise exception 'm8_postflight_failed: schedule operations RLS disabled';
  end if;

  if has_table_privilege('authenticated', 'public.calendar_schedule_operations', 'SELECT') then
    raise exception 'm8_postflight_failed: authenticated can select schedule ledger';
  end if;

  if has_table_privilege('anon', 'public.calendar_schedule_operations', 'SELECT') then
    raise exception 'm8_postflight_failed: anon can select schedule ledger';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.assign_calendar_event(uuid, int, jsonb, uuid)',
    'EXECUTE'
  ) then
    raise exception 'm8_postflight_failed: assign rpc not granted to authenticated';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.reschedule_calendar_event(uuid, int, jsonb, uuid)',
    'EXECUTE'
  ) then
    raise exception 'm8_postflight_failed: reschedule rpc not granted to authenticated';
  end if;

  if has_function_privilege(
    'anon',
    'public.assign_calendar_event(uuid, int, jsonb, uuid)',
    'EXECUTE'
  )
    or has_function_privilege(
      'anon',
      'public.reschedule_calendar_event(uuid, int, jsonb, uuid)',
      'EXECUTE'
    ) then
    raise exception 'm8_postflight_failed: anon can execute schedule mutation rpc';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.record_calendar_schedule_operation(text, uuid, text, uuid, jsonb)',
    'EXECUTE'
  )
    or has_function_privilege(
      'authenticated',
      'public.calendar_schedule_payload_hash(jsonb)',
      'EXECUTE'
    )
    or has_function_privilege(
      'authenticated',
      'public.resolve_calendar_schedule_idempotency(text, uuid, text)',
      'EXECUTE'
    )
    or has_function_privilege(
      'authenticated',
      'public.assert_calendar_schedule_edit_capability()',
      'EXECUTE'
    )
    or has_function_privilege(
      'authenticated',
      'public.calendar_schedule_parse_strict_date(text)',
      'EXECUTE'
    ) then
    raise exception 'm8_postflight_failed: schedule helper executable by authenticated';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_calendar_meeting_notices_operation_xor'
      and conrelid = 'public.calendar_meeting_notices'::regclass
  ) then
    raise exception 'm8_postflight_failed: missing meeting notice XOR constraint';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'fk_calendar_events_assigned_agent'
      and conrelid = 'public.calendar_events'::regclass
      and contype = 'f'
  ) then
    raise exception 'm8_postflight_failed: missing composite assignee FK';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'ux_calendar_schedule_operations_idem'
      and conrelid = 'public.calendar_schedule_operations'::regclass
      and contype = 'u'
  ) then
    raise exception 'm8_postflight_failed: missing schedule operations idempotency unique';
  end if;

  if not (
    select attnotnull
    from pg_attribute
    where attrelid = 'public.calendar_schedule_operations'::regclass
      and attname = 'created_by'
  ) then
    raise exception 'm8_postflight_failed: schedule operations created_by is nullable';
  end if;

  if to_regclass('public.ux_calendar_meeting_notices_recipient_manual_op') is null
    or to_regclass('public.ux_calendar_meeting_notices_recipient_schedule_op') is null then
    raise exception 'm8_postflight_failed: missing meeting notice partial uniques';
  end if;
end $$;
