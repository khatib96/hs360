-- Phase 7 M3: Calendar reminder foundation — logical-occurrence ledger, cursor-paginated
-- reconcile, multi-instant DST anchors, recipient-scoped notification RLS, subtransaction delivery.

-- ---------------------------------------------------------------------------
-- Section A: Preflight
-- ---------------------------------------------------------------------------
do $$
declare
  v_missed int;
begin
  if to_regprocedure('public.sanitize_sql_error_code(text)') is null then
    raise exception 'migration_preflight_failed: missing_095_sanitize_sql_error_code';
  end if;

  if to_regclass('public.calendar_generation_runs') is null then
    raise exception 'migration_preflight_failed: missing_095_calendar_generation_runs';
  end if;

  select count(*)
  into v_missed
  from public.calendar_events ce
  where ce.status = 'missed'::public.calendar_event_status;

  raise notice 'migration_preflight: legacy_missed_calendar_events (%)', v_missed;
end $$;

-- ---------------------------------------------------------------------------
-- Section B: Enums
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'calendar_reminder_rule_key') then
    create type public.calendar_reminder_rule_key as enum (
      'event_workday_start',
      'previous_workday_start'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'calendar_reminder_plan_status') then
    create type public.calendar_reminder_plan_status as enum (
      'planned',
      'delivery_pending',
      'suppressed',
      'skipped',
      'delivered',
      'expired',
      'cancelled_superseded',
      'cancelled_event',
      'failed'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'calendar_dst_resolution_code') then
    create type public.calendar_dst_resolution_code as enum (
      'none',
      'dst_ambiguous_earlier',
      'dst_shifted_forward'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section C: Tables, constraints, indexes
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_reminder_plans (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  calendar_event_id uuid not null,
  rule_key public.calendar_reminder_rule_key not null,
  occurrence_scheduled_date date not null,
  channel public.notification_channel not null default 'in_app',
  recipient_user_id uuid,
  recipient_employee_id uuid,
  anchor_local_date date,
  anchor_local_time time,
  anchor_utc timestamptz,
  timezone_name text,
  dst_resolution_code public.calendar_dst_resolution_code,
  dst_shift_seconds int,
  status public.calendar_reminder_plan_status not null,
  resolution_code text,
  suppressed_reason text,
  attempt_count int not null default 0,
  next_attempt_at timestamptz,
  notification_id uuid references public.notifications (id) on delete restrict,
  delivered_at timestamptz,
  cancelled_at timestamptz,
  last_error_code text,
  last_error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ux_calendar_reminder_plans_occurrence
    unique (tenant_id, calendar_event_id, rule_key, occurrence_scheduled_date),
  constraint fk_calendar_reminder_plans_event
    foreign key (tenant_id, calendar_event_id)
    references public.calendar_events (tenant_id, id)
    on delete restrict,
  constraint chk_calendar_reminder_plans_channel
    check (channel = 'in_app'::public.notification_channel),
  constraint chk_calendar_reminder_plans_attempt_count
    check (attempt_count >= 0),
  constraint chk_calendar_reminder_plans_anchor_tuple
    check (
      (
        anchor_local_date is null
        and anchor_local_time is null
        and anchor_utc is null
        and timezone_name is null
        and dst_resolution_code is null
      )
      or (
        anchor_local_date is not null
        and anchor_local_time is not null
        and anchor_utc is not null
        and timezone_name is not null
        and btrim(timezone_name) <> ''
        and dst_resolution_code is not null
      )
    ),
  constraint chk_calendar_reminder_plans_anchor_required_deliverable
    check (
      not (
        status in (
          'planned'::public.calendar_reminder_plan_status,
          'delivery_pending'::public.calendar_reminder_plan_status,
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status
        )
      )
      or (
        anchor_local_date is not null
        and anchor_local_time is not null
        and anchor_utc is not null
        and timezone_name is not null
        and dst_resolution_code is not null
      )
    ),
  constraint chk_calendar_reminder_plans_skipped_day_off_anchors
    check (
      not (
        status = 'skipped'::public.calendar_reminder_plan_status
        and resolution_code = 'event_date_day_off'
      )
      or (
        anchor_local_date is null
        and anchor_local_time is null
        and anchor_utc is null
        and timezone_name is null
        and dst_resolution_code is null
      )
    ),
  constraint chk_calendar_reminder_plans_suppressed_setup_anchors
    check (
      not (
        status = 'suppressed'::public.calendar_reminder_plan_status
        and suppressed_reason in (
          'schedule_unconfigured',
          'timezone_missing',
          'timezone_invalid',
          'policy_disabled',
          'no_assigned_recipient',
          'recipient_not_calendar_authorized'
        )
      )
      or anchor_utc is null
    ),
  constraint chk_calendar_reminder_plans_delivery_notification
    check (
      (
        status = 'delivered'::public.calendar_reminder_plan_status
        and notification_id is not null
        and delivered_at is not null
      )
      or (
        status <> 'delivered'::public.calendar_reminder_plan_status
        and notification_id is null
        and delivered_at is null
      )
    ),
  constraint chk_calendar_reminder_plans_cancelled_at
    check (
      (
        status in (
          'cancelled_superseded'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status
        )
        and cancelled_at is not null
      )
      or (
        status not in (
          'cancelled_superseded'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status
        )
        and cancelled_at is null
      )
    ),
  constraint chk_calendar_reminder_plans_resolution_code
    check (
      (
        status in (
          'skipped'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status
        )
        and resolution_code is not null
      )
      or (
        status not in (
          'skipped'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status
        )
        and resolution_code is null
      )
    ),
  constraint chk_calendar_reminder_plans_suppressed_reason
    check (
      (
        status = 'suppressed'::public.calendar_reminder_plan_status
        and suppressed_reason is not null
      )
      or (
        status <> 'suppressed'::public.calendar_reminder_plan_status
        and suppressed_reason is null
      )
    ),
  constraint chk_calendar_reminder_plans_recipient_deliverable
    check (
      (
        status in (
          'planned'::public.calendar_reminder_plan_status,
          'delivery_pending'::public.calendar_reminder_plan_status,
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status
        )
        and recipient_user_id is not null
      )
      or (
        status not in (
          'planned'::public.calendar_reminder_plan_status,
          'delivery_pending'::public.calendar_reminder_plan_status,
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status
        )
      )
    ),
  constraint chk_calendar_reminder_plans_delivery_pending_retry
    check (
      not (
        status = 'delivery_pending'::public.calendar_reminder_plan_status
        and attempt_count > 0
      )
      or next_attempt_at is not null
    ),
  constraint chk_calendar_reminder_plans_terminal_no_retry
    check (
      not (
        status in (
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status,
          'cancelled_superseded'::public.calendar_reminder_plan_status
        )
      )
      or next_attempt_at is null
    ),
  constraint chk_calendar_reminder_plans_dst_shift
    check (
      (
        dst_resolution_code = 'dst_shifted_forward'::public.calendar_dst_resolution_code
        and dst_shift_seconds is not null
        and dst_shift_seconds > 0
      )
      or (
        dst_resolution_code is distinct from 'dst_shifted_forward'::public.calendar_dst_resolution_code
        and dst_shift_seconds is null
      )
    )
);

create index if not exists idx_calendar_reminder_plans_due
  on public.calendar_reminder_plans (tenant_id, status, anchor_utc)
  where status in (
    'planned'::public.calendar_reminder_plan_status,
    'delivery_pending'::public.calendar_reminder_plan_status
  );

create index if not exists idx_calendar_reminder_plans_event_status
  on public.calendar_reminder_plans (calendar_event_id, status);

create index if not exists idx_calendar_reminder_plans_tenant_open
  on public.calendar_reminder_plans (tenant_id, status)
  where status in (
    'suppressed'::public.calendar_reminder_plan_status,
    'skipped'::public.calendar_reminder_plan_status,
    'planned'::public.calendar_reminder_plan_status,
    'delivery_pending'::public.calendar_reminder_plan_status
  );

create unique index if not exists ux_calendar_reminder_plans_notification_id
  on public.calendar_reminder_plans (notification_id)
  where notification_id is not null;

create table if not exists public.calendar_reminder_reconcile_queue (
  tenant_id uuid primary key references public.tenants (id) on delete cascade,
  generation bigint not null default 1,
  scan_generation bigint not null default 1,
  scan_after_event_id uuid,
  enqueued_at timestamptz not null default now(),
  processing_generation bigint,
  processed_generation bigint
);

create table if not exists public.calendar_reminder_runs (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null default 'running'
    check (status in ('running', 'completed', 'partial', 'failed', 'skipped_duplicate')),
  plans_delivered int not null default 0,
  plans_failed int not null default 0,
  plans_retried int not null default 0,
  plans_expired int not null default 0,
  plans_suppressed int not null default 0,
  tenants_reconciled int not null default 0,
  tenants_failed int not null default 0,
  error_summary text
);

-- ---------------------------------------------------------------------------
-- Section D: Notification hardening
-- ---------------------------------------------------------------------------
drop policy if exists notifications_select on public.notifications;

create policy notifications_select_own on public.notifications
  for select using (
    tenant_id = public.current_tenant_id()
    and recipient_type = 'user'
    and recipient_id = auth.uid()
  );

create policy notifications_select_tenant on public.notifications
  for select using (
    tenant_id = public.current_tenant_id()
    and public.user_has_permission('notifications.view')
  );

create unique index if not exists ux_notifications_calendar_reminder_delivery
  on public.notifications (tenant_id, related_entity_table, related_entity_id, channel)
  where related_entity_table = 'calendar_reminder_plans'
    and channel = 'in_app'::public.notification_channel;

-- ---------------------------------------------------------------------------
-- Section E: DST probe + previous working day
-- ---------------------------------------------------------------------------
create or replace function public.local_work_start_to_utc(
  p_timezone text,
  p_date date,
  p_time time
)
returns table (
  anchor_utc timestamptz,
  dst_resolution_code public.calendar_dst_resolution_code,
  dst_shift_seconds int
)
language plpgsql
immutable
set search_path = public
as $$
declare
  v_naive timestamp;
  v_base_utc timestamptz;
  v_probe timestamptz;
  v_local timestamp;
  v_offset interval;
  v_candidates timestamptz[] := '{}';
  v_shifted timestamptz;
  v_shift_seconds int;
  v_sorted timestamptz[];
  v_n int;
begin
  if p_timezone is null or btrim(p_timezone) = '' or p_date is null or p_time is null then
    raise exception 'validation_failed';
  end if;

  v_naive := (p_date + p_time)::timestamp;
  v_base_utc := v_naive at time zone p_timezone;
  v_offset := make_interval(hours => -16);

  while v_offset <= make_interval(hours => 16) loop
    v_probe := v_base_utc + v_offset;
    v_local := (v_probe at time zone p_timezone)::timestamp;
    if v_local = v_naive and not v_probe = any (v_candidates) then
      v_candidates := array_append(v_candidates, v_probe);
    end if;
    v_offset := v_offset + make_interval(mins => 15);
  end loop;

  select coalesce(array_agg(c order by c), '{}'::timestamptz[])
  into v_sorted
  from unnest(v_candidates) as c;

  v_n := coalesce(array_length(v_sorted, 1), 0);

  if v_n = 0 then
    v_shifted := v_naive at time zone p_timezone;
    v_shift_seconds := extract(
      epoch from ((v_shifted at time zone p_timezone)::timestamp - v_naive)
    )::int;
    anchor_utc := v_shifted;
    dst_resolution_code := 'dst_shifted_forward'::public.calendar_dst_resolution_code;
    dst_shift_seconds := v_shift_seconds;
    return next;
    return;
  end if;

  if v_n = 1 then
    anchor_utc := v_sorted[1];
    dst_resolution_code := 'none'::public.calendar_dst_resolution_code;
    dst_shift_seconds := null;
    return next;
    return;
  end if;

  if v_n = 2 then
    anchor_utc := v_sorted[1];
    dst_resolution_code := 'dst_ambiguous_earlier'::public.calendar_dst_resolution_code;
    dst_shift_seconds := null;
    return next;
    return;
  end if;

  raise exception 'dst_probe_unexpected_candidate_count';
end;
$$;

create or replace function public.find_previous_working_day(
  p_tenant_id uuid,
  p_date date,
  p_horizon_days int default 366
)
returns date
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_cursor date;
  v_window jsonb;
  v_steps int := 0;
begin
  if p_tenant_id is null or p_date is null then
    return null;
  end if;

  v_cursor := p_date - 1;

  while v_steps < greatest(coalesce(p_horizon_days, 366), 1) loop
    v_window := public.resolve_tenant_working_window(p_tenant_id, v_cursor);

    if coalesce(v_window ->> 'is_unreviewed', 'false')::boolean = false
      and nullif(v_window ->> 'day_mode', '') is not null
      and coalesce(v_window ->> 'is_day_off', 'false')::boolean = false then
      return v_cursor;
    end if;

    v_cursor := v_cursor - 1;
    v_steps := v_steps + 1;
  end loop;

  return null;
end;
$$;

create or replace function public.reminder_delivery_backoff_minutes(p_attempt_count int)
returns int
language sql
immutable
set search_path = public
as $$
  select case greatest(coalesce(p_attempt_count, 1), 1)
    when 1 then 1
    when 2 then 5
    when 3 then 15
    else 60
  end;
$$;

-- ---------------------------------------------------------------------------
-- Section F: Tenant-scoped permission + calendar visibility
-- ---------------------------------------------------------------------------
create or replace function public.user_has_permission_for_tenant_user(
  p_tenant_id uuid,
  p_user_id uuid,
  p_permission_id text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_account_type public.user_account_type;
begin
  if p_tenant_id is null or p_user_id is null or p_permission_id is null then
    return false;
  end if;

  select tu.account_type
  into v_account_type
  from public.tenant_users tu
  where tu.tenant_id = p_tenant_id
    and tu.user_id = p_user_id
    and tu.is_active = true;

  if not found then
    return false;
  end if;

  if v_account_type = 'manager'::public.user_account_type then
    return true;
  end if;

  return exists (
    select 1
    from public.user_permissions up
    join public.tenant_users tu
      on tu.id = up.tenant_user_id
    where up.tenant_id = p_tenant_id
      and tu.tenant_id = p_tenant_id
      and tu.user_id = p_user_id
      and tu.is_active = true
      and up.permission_id = p_permission_id
  );
end;
$$;

create or replace function public.user_has_calendar_event_visibility(
  p_tenant_id uuid,
  p_user_id uuid,
  p_event_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_event public.calendar_events%rowtype;
  v_employee_id uuid;
begin
  if p_tenant_id is null or p_user_id is null or p_event_id is null then
    return false;
  end if;

  select *
  into v_event
  from public.calendar_events ce
  where ce.id = p_event_id;

  if not found or v_event.tenant_id is distinct from p_tenant_id then
    return false;
  end if;

  if public.user_has_permission_for_tenant_user(
    p_tenant_id,
    p_user_id,
    'calendar.view'
  ) then
    return true;
  end if;

  if public.user_has_permission_for_tenant_user(
    p_tenant_id,
    p_user_id,
    'calendar.view_assigned'
  ) then
    select e.id
    into v_employee_id
    from public.employees e
    where e.tenant_id = p_tenant_id
      and e.user_id = p_user_id
      and e.is_active = true
    limit 1;

    return v_employee_id is not null
      and v_event.assigned_agent_id is not distinct from v_employee_id;
  end if;

  return false;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section G: Reconcile generation bump
-- ---------------------------------------------------------------------------
create or replace function public.bump_reminder_reconcile_generation(p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_tenant_id is null then
    return;
  end if;

  if not exists (
    select 1
    from public.tenants t
    where t.id = p_tenant_id
  ) then
    return;
  end if;

  insert into public.calendar_reminder_reconcile_queue (
    tenant_id,
    generation,
    scan_generation,
    enqueued_at
  )
  values (
    p_tenant_id,
    1,
    1,
    now()
  )
  on conflict (tenant_id) do update
  set
    generation = public.calendar_reminder_reconcile_queue.generation + 1,
    enqueued_at = now(),
    scan_after_event_id = null,
    processed_generation = null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section H: Cancel helpers + rule application + refresh
-- ---------------------------------------------------------------------------
create or replace function public.cancel_open_calendar_reminder_plans_for_event(
  p_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.calendar_reminder_plans crp
  set
    status = 'cancelled_event'::public.calendar_reminder_plan_status,
    cancelled_at = now(),
    next_attempt_at = null,
    suppressed_reason = null,
    resolution_code = null,
    updated_at = now()
  where crp.calendar_event_id = p_event_id
    and crp.status in (
      'planned'::public.calendar_reminder_plan_status,
      'delivery_pending'::public.calendar_reminder_plan_status,
      'suppressed'::public.calendar_reminder_plan_status,
      'skipped'::public.calendar_reminder_plan_status,
      'cancelled_superseded'::public.calendar_reminder_plan_status
    );
end;
$$;

create or replace function public.cancel_superseded_calendar_reminder_occurrences(
  p_event_id uuid,
  p_current_scheduled_date date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.calendar_reminder_plans crp
  set
    status = 'cancelled_superseded'::public.calendar_reminder_plan_status,
    cancelled_at = now(),
    next_attempt_at = null,
    suppressed_reason = null,
    resolution_code = null,
    updated_at = now()
  where crp.calendar_event_id = p_event_id
    and crp.occurrence_scheduled_date is distinct from p_current_scheduled_date
    and crp.status not in (
      'delivered'::public.calendar_reminder_plan_status,
      'expired'::public.calendar_reminder_plan_status,
      'failed'::public.calendar_reminder_plan_status,
      'cancelled_event'::public.calendar_reminder_plan_status
    );
end;
$$;

create or replace function public.resolve_calendar_reminder_recipient(
  p_tenant_id uuid,
  p_assigned_agent_id uuid
)
returns table (
  recipient_user_id uuid,
  recipient_employee_id uuid,
  suppressed_reason text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_employee public.employees%rowtype;
begin
  if p_assigned_agent_id is null then
    recipient_user_id := null;
    recipient_employee_id := null;
    suppressed_reason := 'no_assigned_recipient';
    return next;
    return;
  end if;

  select *
  into v_employee
  from public.employees e
  where e.id = p_assigned_agent_id
    and e.tenant_id = p_tenant_id;

  if not found
    or not v_employee.is_active
    or v_employee.user_id is null then
    recipient_user_id := null;
    recipient_employee_id := null;
    suppressed_reason := 'no_assigned_recipient';
    return next;
    return;
  end if;

  if not exists (
    select 1
    from public.tenant_users tu
    where tu.tenant_id = p_tenant_id
      and tu.user_id = v_employee.user_id
      and tu.is_active = true
  ) then
    recipient_user_id := null;
    recipient_employee_id := null;
    suppressed_reason := 'no_assigned_recipient';
    return next;
    return;
  end if;

  recipient_user_id := v_employee.user_id;
  recipient_employee_id := v_employee.id;
  suppressed_reason := null;
  return next;
end;
$$;

create or replace function public.apply_calendar_reminder_rule_plan(
  p_event public.calendar_events,
  p_settings public.tenant_calendar_settings,
  p_rule_key public.calendar_reminder_rule_key,
  p_policy_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.calendar_reminder_plans%rowtype;
  v_recipient record;
  v_anchor_date date;
  v_window jsonb;
  v_local_time time;
  v_dst record;
  v_status public.calendar_reminder_plan_status;
  v_resolution_code text;
  v_suppressed_reason text;
  v_anchor_local_date date;
  v_anchor_local_time time;
  v_anchor_utc timestamptz;
  v_timezone_name text;
  v_dst_code public.calendar_dst_resolution_code;
  v_dst_shift_seconds int;
  v_reactivate boolean;
  v_reset_retry boolean;
  v_existing_found boolean;
begin
  select *
  into v_existing
  from public.calendar_reminder_plans crp
  where crp.tenant_id = p_event.tenant_id
    and crp.calendar_event_id = p_event.id
    and crp.rule_key = p_rule_key
    and crp.occurrence_scheduled_date = p_event.scheduled_date;

  v_existing_found := found;

  if not coalesce(p_settings.working_schedule_configured, false) then
    if v_existing_found then
      update public.calendar_reminder_plans crp
      set
        status = 'suppressed'::public.calendar_reminder_plan_status,
        suppressed_reason = 'schedule_unconfigured',
        resolution_code = null,
        anchor_local_date = null,
        anchor_local_time = null,
        anchor_utc = null,
        timezone_name = null,
        dst_resolution_code = null,
        dst_shift_seconds = null,
        recipient_user_id = null,
        recipient_employee_id = null,
        cancelled_at = null,
        next_attempt_at = null,
        updated_at = now()
      where crp.id = v_existing.id
        and crp.status not in (
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status
        );
    end if;
    return;
  end if;

  if p_settings.timezone_name is null then
    if v_existing_found then
      update public.calendar_reminder_plans crp
      set
        status = 'suppressed'::public.calendar_reminder_plan_status,
        suppressed_reason = 'timezone_missing',
        resolution_code = null,
        anchor_local_date = null,
        anchor_local_time = null,
        anchor_utc = null,
        timezone_name = null,
        dst_resolution_code = null,
        dst_shift_seconds = null,
        recipient_user_id = null,
        recipient_employee_id = null,
        cancelled_at = null,
        next_attempt_at = null,
        updated_at = now()
      where crp.id = v_existing.id
        and crp.status not in (
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status
        );
    end if;
    return;
  end if;

  if not public.is_valid_iana_timezone(p_settings.timezone_name) then
    if v_existing_found then
      update public.calendar_reminder_plans crp
      set
        status = 'suppressed'::public.calendar_reminder_plan_status,
        suppressed_reason = 'timezone_invalid',
        resolution_code = null,
        anchor_local_date = null,
        anchor_local_time = null,
        anchor_utc = null,
        timezone_name = null,
        dst_resolution_code = null,
        dst_shift_seconds = null,
        recipient_user_id = null,
        recipient_employee_id = null,
        cancelled_at = null,
        next_attempt_at = null,
        updated_at = now()
      where crp.id = v_existing.id
        and crp.status not in (
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status
        );
    end if;
    return;
  end if;

  if not coalesce(p_policy_enabled, false) then
    if v_existing_found then
      update public.calendar_reminder_plans crp
      set
        status = 'suppressed'::public.calendar_reminder_plan_status,
        suppressed_reason = 'policy_disabled',
        resolution_code = null,
        anchor_local_date = null,
        anchor_local_time = null,
        anchor_utc = null,
        timezone_name = null,
        dst_resolution_code = null,
        dst_shift_seconds = null,
        recipient_user_id = null,
        recipient_employee_id = null,
        cancelled_at = null,
        next_attempt_at = null,
        updated_at = now()
      where crp.id = v_existing.id
        and crp.status not in (
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status
        );
    end if;
    return;
  end if;

  select *
  into v_recipient
  from public.resolve_calendar_reminder_recipient(
    p_event.tenant_id,
    p_event.assigned_agent_id
  ) r;

  if v_recipient.suppressed_reason is not null then
    if v_existing_found then
      update public.calendar_reminder_plans crp
      set
        status = 'suppressed'::public.calendar_reminder_plan_status,
        suppressed_reason = v_recipient.suppressed_reason,
        resolution_code = null,
        anchor_local_date = null,
        anchor_local_time = null,
        anchor_utc = null,
        timezone_name = null,
        dst_resolution_code = null,
        dst_shift_seconds = null,
        recipient_user_id = null,
        recipient_employee_id = null,
        cancelled_at = null,
        next_attempt_at = null,
        updated_at = now()
      where crp.id = v_existing.id
        and crp.status not in (
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status
        );
    end if;
    return;
  end if;

  if not public.user_has_calendar_event_visibility(
    p_event.tenant_id,
    v_recipient.recipient_user_id,
    p_event.id
  ) then
    if v_existing_found then
      update public.calendar_reminder_plans crp
      set
        status = 'suppressed'::public.calendar_reminder_plan_status,
        suppressed_reason = 'recipient_not_calendar_authorized',
        resolution_code = null,
        anchor_local_date = null,
        anchor_local_time = null,
        anchor_utc = null,
        timezone_name = null,
        dst_resolution_code = null,
        dst_shift_seconds = null,
        recipient_user_id = null,
        recipient_employee_id = null,
        cancelled_at = null,
        next_attempt_at = null,
        updated_at = now()
      where crp.id = v_existing.id
        and crp.status not in (
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status
        );
    end if;
    return;
  end if;

  if p_rule_key = 'event_workday_start'::public.calendar_reminder_rule_key then
    v_anchor_date := p_event.scheduled_date;
    v_window := public.resolve_tenant_working_window(p_event.tenant_id, v_anchor_date);

    if coalesce(v_window ->> 'is_day_off', 'false')::boolean
      or coalesce(v_window ->> 'is_unreviewed', 'false')::boolean
      or nullif(v_window ->> 'day_mode', '') is null then
      v_status := 'skipped'::public.calendar_reminder_plan_status;
      v_resolution_code := 'event_date_day_off';
      v_suppressed_reason := null;
      v_anchor_local_date := null;
      v_anchor_local_time := null;
      v_anchor_utc := null;
      v_timezone_name := null;
      v_dst_code := null;
      v_dst_shift_seconds := null;
    else
      if coalesce(v_window ->> 'is_24_hours', 'false')::boolean then
        v_local_time := make_time(0, 0, 0);
      elsif coalesce(v_window ->> 'is_working_hours', 'false')::boolean then
        v_local_time := (v_window ->> 'work_start')::time;
      else
        v_status := 'skipped'::public.calendar_reminder_plan_status;
        v_resolution_code := 'event_date_day_off';
        v_suppressed_reason := null;
        v_anchor_local_date := null;
        v_anchor_local_time := null;
        v_anchor_utc := null;
        v_timezone_name := null;
        v_dst_code := null;
        v_dst_shift_seconds := null;
      end if;

      if v_local_time is not null then
        select *
        into v_dst
        from public.local_work_start_to_utc(
          p_settings.timezone_name,
          v_anchor_date,
          v_local_time
        ) d;

        v_status := 'planned'::public.calendar_reminder_plan_status;
        v_resolution_code := null;
        v_suppressed_reason := null;
        v_anchor_local_date := v_anchor_date;
        v_anchor_local_time := v_local_time;
        v_anchor_utc := v_dst.anchor_utc;
        v_timezone_name := p_settings.timezone_name;
        v_dst_code := v_dst.dst_resolution_code;
        v_dst_shift_seconds := v_dst.dst_shift_seconds;
      end if;
    end if;
  else
    v_anchor_date := public.find_previous_working_day(
      p_event.tenant_id,
      p_event.scheduled_date,
      366
    );

    if v_anchor_date is null then
      v_status := 'skipped'::public.calendar_reminder_plan_status;
      v_resolution_code := 'no_prior_working_day_in_horizon';
      v_suppressed_reason := null;
      v_anchor_local_date := null;
      v_anchor_local_time := null;
      v_anchor_utc := null;
      v_timezone_name := null;
      v_dst_code := null;
      v_dst_shift_seconds := null;
    else
      v_window := public.resolve_tenant_working_window(p_event.tenant_id, v_anchor_date);

      if coalesce(v_window ->> 'is_24_hours', 'false')::boolean then
        v_local_time := make_time(0, 0, 0);
      elsif coalesce(v_window ->> 'is_working_hours', 'false')::boolean then
        v_local_time := (v_window ->> 'work_start')::time;
      else
        v_status := 'skipped'::public.calendar_reminder_plan_status;
        v_resolution_code := 'no_prior_working_day_in_horizon';
        v_suppressed_reason := null;
        v_anchor_local_date := null;
        v_anchor_local_time := null;
        v_anchor_utc := null;
        v_timezone_name := null;
        v_dst_code := null;
        v_dst_shift_seconds := null;
        v_local_time := null;
      end if;

      if v_local_time is not null then
        select *
        into v_dst
        from public.local_work_start_to_utc(
          p_settings.timezone_name,
          v_anchor_date,
          v_local_time
        ) d;

        v_status := 'planned'::public.calendar_reminder_plan_status;
        v_resolution_code := null;
        v_suppressed_reason := null;
        v_anchor_local_date := v_anchor_date;
        v_anchor_local_time := v_local_time;
        v_anchor_utc := v_dst.anchor_utc;
        v_timezone_name := p_settings.timezone_name;
        v_dst_code := v_dst.dst_resolution_code;
        v_dst_shift_seconds := v_dst.dst_shift_seconds;
      end if;
    end if;
  end if;

  if v_existing_found then
    if v_existing.status in (
      'delivered'::public.calendar_reminder_plan_status,
      'expired'::public.calendar_reminder_plan_status,
      'failed'::public.calendar_reminder_plan_status,
      'cancelled_event'::public.calendar_reminder_plan_status
    ) then
      return;
    end if;

    v_reactivate := v_existing.status in (
      'suppressed'::public.calendar_reminder_plan_status,
      'skipped'::public.calendar_reminder_plan_status,
      'cancelled_superseded'::public.calendar_reminder_plan_status
    )
    and v_status is distinct from v_existing.status;

    v_reset_retry :=
      v_status in (
        'planned'::public.calendar_reminder_plan_status,
        'delivery_pending'::public.calendar_reminder_plan_status
      )
      and (
        v_reactivate
        or v_existing.recipient_user_id is distinct from v_recipient.recipient_user_id
        or v_existing.recipient_employee_id is distinct from v_recipient.recipient_employee_id
        or v_existing.anchor_local_date is distinct from v_anchor_local_date
        or v_existing.anchor_local_time is distinct from v_anchor_local_time
        or v_existing.anchor_utc is distinct from v_anchor_utc
        or v_existing.timezone_name is distinct from v_timezone_name
        or v_existing.dst_resolution_code is distinct from v_dst_code
        or v_existing.dst_shift_seconds is distinct from v_dst_shift_seconds
      );

    -- Reconciliation must not bypass retry backoff by demoting an unchanged
    -- due plan to planned and letting the scheduler promote it again.
    if v_existing.status = 'delivery_pending'::public.calendar_reminder_plan_status
      and v_status = 'planned'::public.calendar_reminder_plan_status
      and not v_reset_retry then
      v_status := 'delivery_pending'::public.calendar_reminder_plan_status;
    end if;

    update public.calendar_reminder_plans crp
    set
      status = v_status,
      resolution_code = v_resolution_code,
      suppressed_reason = v_suppressed_reason,
      anchor_local_date = v_anchor_local_date,
      anchor_local_time = v_anchor_local_time,
      anchor_utc = v_anchor_utc,
      timezone_name = v_timezone_name,
      dst_resolution_code = v_dst_code,
      dst_shift_seconds = v_dst_shift_seconds,
      recipient_user_id = case
        when v_status in (
          'planned'::public.calendar_reminder_plan_status,
          'delivery_pending'::public.calendar_reminder_plan_status,
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status
        ) then v_recipient.recipient_user_id
        else null
      end,
      recipient_employee_id = case
        when v_status in (
          'planned'::public.calendar_reminder_plan_status,
          'delivery_pending'::public.calendar_reminder_plan_status,
          'delivered'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status
        ) then v_recipient.recipient_employee_id
        else null
      end,
      cancelled_at = case
        when v_existing.status = 'cancelled_superseded'::public.calendar_reminder_plan_status
          and v_status <> 'cancelled_superseded'::public.calendar_reminder_plan_status
          then null
        when v_reactivate then null
        else crp.cancelled_at
      end,
      last_error_code = case when v_reactivate or v_reset_retry then null else crp.last_error_code end,
      last_error_message = case when v_reactivate or v_reset_retry then null else crp.last_error_message end,
      attempt_count = case when v_reactivate or v_reset_retry then 0 else crp.attempt_count end,
      next_attempt_at = case when v_reactivate or v_reset_retry then null else crp.next_attempt_at end,
      updated_at = now()
    where crp.id = v_existing.id;

    return;
  end if;

  insert into public.calendar_reminder_plans (
    tenant_id,
    calendar_event_id,
    rule_key,
    occurrence_scheduled_date,
    channel,
    recipient_user_id,
    recipient_employee_id,
    anchor_local_date,
    anchor_local_time,
    anchor_utc,
    timezone_name,
    dst_resolution_code,
    dst_shift_seconds,
    status,
    resolution_code,
    suppressed_reason
  )
  values (
    p_event.tenant_id,
    p_event.id,
    p_rule_key,
    p_event.scheduled_date,
    'in_app'::public.notification_channel,
    case
      when v_status in (
        'planned'::public.calendar_reminder_plan_status,
        'delivery_pending'::public.calendar_reminder_plan_status,
        'delivered'::public.calendar_reminder_plan_status,
        'expired'::public.calendar_reminder_plan_status,
        'failed'::public.calendar_reminder_plan_status
      ) then v_recipient.recipient_user_id
      else null
    end,
    case
      when v_status in (
        'planned'::public.calendar_reminder_plan_status,
        'delivery_pending'::public.calendar_reminder_plan_status,
        'delivered'::public.calendar_reminder_plan_status,
        'expired'::public.calendar_reminder_plan_status,
        'failed'::public.calendar_reminder_plan_status
      ) then v_recipient.recipient_employee_id
      else null
    end,
    v_anchor_local_date,
    v_anchor_local_time,
    v_anchor_utc,
    v_timezone_name,
    v_dst_code,
    v_dst_shift_seconds,
    v_status,
    v_resolution_code,
    v_suppressed_reason
  );
end;
$$;

create or replace function public.refresh_calendar_event_reminder_plans(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.calendar_events%rowtype;
  v_settings public.tenant_calendar_settings%rowtype;
begin
  select *
  into v_event
  from public.calendar_events ce
  where ce.id = p_event_id
  for update;

  if not found then
    return;
  end if;

  if v_event.status <> 'pending'::public.calendar_event_status then
    perform public.cancel_open_calendar_reminder_plans_for_event(v_event.id);
    return;
  end if;

  select *
  into v_settings
  from public.tenant_calendar_settings tcs
  where tcs.tenant_id = v_event.tenant_id;

  if not found then
    return;
  end if;

  perform public.cancel_superseded_calendar_reminder_occurrences(
    v_event.id,
    v_event.scheduled_date
  );

  perform public.apply_calendar_reminder_rule_plan(
    v_event,
    v_settings,
    'event_workday_start'::public.calendar_reminder_rule_key,
    v_settings.remind_event_workday_start
  );

  perform public.apply_calendar_reminder_rule_plan(
    v_event,
    v_settings,
    'previous_workday_start'::public.calendar_reminder_rule_key,
    v_settings.remind_previous_workday_start
  );
end;
$$;

create or replace function public.reconcile_tenant_calendar_reminder_plans(
  p_tenant_id uuid,
  p_batch_size int default 500
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_queue public.calendar_reminder_reconcile_queue%rowtype;
  v_batch_size int;
  v_event_ids uuid[];
  v_batch_count int;
  v_last_id uuid;
  v_event_id uuid;
begin
  if p_tenant_id is null then
    return;
  end if;

  v_batch_size := greatest(coalesce(p_batch_size, 500), 1);

  select *
  into v_queue
  from public.calendar_reminder_reconcile_queue q
  where q.tenant_id = p_tenant_id
  for update;

  if not found then
    return;
  end if;

  if v_queue.scan_generation is distinct from v_queue.generation then
    update public.calendar_reminder_reconcile_queue q
    set
      scan_generation = v_queue.generation,
      scan_after_event_id = null
    where q.tenant_id = p_tenant_id;

    v_queue.scan_generation := v_queue.generation;
    v_queue.scan_after_event_id := null;
  end if;

  update public.calendar_reminder_reconcile_queue q
  set processing_generation = v_queue.generation
  where q.tenant_id = p_tenant_id;

  select array_agg(ce.id order by ce.id)
  into v_event_ids
  from (
    select ce.id
    from public.calendar_events ce
    where ce.tenant_id = p_tenant_id
      and ce.status = 'pending'::public.calendar_event_status
      and (
        v_queue.scan_after_event_id is null
        or ce.id > v_queue.scan_after_event_id
      )
    order by ce.id
    limit v_batch_size
  ) ce;

  v_batch_count := coalesce(array_length(v_event_ids, 1), 0);

  if v_batch_count = 0 then
    update public.calendar_reminder_reconcile_queue q
    set
      processed_generation = v_queue.generation,
      scan_after_event_id = null,
      processing_generation = null
    where q.tenant_id = p_tenant_id
      and q.generation = v_queue.generation;
    return;
  end if;

  foreach v_event_id in array v_event_ids loop
    perform public.refresh_calendar_event_reminder_plans(v_event_id);
  end loop;

  v_last_id := v_event_ids[v_batch_count];

  if v_batch_count >= v_batch_size then
    update public.calendar_reminder_reconcile_queue q
    set
      scan_after_event_id = v_last_id,
      processing_generation = null
    where q.tenant_id = p_tenant_id;
    return;
  end if;

  update public.calendar_reminder_reconcile_queue q
  set
    processed_generation = v_queue.generation,
    scan_after_event_id = null,
    processing_generation = null
  where q.tenant_id = p_tenant_id
    and q.generation = v_queue.generation;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section I: Delivery + failure recording
-- ---------------------------------------------------------------------------
create or replace function public.record_reminder_delivery_failure(
  p_plan_id uuid,
  p_sqlstate text,
  p_sqlerrm text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan public.calendar_reminder_plans%rowtype;
  v_new_attempt int;
begin
  select *
  into v_plan
  from public.calendar_reminder_plans crp
  where crp.id = p_plan_id
  for update;

  if not found then
    return;
  end if;

  if v_plan.status <> 'delivery_pending'::public.calendar_reminder_plan_status then
    return;
  end if;

  v_new_attempt := v_plan.attempt_count + 1;

  if v_new_attempt >= 5 then
    update public.calendar_reminder_plans crp
    set
      status = 'failed'::public.calendar_reminder_plan_status,
      attempt_count = v_new_attempt,
      next_attempt_at = null,
      last_error_code = public.sanitize_sql_error_code(p_sqlstate),
      last_error_message = left(coalesce(p_sqlerrm, ''), 500),
      updated_at = now()
    where crp.id = p_plan_id;
    return;
  end if;

  update public.calendar_reminder_plans crp
  set
    attempt_count = v_new_attempt,
    next_attempt_at = now()
      + make_interval(
        mins => public.reminder_delivery_backoff_minutes(v_new_attempt)
      ),
    last_error_code = public.sanitize_sql_error_code(p_sqlstate),
    last_error_message = left(coalesce(p_sqlerrm, ''), 500),
    updated_at = now()
  where crp.id = p_plan_id;
end;
$$;

create or replace function public.deliver_calendar_reminder_plan_locked(p_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan public.calendar_reminder_plans%rowtype;
  v_event public.calendar_events%rowtype;
  v_settings public.tenant_calendar_settings%rowtype;
  v_local_today date;
  v_notification_id uuid;
  v_subject_ar text;
  v_body_ar text;
  v_body_en text;
  v_policy_enabled boolean;
begin
  select *
  into v_plan
  from public.calendar_reminder_plans crp
  where crp.id = p_plan_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_plan.status <> 'delivery_pending'::public.calendar_reminder_plan_status then
    return;
  end if;

  if v_plan.notification_id is not null then
    return;
  end if;

  -- Settings, schedule, identity, or permission changes are reconciled in
  -- cursor-sized batches. Never deliver a snapshot while its tenant still has
  -- an unfinished generation.
  if exists (
    select 1
    from public.calendar_reminder_reconcile_queue q
    where q.tenant_id = v_plan.tenant_id
      and (
        q.generation is distinct from q.processed_generation
        or q.scan_after_event_id is not null
        or q.processing_generation is not null
      )
  ) then
    return;
  end if;

  select *
  into v_event
  from public.calendar_events ce
  where ce.id = v_plan.calendar_event_id
    and ce.tenant_id = v_plan.tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  -- Recompute the occurrence under the event lock. An unchanged due plan
  -- remains delivery_pending; any date, assignment, identity, permission,
  -- timezone, schedule, or policy change moves it out of the deliverable state.
  perform public.refresh_calendar_event_reminder_plans(v_event.id);

  select *
  into v_plan
  from public.calendar_reminder_plans crp
  where crp.id = p_plan_id
  for update;

  if not found
    or v_plan.status <> 'delivery_pending'::public.calendar_reminder_plan_status
    or v_plan.notification_id is not null then
    return;
  end if;

  if v_event.status <> 'pending'::public.calendar_event_status then
    return;
  end if;

  if v_event.scheduled_date is distinct from v_plan.occurrence_scheduled_date
    or v_event.assigned_agent_id is distinct from v_plan.recipient_employee_id then
    return;
  end if;

  select *
  into v_settings
  from public.tenant_calendar_settings tcs
  where tcs.tenant_id = v_plan.tenant_id;

  if not found
    or not v_settings.working_schedule_configured
    or v_settings.timezone_name is null
    or not public.is_valid_iana_timezone(v_settings.timezone_name) then
    update public.calendar_reminder_plans crp
    set
      status = 'suppressed'::public.calendar_reminder_plan_status,
      suppressed_reason = case
        when not coalesce(v_settings.working_schedule_configured, false)
          then 'schedule_unconfigured'
        when v_settings.timezone_name is null then 'timezone_missing'
        else 'timezone_invalid'
      end,
      resolution_code = null,
      anchor_local_date = null,
      anchor_local_time = null,
      anchor_utc = null,
      timezone_name = null,
      dst_resolution_code = null,
      dst_shift_seconds = null,
      recipient_user_id = null,
      recipient_employee_id = null,
      cancelled_at = null,
      next_attempt_at = null,
      updated_at = now()
    where crp.id = v_plan.id;
    return;
  end if;

  v_policy_enabled := case v_plan.rule_key
    when 'event_workday_start'::public.calendar_reminder_rule_key
      then v_settings.remind_event_workday_start
    when 'previous_workday_start'::public.calendar_reminder_rule_key
      then v_settings.remind_previous_workday_start
    else false
  end;

  if not v_policy_enabled then
    update public.calendar_reminder_plans crp
    set
      status = 'suppressed'::public.calendar_reminder_plan_status,
      suppressed_reason = 'policy_disabled',
      resolution_code = null,
      anchor_local_date = null,
      anchor_local_time = null,
      anchor_utc = null,
      timezone_name = null,
      dst_resolution_code = null,
      dst_shift_seconds = null,
      recipient_user_id = null,
      recipient_employee_id = null,
      cancelled_at = null,
      next_attempt_at = null,
      updated_at = now()
    where crp.id = v_plan.id;
    return;
  end if;

  if v_plan.recipient_user_id is null then
    update public.calendar_reminder_plans crp
    set
      status = 'suppressed'::public.calendar_reminder_plan_status,
      suppressed_reason = 'no_assigned_recipient',
      resolution_code = null,
      anchor_local_date = null,
      anchor_local_time = null,
      anchor_utc = null,
      timezone_name = null,
      dst_resolution_code = null,
      dst_shift_seconds = null,
      recipient_user_id = null,
      recipient_employee_id = null,
      cancelled_at = null,
      next_attempt_at = null,
      updated_at = now()
    where crp.id = v_plan.id;
    return;
  end if;

  if not exists (
    select 1
    from public.tenant_users tu
    where tu.tenant_id = v_plan.tenant_id
      and tu.user_id = v_plan.recipient_user_id
      and tu.is_active = true
  ) then
    update public.calendar_reminder_plans crp
    set
      status = 'suppressed'::public.calendar_reminder_plan_status,
      suppressed_reason = 'no_assigned_recipient',
      resolution_code = null,
      anchor_local_date = null,
      anchor_local_time = null,
      anchor_utc = null,
      timezone_name = null,
      dst_resolution_code = null,
      dst_shift_seconds = null,
      recipient_user_id = null,
      recipient_employee_id = null,
      cancelled_at = null,
      next_attempt_at = null,
      updated_at = now()
    where crp.id = v_plan.id;
    return;
  end if;

  if not exists (
    select 1
    from public.employees e
    where e.id = v_plan.recipient_employee_id
      and e.tenant_id = v_plan.tenant_id
      and e.user_id = v_plan.recipient_user_id
      and e.is_active = true
      and e.id = v_event.assigned_agent_id
  ) then
    update public.calendar_reminder_plans crp
    set
      status = 'suppressed'::public.calendar_reminder_plan_status,
      suppressed_reason = 'no_assigned_recipient',
      resolution_code = null,
      anchor_local_date = null,
      anchor_local_time = null,
      anchor_utc = null,
      timezone_name = null,
      dst_resolution_code = null,
      dst_shift_seconds = null,
      recipient_user_id = null,
      recipient_employee_id = null,
      cancelled_at = null,
      next_attempt_at = null,
      updated_at = now()
    where crp.id = v_plan.id;
    return;
  end if;

  if not public.user_has_calendar_event_visibility(
    v_plan.tenant_id,
    v_plan.recipient_user_id,
    v_event.id
  ) then
    update public.calendar_reminder_plans crp
    set
      status = 'suppressed'::public.calendar_reminder_plan_status,
      suppressed_reason = 'recipient_not_calendar_authorized',
      resolution_code = null,
      anchor_local_date = null,
      anchor_local_time = null,
      anchor_utc = null,
      timezone_name = null,
      dst_resolution_code = null,
      dst_shift_seconds = null,
      recipient_user_id = null,
      recipient_employee_id = null,
      cancelled_at = null,
      next_attempt_at = null,
      updated_at = now()
    where crp.id = v_plan.id;
    return;
  end if;

  v_local_today := public.try_tenant_local_today(v_plan.tenant_id);

  if v_local_today is null
    or v_plan.anchor_local_date is distinct from v_local_today then
    update public.calendar_reminder_plans crp
    set
      status = 'expired'::public.calendar_reminder_plan_status,
      resolution_code = 'anchor_local_day_passed',
      suppressed_reason = null,
      next_attempt_at = null,
      updated_at = now()
    where crp.id = v_plan.id;
    return;
  end if;

  v_subject_ar := coalesce(v_event.title_ar, v_event.title_en, 'تذكير تقويم');
  v_body_ar := format(
    '%s — %s — %s',
    coalesce(v_event.title_ar, v_event.title_en, ''),
    v_event.type::text,
    to_char(v_event.scheduled_date, 'YYYY-MM-DD')
  );
  v_body_en := format(
    '%s — %s — %s',
    coalesce(v_event.title_en, v_event.title_ar, ''),
    v_event.type::text,
    to_char(v_event.scheduled_date, 'YYYY-MM-DD')
  );

  insert into public.notifications (
    tenant_id,
    channel,
    recipient_type,
    recipient_id,
    recipient_address,
    subject,
    body_ar,
    body_en,
    template_key,
    status,
    sent_at,
    related_entity_table,
    related_entity_id
  )
  values (
    v_plan.tenant_id,
    'in_app'::public.notification_channel,
    'user',
    v_plan.recipient_user_id,
    v_plan.recipient_user_id::text,
    v_subject_ar,
    v_body_ar,
    v_body_en,
    'calendar_reminder_' || v_plan.rule_key::text,
    'sent'::public.notification_status,
    now(),
    'calendar_reminder_plans',
    v_plan.id
  )
  returning id into v_notification_id;

  update public.calendar_reminder_plans crp
  set
    status = 'delivered'::public.calendar_reminder_plan_status,
    notification_id = v_notification_id,
    delivered_at = now(),
    suppressed_reason = null,
    resolution_code = null,
    next_attempt_at = null,
    last_error_code = null,
    last_error_message = null,
    updated_at = now()
  where crp.id = v_plan.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section J: Scheduler
-- ---------------------------------------------------------------------------
create or replace function public.run_scheduled_calendar_reminders(
  p_batch_size int default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_run_id uuid;
  v_batch_size int;
  v_tenant record;
  v_plan record;
  v_delivered int := 0;
  v_failed int := 0;
  v_retried int := 0;
  v_expired int := 0;
  v_suppressed int := 0;
  v_tenants_reconciled int := 0;
  v_tenants_failed int := 0;
  v_error_summary text;
  v_local_today date;
begin
  if not pg_try_advisory_xact_lock(hashtext('calendar_reminders_batch')) then
    return jsonb_build_object('status', 'skipped_duplicate');
  end if;

  v_batch_size := greatest(coalesce(p_batch_size, 100), 1);

  insert into public.calendar_reminder_runs (status)
  values ('running')
  returning id into v_run_id;

  for v_tenant in
    select q.tenant_id
    from public.calendar_reminder_reconcile_queue q
    where q.generation is distinct from q.processed_generation
      or q.scan_after_event_id is not null
      or q.processing_generation is not null
    order by q.enqueued_at, q.tenant_id
  loop
    begin
      perform public.reconcile_tenant_calendar_reminder_plans(v_tenant.tenant_id, 500);
      v_tenants_reconciled := v_tenants_reconciled + 1;
    exception
      when others then
        v_tenants_failed := v_tenants_failed + 1;
        v_error_summary := concat_ws(
          '; ',
          v_error_summary,
          format(
            'tenant=%s code=%s error=%s',
            v_tenant.tenant_id,
            public.sanitize_sql_error_code(sqlstate),
            left(sqlerrm, 200)
          )
        );
    end;
  end loop;

  with promoted as (
    update public.calendar_reminder_plans crp
    set
      status = case
        when crp.anchor_local_date = public.try_tenant_local_today(crp.tenant_id)
          then 'delivery_pending'::public.calendar_reminder_plan_status
        else 'expired'::public.calendar_reminder_plan_status
      end,
      resolution_code = case
        when crp.anchor_local_date = public.try_tenant_local_today(crp.tenant_id)
          then null
        else 'anchor_local_day_passed'
      end,
      suppressed_reason = null,
      next_attempt_at = null,
      updated_at = now()
    where crp.status = 'planned'::public.calendar_reminder_plan_status
      and crp.anchor_utc is not null
      and crp.anchor_utc <= now()
      and not exists (
        select 1
        from public.calendar_reminder_reconcile_queue q
        where q.tenant_id = crp.tenant_id
          and (
            q.generation is distinct from q.processed_generation
            or q.scan_after_event_id is not null
            or q.processing_generation is not null
          )
      )
    returning crp.status as new_status
  )
  select
    count(*) filter (
      where new_status = 'expired'::public.calendar_reminder_plan_status
    )
  into v_expired
  from promoted;

  for v_plan in
    select crp.id
    from public.calendar_reminder_plans crp
    where crp.status = 'delivery_pending'::public.calendar_reminder_plan_status
      and crp.anchor_utc is not null
      and crp.anchor_utc <= now()
      and (
        crp.next_attempt_at is null
        or crp.next_attempt_at <= now()
      )
      and not exists (
        select 1
        from public.calendar_reminder_reconcile_queue q
        where q.tenant_id = crp.tenant_id
          and (
            q.generation is distinct from q.processed_generation
            or q.scan_after_event_id is not null
            or q.processing_generation is not null
          )
      )
    order by crp.anchor_utc, crp.id
    limit v_batch_size
    for update skip locked
  loop
    begin
      perform public.deliver_calendar_reminder_plan_locked(v_plan.id);

      if exists (
        select 1
        from public.calendar_reminder_plans crp
        where crp.id = v_plan.id
          and crp.status = 'delivered'::public.calendar_reminder_plan_status
      ) then
        v_delivered := v_delivered + 1;
      elsif exists (
        select 1
        from public.calendar_reminder_plans crp
        where crp.id = v_plan.id
          and crp.status = 'expired'::public.calendar_reminder_plan_status
      ) then
        v_expired := v_expired + 1;
      elsif exists (
        select 1
        from public.calendar_reminder_plans crp
        where crp.id = v_plan.id
          and crp.status = 'suppressed'::public.calendar_reminder_plan_status
      ) then
        v_suppressed := v_suppressed + 1;
      end if;
    exception
      when others then
        perform public.record_reminder_delivery_failure(
          v_plan.id,
          sqlstate,
          sqlerrm
        );

        if exists (
          select 1
          from public.calendar_reminder_plans crp
          where crp.id = v_plan.id
            and crp.status = 'failed'::public.calendar_reminder_plan_status
        ) then
          v_failed := v_failed + 1;
        elsif exists (
          select 1
          from public.calendar_reminder_plans crp
          where crp.id = v_plan.id
            and crp.status = 'delivery_pending'::public.calendar_reminder_plan_status
            and crp.attempt_count > 0
        ) then
          v_retried := v_retried + 1;
        end if;
    end;
  end loop;

  v_error_summary := concat_ws(
    '; ',
    v_error_summary,
    case when v_failed > 0 then format('plans_failed=%s', v_failed) end,
    case when v_retried > 0 then format('plans_retried=%s', v_retried) end
  );
  if v_error_summary = '' then
    v_error_summary := null;
  end if;

  update public.calendar_reminder_runs r
  set
    completed_at = clock_timestamp(),
    status = case
      when (v_failed > 0 or v_tenants_failed > 0)
        and v_delivered = 0
        and v_retried = 0
        and v_tenants_reconciled = 0 then 'failed'
      when v_failed > 0 or v_retried > 0 or v_tenants_failed > 0 then 'partial'
      else 'completed'
    end,
    plans_delivered = v_delivered,
    plans_failed = v_failed,
    plans_retried = v_retried,
    plans_expired = v_expired,
    plans_suppressed = v_suppressed,
    tenants_reconciled = v_tenants_reconciled,
    tenants_failed = v_tenants_failed,
    error_summary = v_error_summary
  where r.id = v_run_id;

  return jsonb_build_object(
    'run_id', v_run_id,
    'status', (
      select rr.status
      from public.calendar_reminder_runs rr
      where rr.id = v_run_id
    ),
    'plans_delivered', v_delivered,
    'plans_failed', v_failed,
    'plans_retried', v_retried,
    'plans_expired', v_expired,
    'plans_suppressed', v_suppressed,
    'tenants_reconciled', v_tenants_reconciled,
    'tenants_failed', v_tenants_failed
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section K: Immutability trigger
-- ---------------------------------------------------------------------------
create or replace function public.enforce_calendar_reminder_plan_snapshot_immutability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status in (
    'delivered'::public.calendar_reminder_plan_status,
    'expired'::public.calendar_reminder_plan_status,
    'failed'::public.calendar_reminder_plan_status
  ) then
    if new.status is distinct from old.status then
      raise exception 'validation_failed';
    end if;

    if new.occurrence_scheduled_date is distinct from old.occurrence_scheduled_date
      or new.rule_key is distinct from old.rule_key
      or new.anchor_local_date is distinct from old.anchor_local_date
      or new.anchor_local_time is distinct from old.anchor_local_time
      or new.anchor_utc is distinct from old.anchor_utc
      or new.timezone_name is distinct from old.timezone_name
      or new.dst_resolution_code is distinct from old.dst_resolution_code
      or new.dst_shift_seconds is distinct from old.dst_shift_seconds
      or new.recipient_user_id is distinct from old.recipient_user_id
      or new.recipient_employee_id is distinct from old.recipient_employee_id
      or new.channel is distinct from old.channel
      or new.notification_id is distinct from old.notification_id
      or new.delivered_at is distinct from old.delivered_at
      or new.resolution_code is distinct from old.resolution_code then
      raise exception 'validation_failed';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_calendar_reminder_plans_snapshot_immutability
  on public.calendar_reminder_plans;
create trigger trg_calendar_reminder_plans_snapshot_immutability
  before update on public.calendar_reminder_plans
  for each row
  execute function public.enforce_calendar_reminder_plan_snapshot_immutability();

drop trigger if exists trg_touch_calendar_reminder_plans on public.calendar_reminder_plans;
create trigger trg_touch_calendar_reminder_plans
  before update on public.calendar_reminder_plans
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Section L: Enqueue triggers
-- ---------------------------------------------------------------------------
create or replace function public.trg_enqueue_reminder_reconcile_tenant_calendar_settings()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.bump_reminder_reconcile_generation(new.tenant_id);
  return new;
end;
$$;

create or replace function public.trg_enqueue_reminder_reconcile_tenant_working_days()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.bump_reminder_reconcile_generation(
    coalesce(new.tenant_id, old.tenant_id)
  );
  return coalesce(new, old);
end;
$$;

create or replace function public.trg_enqueue_reminder_reconcile_employees()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.bump_reminder_reconcile_generation(new.tenant_id);
    return new;
  elsif tg_op = 'DELETE' then
    perform public.bump_reminder_reconcile_generation(old.tenant_id);
    return old;
  end if;

  if old.tenant_id is distinct from new.tenant_id then
    perform public.bump_reminder_reconcile_generation(old.tenant_id);
    perform public.bump_reminder_reconcile_generation(new.tenant_id);
  elsif old.is_active is distinct from new.is_active
    or old.user_id is distinct from new.user_id then
    perform public.bump_reminder_reconcile_generation(new.tenant_id);
  end if;

  return new;
end;
$$;

create or replace function public.trg_enqueue_reminder_reconcile_tenant_users()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.bump_reminder_reconcile_generation(new.tenant_id);
    return new;
  elsif tg_op = 'DELETE' then
    perform public.bump_reminder_reconcile_generation(old.tenant_id);
    return old;
  end if;

  if old.tenant_id is distinct from new.tenant_id then
    perform public.bump_reminder_reconcile_generation(old.tenant_id);
    perform public.bump_reminder_reconcile_generation(new.tenant_id);
  elsif old.is_active is distinct from new.is_active
    or old.user_id is distinct from new.user_id
    or old.account_type is distinct from new.account_type then
    perform public.bump_reminder_reconcile_generation(new.tenant_id);
  end if;

  return new;
end;
$$;

create or replace function public.trg_enqueue_reminder_reconcile_user_permissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_relevant boolean;
  v_new_relevant boolean;
begin
  v_old_relevant := tg_op in ('UPDATE', 'DELETE')
    and old.permission_id in ('calendar.view', 'calendar.view_assigned');
  v_new_relevant := tg_op in ('INSERT', 'UPDATE')
    and new.permission_id in ('calendar.view', 'calendar.view_assigned');

  if tg_op = 'INSERT' then
    if v_new_relevant then
      perform public.bump_reminder_reconcile_generation(new.tenant_id);
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    if v_old_relevant then
      perform public.bump_reminder_reconcile_generation(old.tenant_id);
    end if;
    return old;
  end if;

  if old.tenant_id is distinct from new.tenant_id then
    if v_old_relevant then
      perform public.bump_reminder_reconcile_generation(old.tenant_id);
    end if;
    if v_new_relevant then
      perform public.bump_reminder_reconcile_generation(new.tenant_id);
    end if;
  elsif v_old_relevant or v_new_relevant then
    perform public.bump_reminder_reconcile_generation(new.tenant_id);
  end if;

  return new;
end;
$$;

create or replace function public.trg_refresh_calendar_event_reminder_plans()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.refresh_calendar_event_reminder_plans(new.id);
  return new;
end;
$$;

drop trigger if exists trg_tenant_calendar_settings_reminder_enqueue
  on public.tenant_calendar_settings;
create trigger trg_tenant_calendar_settings_reminder_enqueue
  after insert or update on public.tenant_calendar_settings
  for each row
  execute function public.trg_enqueue_reminder_reconcile_tenant_calendar_settings();

drop trigger if exists trg_tenant_working_days_reminder_enqueue
  on public.tenant_working_days;
create trigger trg_tenant_working_days_reminder_enqueue
  after insert or update or delete on public.tenant_working_days
  for each row
  execute function public.trg_enqueue_reminder_reconcile_tenant_working_days();

drop trigger if exists trg_employees_reminder_enqueue on public.employees;
create trigger trg_employees_reminder_enqueue
  after insert or update or delete on public.employees
  for each row
  execute function public.trg_enqueue_reminder_reconcile_employees();

drop trigger if exists trg_tenant_users_reminder_enqueue on public.tenant_users;
create trigger trg_tenant_users_reminder_enqueue
  after insert or update or delete on public.tenant_users
  for each row
  execute function public.trg_enqueue_reminder_reconcile_tenant_users();

drop trigger if exists trg_user_permissions_reminder_enqueue on public.user_permissions;
create trigger trg_user_permissions_reminder_enqueue
  after insert or update or delete on public.user_permissions
  for each row
  execute function public.trg_enqueue_reminder_reconcile_user_permissions();

drop trigger if exists trg_calendar_events_reminder_refresh on public.calendar_events;
create trigger trg_calendar_events_reminder_refresh
  after insert or update of scheduled_date, assigned_agent_id, status
  on public.calendar_events
  for each row
  execute function public.trg_refresh_calendar_event_reminder_plans();

-- ---------------------------------------------------------------------------
-- Section M: RLS + ACL
-- ---------------------------------------------------------------------------
alter table public.calendar_reminder_plans enable row level security;
alter table public.calendar_reminder_reconcile_queue enable row level security;
alter table public.calendar_reminder_runs enable row level security;

revoke all on table public.calendar_reminder_plans
  from public, anon, authenticated, service_role;
revoke all on table public.calendar_reminder_reconcile_queue
  from public, anon, authenticated, service_role;
revoke all on table public.calendar_reminder_runs
  from public, anon, authenticated, service_role;

revoke all on function public.local_work_start_to_utc(text, date, time)
  from public, anon, authenticated, service_role;
revoke all on function public.find_previous_working_day(uuid, date, int)
  from public, anon, authenticated, service_role;
revoke all on function public.reminder_delivery_backoff_minutes(int)
  from public, anon, authenticated, service_role;
revoke all on function public.user_has_permission_for_tenant_user(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.user_has_calendar_event_visibility(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.bump_reminder_reconcile_generation(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.cancel_open_calendar_reminder_plans_for_event(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.cancel_superseded_calendar_reminder_occurrences(uuid, date)
  from public, anon, authenticated, service_role;
revoke all on function public.resolve_calendar_reminder_recipient(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.apply_calendar_reminder_rule_plan(
  public.calendar_events,
  public.tenant_calendar_settings,
  public.calendar_reminder_rule_key,
  boolean
) from public, anon, authenticated, service_role;
revoke all on function public.refresh_calendar_event_reminder_plans(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.reconcile_tenant_calendar_reminder_plans(uuid, int)
  from public, anon, authenticated, service_role;
revoke all on function public.record_reminder_delivery_failure(uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all on function public.deliver_calendar_reminder_plan_locked(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.run_scheduled_calendar_reminders(int)
  from public, anon, authenticated, service_role;
revoke all on function public.enforce_calendar_reminder_plan_snapshot_immutability()
  from public, anon, authenticated, service_role;
revoke all on function public.trg_enqueue_reminder_reconcile_tenant_calendar_settings()
  from public, anon, authenticated, service_role;
revoke all on function public.trg_enqueue_reminder_reconcile_tenant_working_days()
  from public, anon, authenticated, service_role;
revoke all on function public.trg_enqueue_reminder_reconcile_employees()
  from public, anon, authenticated, service_role;
revoke all on function public.trg_enqueue_reminder_reconcile_tenant_users()
  from public, anon, authenticated, service_role;
revoke all on function public.trg_enqueue_reminder_reconcile_user_permissions()
  from public, anon, authenticated, service_role;
revoke all on function public.trg_refresh_calendar_event_reminder_plans()
  from public, anon, authenticated, service_role;

grant execute on function public.run_scheduled_calendar_reminders(int) to postgres;

-- ---------------------------------------------------------------------------
-- Section N: Backfill (queue only — zero plans/notifications)
-- ---------------------------------------------------------------------------
do $$
declare
  v_before_reminder_notifications int;
begin
  select count(*)
  into v_before_reminder_notifications
  from public.notifications n
  where n.related_entity_table = 'calendar_reminder_plans';

  insert into public.calendar_reminder_reconcile_queue (
    tenant_id,
    generation,
    scan_generation,
    enqueued_at
  )
  select
    tcs.tenant_id,
    1,
    1,
    now()
  from public.tenant_calendar_settings tcs
  where tcs.working_schedule_configured = true
    and tcs.timezone_name is not null
    and public.is_valid_iana_timezone(tcs.timezone_name)
  on conflict (tenant_id) do nothing;

  perform set_config(
    'hs360.m3_preflight_reminder_notification_count',
    v_before_reminder_notifications::text,
    true
  );
end $$;

-- ---------------------------------------------------------------------------
-- Section O: Postflight
-- ---------------------------------------------------------------------------
do $$
declare
  v_before int;
  v_after int;
begin
  if to_regclass('public.ux_notifications_calendar_reminder_delivery') is null then
    raise exception 'migration_postflight_failed: missing_notification_partial_unique';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'notifications_select_own'
  ) then
    raise exception 'migration_postflight_failed: missing_notifications_select_own';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'notifications_select_tenant'
  ) then
    raise exception 'migration_postflight_failed: missing_notifications_select_tenant';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'refresh_calendar_event_reminder_plans'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ) then
    raise exception 'migration_postflight_failed: authenticated_can_execute_refresh';
  end if;

  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    where t.relname = 'calendar_reminder_plans'
      and c.conname = 'fk_calendar_reminder_plans_event'
      and c.confdeltype = 'r'
  ) then
    raise exception 'migration_postflight_failed: event_fk_not_restrict';
  end if;

  v_before := coalesce(
    current_setting('hs360.m3_preflight_reminder_notification_count', true),
    '0'
  )::int;

  select count(*)
  into v_after
  from public.notifications n
  where n.related_entity_table = 'calendar_reminder_plans';

  if v_after is distinct from v_before then
    raise exception
      'migration_postflight_failed: reminder_notification_count_changed (% -> %)',
      v_before,
      v_after;
  end if;
end $$;
