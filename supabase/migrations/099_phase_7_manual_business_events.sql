-- Phase 7 M7A (part 2): manual business events — schema, mutation RPCs,
-- reminder fan-out, organizer scope, dual list/overdue order, meeting notices.
-- Depends on committed 098 enum ADD VALUE barrier.
-- Do not edit 096/097 sources; supersede via CREATE OR REPLACE / ALTER here.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Section A: Preflight
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'calendar_event_type'
      and e.enumlabel = 'customer_visit'
  ) then
    raise exception 'migration_preflight_failed: missing_098_customer_visit';
  end if;

  if to_regclass('public.calendar_reminder_plans') is null then
    raise exception 'migration_preflight_failed: missing_096_reminder_plans';
  end if;

  if to_regprocedure(
    'public.calendar_read_scoped_events(uuid, text, uuid, public.calendar_read_filter_bundle, date)'
  ) is null then
    raise exception 'migration_preflight_failed: missing_097_scoped_events';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section B: Employees composite unique (participant FK prerequisite)
-- ---------------------------------------------------------------------------
create unique index if not exists ux_employees_tenant_id_id
  on public.employees (tenant_id, id);

-- ---------------------------------------------------------------------------
-- Section C: Meeting mode enum + calendar_events columns / CHECKs
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'calendar_meeting_mode'
  ) then
    create type public.calendar_meeting_mode as enum ('in_person', 'online');
  end if;
end $$;

alter table public.calendar_events
  add column if not exists scheduled_start_at timestamptz,
  add column if not exists scheduled_end_at timestamptz,
  add column if not exists scheduled_timezone_name text,
  add column if not exists free_text_team text,
  add column if not exists free_text_location text,
  add column if not exists cancellation_reason text,
  add column if not exists meeting_mode public.calendar_meeting_mode,
  add column if not exists meeting_url text;

alter table public.calendar_events
  drop constraint if exists chk_calendar_events_time_window_triple;

alter table public.calendar_events
  add constraint chk_calendar_events_time_window_triple check (
    (
      scheduled_start_at is null
      and scheduled_end_at is null
      and scheduled_timezone_name is null
    )
    or (
      scheduled_start_at is not null
      and scheduled_end_at is not null
      and scheduled_timezone_name is not null
      and btrim(scheduled_timezone_name) <> ''
      and scheduled_end_at > scheduled_start_at
      and source_kind = 'manual'::public.calendar_event_source_kind
    )
  );

alter table public.calendar_events
  drop constraint if exists chk_calendar_events_meeting_fields;

alter table public.calendar_events
  add constraint chk_calendar_events_meeting_fields check (
    (
      type = 'internal_meeting'::public.calendar_event_type
      and source_kind = 'manual'::public.calendar_event_source_kind
      and meeting_mode is not null
      and (
        (
          meeting_mode = 'online'::public.calendar_meeting_mode
          and meeting_url is not null
          and btrim(meeting_url) <> ''
          and free_text_location is null
        )
        or (
          meeting_mode = 'in_person'::public.calendar_meeting_mode
          and free_text_location is not null
          and btrim(free_text_location) <> ''
          and meeting_url is null
        )
      )
    )
    or (
      not (
        type = 'internal_meeting'::public.calendar_event_type
        and source_kind = 'manual'::public.calendar_event_source_kind
      )
      and meeting_mode is null
      and meeting_url is null
    )
  );

comment on column public.calendar_events.scheduled_start_at is
  'M7A: optional timed manual window start (UTC); part of all-null/all-non-null triple.';
comment on column public.calendar_events.meeting_mode is
  'M7A: required for manual internal_meeting; null otherwise.';
comment on column public.calendar_events.meeting_url is
  'M7A: HTTPS absolute URL when meeting_mode=online; never stored in notes.';

-- ---------------------------------------------------------------------------
-- Section D: Participants
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_event_participants (
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  event_id uuid not null,
  employee_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  primary key (tenant_id, event_id, employee_id),
  constraint fk_calendar_event_participants_event
    foreign key (tenant_id, event_id)
    references public.calendar_events (tenant_id, id)
    on delete cascade,
  constraint fk_calendar_event_participants_employee
    foreign key (tenant_id, employee_id)
    references public.employees (tenant_id, id)
    on delete restrict
);

create index if not exists idx_calendar_event_participants_employee
  on public.calendar_event_participants (tenant_id, employee_id);

alter table public.calendar_event_participants enable row level security;

revoke all on table public.calendar_event_participants
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Section E: Idempotency ledger
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_manual_event_operations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  operation_type text not null,
  idempotency_key uuid not null,
  business_payload_hash text not null,
  result_status text not null,
  result_event_id uuid,
  result_jsonb jsonb,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  constraint chk_calendar_manual_event_operations_type check (
    operation_type in ('create', 'update', 'cancel', 'mark_done')
  ),
  constraint chk_calendar_manual_event_operations_status check (
    result_status in ('ok')
  ),
  constraint ux_calendar_manual_event_operations_idem
    unique (tenant_id, operation_type, idempotency_key)
);

create index if not exists idx_calendar_manual_event_operations_event
  on public.calendar_manual_event_operations (tenant_id, result_event_id);

alter table public.calendar_manual_event_operations enable row level security;

revoke all on table public.calendar_manual_event_operations
  from public, anon, authenticated, service_role;

comment on table public.calendar_manual_event_operations is
  'M7A: idempotency ledger for manual calendar mutations. '
  'confirmation_required soft-returns are never persisted.';

-- ---------------------------------------------------------------------------
-- Section F: Meeting notices
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_meeting_notices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  calendar_event_id uuid not null,
  notice_kind text not null,
  recipient_user_id uuid not null,
  recipient_employee_id uuid,
  operation_id uuid not null,
  notification_id uuid references public.notifications (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint chk_calendar_meeting_notices_kind check (
    notice_kind in (
      'meeting_created',
      'meeting_updated',
      'meeting_invited',
      'meeting_removed',
      'meeting_cancelled'
    )
  ),
  constraint fk_calendar_meeting_notices_event
    foreign key (tenant_id, calendar_event_id)
    references public.calendar_events (tenant_id, id)
    on delete cascade,
  constraint fk_calendar_meeting_notices_operation
    foreign key (operation_id)
    references public.calendar_manual_event_operations (id)
    on delete restrict,
  constraint ux_calendar_meeting_notices_recipient_op
    unique (
      tenant_id,
      calendar_event_id,
      notice_kind,
      recipient_user_id,
      operation_id
    )
);

create index if not exists idx_calendar_meeting_notices_event
  on public.calendar_meeting_notices (tenant_id, calendar_event_id);

alter table public.calendar_meeting_notices enable row level security;

revoke all on table public.calendar_meeting_notices
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Section G: Reminder uniqueness — dual partial uniques + open rebuild
-- ---------------------------------------------------------------------------
alter table public.calendar_reminder_plans
  drop constraint if exists ux_calendar_reminder_plans_occurrence;

drop index if exists public.ux_calendar_reminder_plans_occurrence;

-- Evidence-only: historical delivered collisions should not exist under old unique.
do $$
declare
  v_collisions int;
begin
  select count(*)
  into v_collisions
  from (
    select 1
    from public.calendar_reminder_plans crp
    where crp.recipient_employee_id is not null
      and crp.status = 'delivered'::public.calendar_reminder_plan_status
    group by
      crp.tenant_id,
      crp.calendar_event_id,
      crp.rule_key,
      crp.occurrence_scheduled_date,
      crp.recipient_employee_id
    having count(*) > 1
  ) x;

  if v_collisions > 0 then
    raise notice
      'm7a_reminder_history_collision: % delivered recipient groups collide; leaving immutable',
      v_collisions;
  end if;
end $$;

-- Active identity uniques. Cancelled rows are excluded so open plans can be
-- cancel-superseded then rebuilt without mutating delivered history.
create unique index if not exists ux_calendar_reminder_plans_recipient_occurrence
  on public.calendar_reminder_plans (
    tenant_id,
    calendar_event_id,
    rule_key,
    occurrence_scheduled_date,
    recipient_employee_id
  )
  where recipient_employee_id is not null
    and status not in (
      'cancelled_superseded'::public.calendar_reminder_plan_status,
      'cancelled_event'::public.calendar_reminder_plan_status
    );

create unique index if not exists ux_calendar_reminder_plans_suppressed_occurrence
  on public.calendar_reminder_plans (
    tenant_id,
    calendar_event_id,
    rule_key,
    occurrence_scheduled_date
  )
  where recipient_employee_id is null
    and status not in (
      'cancelled_superseded'::public.calendar_reminder_plan_status,
      'cancelled_event'::public.calendar_reminder_plan_status
    );

-- Cancel-supersede open/non-terminal plans so new planner identity applies.
-- Terminal plans (delivered/expired/failed/cancelled_event) remain immutable.
update public.calendar_reminder_plans crp
set
  status = 'cancelled_superseded'::public.calendar_reminder_plan_status,
  cancelled_at = coalesce(crp.cancelled_at, now()),
  next_attempt_at = null,
  suppressed_reason = null,
  resolution_code = null,
  updated_at = now()
where crp.status in (
  'planned'::public.calendar_reminder_plan_status,
  'delivery_pending'::public.calendar_reminder_plan_status,
  'suppressed'::public.calendar_reminder_plan_status,
  'skipped'::public.calendar_reminder_plan_status
);

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
on conflict (tenant_id) do update
set
  generation = public.calendar_reminder_reconcile_queue.generation + 1,
  enqueued_at = now(),
  scan_after_event_id = null,
  processed_generation = null;

-- ---------------------------------------------------------------------------
-- Section H: HTTPS validator + appointment time resolution
-- ---------------------------------------------------------------------------
create or replace function public.calendar_is_safe_https_url(p_url text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_url text;
  v_rest text;
  v_host text;
begin
  if p_url is null then
    return false;
  end if;

  v_url := btrim(p_url);
  if v_url = '' or length(v_url) > 2048 then
    return false;
  end if;

  if v_url !~* '^https://' then
    return false;
  end if;

  -- Reject credentials: https://user:pass@host
  if v_url ~* '^https://[^/]*@' then
    return false;
  end if;

  v_rest := substring(v_url from 9); -- after https://
  v_host := split_part(split_part(v_rest, '/', 1), '?', 1);
  v_host := split_part(v_host, '#', 1);

  if v_host is null or btrim(v_host) = '' then
    return false;
  end if;

  -- Reject empty / whitespace hosts and literal spaces
  if v_host ~ '\s' then
    return false;
  end if;

  -- Require at least one non-empty label (hostname or IPv4-ish)
  if v_host !~ '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'
    and v_host !~ '^[0-9]{1,3}(\.[0-9]{1,3}){3}(:[0-9]+)?$'
    and v_host !~ '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?:[0-9]+$' then
    return false;
  end if;

  return true;
end;
$$;

create or replace function public.resolve_appointment_local_timestamptz(
  p_timezone text,
  p_date date,
  p_local_time time
)
returns timestamptz
language plpgsql
immutable
set search_path = public
as $$
declare
  v_dst record;
begin
  if p_timezone is null or btrim(p_timezone) = '' or p_date is null or p_local_time is null then
    raise exception 'validation_failed';
  end if;

  select *
  into v_dst
  from public.local_work_start_to_utc(p_timezone, p_date, p_local_time) d;

  if v_dst.dst_resolution_code = 'dst_shifted_forward'::public.calendar_dst_resolution_code then
    raise exception 'calendar_local_time_nonexistent';
  end if;

  if v_dst.dst_resolution_code = 'dst_ambiguous_earlier'::public.calendar_dst_resolution_code then
    raise exception 'calendar_local_time_ambiguous';
  end if;

  return v_dst.anchor_utc;
end;
$$;

create or replace function public.resolve_appointment_time_window(
  p_timezone text,
  p_scheduled_date date,
  p_start_local text,
  p_end_local text
)
returns table (
  start_at timestamptz,
  end_at timestamptz,
  timezone_name text
)
language plpgsql
immutable
set search_path = public
as $$
declare
  v_start_time time;
  v_end_time time;
  v_start timestamptz;
  v_end timestamptz;
  v_local_start_date date;
  v_local_end_date date;
begin
  if p_timezone is null or not public.is_valid_iana_timezone(p_timezone) then
    raise exception 'calendar_timezone_unconfigured';
  end if;

  begin
    v_start_time := p_start_local::time;
    v_end_time := p_end_local::time;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  v_start := public.resolve_appointment_local_timestamptz(p_timezone, p_scheduled_date, v_start_time);
  v_end := public.resolve_appointment_local_timestamptz(p_timezone, p_scheduled_date, v_end_time);

  if v_end <= v_start then
    raise exception 'validation_failed';
  end if;

  v_local_start_date := (v_start at time zone p_timezone)::date;
  v_local_end_date := (v_end at time zone p_timezone)::date;

  if v_local_start_date is distinct from p_scheduled_date
    or v_local_end_date is distinct from p_scheduled_date then
    raise exception 'calendar_time_window_cross_date';
  end if;

  start_at := v_start;
  end_at := v_end;
  timezone_name := p_timezone;
  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section I: Conflict advisory locks
-- ---------------------------------------------------------------------------
create or replace function public.acquire_calendar_conflict_locks(
  p_tenant_id uuid,
  p_scheduled_date date,
  p_participant_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
  v_id uuid;
  v_key bigint;
begin
  if p_tenant_id is null or p_scheduled_date is null then
    raise exception 'validation_failed';
  end if;

  select coalesce(array_agg(x order by x), array[]::uuid[])
  into v_ids
  from (
    select distinct unnest(coalesce(p_participant_ids, array[]::uuid[])) as x
  ) s
  where x is not null;

  if coalesce(array_length(v_ids, 1), 0) = 0 then
    v_key := hashtextextended(
      'calconflict:' || p_tenant_id::text || ':' || p_scheduled_date::text || ':none',
      0
    );
    perform pg_advisory_xact_lock(v_key);
    return;
  end if;

  foreach v_id in array v_ids loop
    v_key := hashtextextended(
      'calconflict:' || p_tenant_id::text || ':' || p_scheduled_date::text || ':' || v_id::text,
      0
    );
    perform pg_advisory_xact_lock(v_key);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section J: Strict jsonb helpers (whitelist / hash / acks)
-- ---------------------------------------------------------------------------
create or replace function public.manual_calendar_ack_keys()
returns text[]
language sql
immutable
as $$
  select array[
    'acknowledge_overlap',
    'acknowledge_non_working_day',
    'acknowledge_schedule_unconfigured',
    'acknowledge_outside_working_window',
    'day_off_override_reason'
  ];
$$;

create or replace function public.manual_calendar_create_business_keys()
returns text[]
language sql
immutable
as $$
  select array[
    'type',
    'scheduled_date',
    'title_ar',
    'title_en',
    'notes',
    'time_window',
    'customer_id',
    'service_location_id',
    'contract_id',
    'free_text_team',
    'free_text_location',
    'participant_employee_ids',
    'meeting_mode',
    'meeting_url'
  ];
$$;

create or replace function public.manual_calendar_update_business_keys()
returns text[]
language sql
immutable
as $$
  select array[
    'title_ar',
    'title_en',
    'notes',
    'time_window',
    'customer_id',
    'service_location_id',
    'contract_id',
    'free_text_team',
    'free_text_location',
    'participant_employee_ids',
    'meeting_mode',
    'meeting_url'
  ];
$$;

create or replace function public.manual_calendar_parse_optional_uuid(
  p_obj jsonb,
  p_key text
)
returns uuid
language plpgsql
immutable
as $$
declare
  v_value jsonb;
  v_text text;
begin
  if not coalesce(p_obj ? p_key, false) then
    return null;
  end if;
  v_value := p_obj -> p_key;
  if jsonb_typeof(v_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(v_value) <> 'string' then
    raise exception 'validation_failed';
  end if;
  v_text := btrim(v_value #>> '{}');
  if v_text = '' then
    raise exception 'validation_failed';
  end if;
  begin
    return v_text::uuid;
  exception
    when others then
      raise exception 'validation_failed';
  end;
end;
$$;

create or replace function public.manual_calendar_parse_optional_text(
  p_obj jsonb,
  p_key text,
  p_max_len int default 4000
)
returns text
language plpgsql
immutable
as $$
declare
  v_value jsonb;
  v_text text;
begin
  if not coalesce(p_obj ? p_key, false) then
    return null;
  end if;
  v_value := p_obj -> p_key;
  if jsonb_typeof(v_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(v_value) <> 'string' then
    raise exception 'validation_failed';
  end if;
  v_text := btrim(v_value #>> '{}');
  if v_text = '' then
    return null;
  end if;
  if length(v_text) > p_max_len then
    raise exception 'validation_failed';
  end if;
  return v_text;
end;
$$;

create or replace function public.manual_calendar_parse_participant_ids(p_obj jsonb)
returns uuid[]
language plpgsql
immutable
as $$
declare
  v_value jsonb;
  v_elem jsonb;
  v_text text;
  v_ids uuid[] := array[]::uuid[];
begin
  if not coalesce(p_obj ? 'participant_employee_ids', false) then
    return array[]::uuid[];
  end if;
  v_value := p_obj -> 'participant_employee_ids';
  if jsonb_typeof(v_value) = 'null' then
    return array[]::uuid[];
  end if;
  if jsonb_typeof(v_value) <> 'array' then
    raise exception 'validation_failed';
  end if;
  for v_elem in select value from jsonb_array_elements(v_value) loop
    if jsonb_typeof(v_elem) <> 'string' then
      raise exception 'validation_failed';
    end if;
    v_text := btrim(v_elem #>> '{}');
    if v_text = '' then
      raise exception 'validation_failed';
    end if;
    begin
      v_ids := v_ids || v_text::uuid;
    exception
      when others then
        raise exception 'validation_failed';
    end;
  end loop;
  select coalesce(array_agg(distinct x order by x), array[]::uuid[])
  into v_ids
  from unnest(v_ids) as x;
  return v_ids;
end;
$$;

create or replace function public.manual_calendar_parse_time_window(p_obj jsonb)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_value jsonb;
  v_key text;
  v_start text;
  v_end text;
begin
  if not coalesce(p_obj ? 'time_window', false) then
    return null;
  end if;
  v_value := p_obj -> 'time_window';
  if jsonb_typeof(v_value) = 'null' then
    return null;
  end if;
  if jsonb_typeof(v_value) <> 'object' then
    raise exception 'validation_failed';
  end if;
  for v_key in select jsonb_object_keys(v_value) loop
    if v_key not in ('start_local', 'end_local') then
      raise exception 'validation_failed';
    end if;
  end loop;
  if not (v_value ? 'start_local') or not (v_value ? 'end_local') then
    raise exception 'validation_failed';
  end if;
  if jsonb_typeof(v_value -> 'start_local') <> 'string'
    or jsonb_typeof(v_value -> 'end_local') <> 'string' then
    raise exception 'validation_failed';
  end if;
  v_start := btrim(v_value ->> 'start_local');
  v_end := btrim(v_value ->> 'end_local');
  if v_start = '' or v_end = '' then
    raise exception 'validation_failed';
  end if;
  return jsonb_build_object('start_local', v_start, 'end_local', v_end);
end;
$$;

create or replace function public.manual_calendar_extract_acknowledgements(p_data jsonb)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_src jsonb;
  v_ack jsonb := '{}'::jsonb;
  v_key text;
  v_bool boolean;
  v_reason text;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  if p_data ? 'acknowledgements' then
    if jsonb_typeof(p_data -> 'acknowledgements') <> 'object' then
      raise exception 'validation_failed';
    end if;
    v_src := p_data -> 'acknowledgements';
    for v_key in select jsonb_object_keys(v_src) loop
      if v_key <> all (public.manual_calendar_ack_keys()) then
        raise exception 'validation_failed';
      end if;
    end loop;
  else
    v_src := '{}'::jsonb;
    for v_key in select unnest(public.manual_calendar_ack_keys()) loop
      if p_data ? v_key then
        v_src := v_src || jsonb_build_object(v_key, p_data -> v_key);
      end if;
    end loop;
  end if;

  foreach v_key in array array[
    'acknowledge_overlap',
    'acknowledge_non_working_day',
    'acknowledge_schedule_unconfigured',
    'acknowledge_outside_working_window'
  ] loop
    if v_src ? v_key then
      if jsonb_typeof(v_src -> v_key) <> 'boolean' then
        raise exception 'validation_failed';
      end if;
      v_bool := (v_src ->> v_key)::boolean;
      if v_bool then
        v_ack := v_ack || jsonb_build_object(v_key, true);
      end if;
    end if;
  end loop;

  if v_src ? 'day_off_override_reason' then
    if jsonb_typeof(v_src -> 'day_off_override_reason') = 'null' then
      null;
    elsif jsonb_typeof(v_src -> 'day_off_override_reason') <> 'string' then
      raise exception 'validation_failed';
    else
      v_reason := btrim(v_src ->> 'day_off_override_reason');
      if v_reason <> '' then
        if length(v_reason) > 1000 then
          raise exception 'validation_failed';
        end if;
        v_ack := v_ack || jsonb_build_object('day_off_override_reason', v_reason);
      end if;
    end if;
  end if;

  return v_ack;
end;
$$;

create or replace function public.manual_calendar_strip_ack_keys(p_data jsonb)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_out jsonb := '{}'::jsonb;
  v_key text;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;
  for v_key in select jsonb_object_keys(p_data) loop
    if v_key = 'acknowledgements' then
      continue;
    end if;
    if v_key = any (public.manual_calendar_ack_keys()) then
      continue;
    end if;
    v_out := v_out || jsonb_build_object(v_key, p_data -> v_key);
  end loop;
  return v_out;
end;
$$;

create or replace function public.manual_calendar_business_payload_hash(p_business jsonb)
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

create or replace function public.normalize_manual_calendar_create_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_data jsonb;
  v_key text;
  v_type text;
  v_date text;
  v_title_ar text;
  v_title_en text;
  v_notes text;
  v_tw jsonb;
  v_customer uuid;
  v_location uuid;
  v_contract uuid;
  v_team text;
  v_location_text text;
  v_participants uuid[];
  v_meeting_mode text;
  v_meeting_url text;
  v_out jsonb;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  v_data := public.manual_calendar_strip_ack_keys(p_data);

  for v_key in select jsonb_object_keys(v_data) loop
    if v_key <> all (public.manual_calendar_create_business_keys()) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if not (v_data ? 'type') or jsonb_typeof(v_data -> 'type') <> 'string' then
    raise exception 'validation_failed';
  end if;
  v_type := btrim(v_data ->> 'type');
  if v_type not in (
    'customer_visit', 'internal_meeting', 'internal_task', 'internal_activity', 'custom'
  ) then
    raise exception 'validation_failed';
  end if;

  if not (v_data ? 'scheduled_date') or jsonb_typeof(v_data -> 'scheduled_date') <> 'string' then
    raise exception 'validation_failed';
  end if;
  v_date := btrim(v_data ->> 'scheduled_date');
  begin
    perform v_date::date;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  v_title_ar := public.manual_calendar_parse_optional_text(v_data, 'title_ar', 500);
  v_title_en := public.manual_calendar_parse_optional_text(v_data, 'title_en', 500);
  if v_title_ar is null and v_title_en is null then
    raise exception 'validation_failed';
  end if;

  v_notes := public.manual_calendar_parse_optional_text(v_data, 'notes', 8000);
  v_tw := public.manual_calendar_parse_time_window(v_data);
  v_customer := public.manual_calendar_parse_optional_uuid(v_data, 'customer_id');
  v_location := public.manual_calendar_parse_optional_uuid(v_data, 'service_location_id');
  v_contract := public.manual_calendar_parse_optional_uuid(v_data, 'contract_id');
  v_team := public.manual_calendar_parse_optional_text(v_data, 'free_text_team', 500);
  v_location_text := public.manual_calendar_parse_optional_text(v_data, 'free_text_location', 500);
  v_participants := public.manual_calendar_parse_participant_ids(v_data);

  if v_type in ('internal_meeting', 'internal_task', 'internal_activity') then
    if v_customer is not null or v_location is not null or v_contract is not null then
      raise exception 'validation_failed';
    end if;
  end if;

  if v_location is not null and v_customer is null then
    raise exception 'validation_failed';
  end if;

  if v_type = 'internal_meeting' then
    if not (v_data ? 'meeting_mode') or jsonb_typeof(v_data -> 'meeting_mode') <> 'string' then
      raise exception 'validation_failed';
    end if;
    v_meeting_mode := btrim(v_data ->> 'meeting_mode');
    if v_meeting_mode not in ('in_person', 'online') then
      raise exception 'validation_failed';
    end if;
    if v_meeting_mode = 'online' then
      v_meeting_url := public.manual_calendar_parse_optional_text(v_data, 'meeting_url', 2048);
      if v_meeting_url is null or not public.calendar_is_safe_https_url(v_meeting_url) then
        raise exception 'validation_failed';
      end if;
      v_location_text := null;
    else
      if v_data ? 'meeting_url' and jsonb_typeof(v_data -> 'meeting_url') <> 'null' then
        if public.manual_calendar_parse_optional_text(v_data, 'meeting_url', 2048) is not null then
          raise exception 'validation_failed';
        end if;
      end if;
      if v_location_text is null then
        raise exception 'validation_failed';
      end if;
      v_meeting_url := null;
    end if;
  else
    if v_data ? 'meeting_mode' and jsonb_typeof(v_data -> 'meeting_mode') <> 'null' then
      raise exception 'validation_failed';
    end if;
    if v_data ? 'meeting_url' and jsonb_typeof(v_data -> 'meeting_url') <> 'null' then
      if public.manual_calendar_parse_optional_text(v_data, 'meeting_url', 2048) is not null then
        raise exception 'validation_failed';
      end if;
    end if;
    v_meeting_mode := null;
    v_meeting_url := null;
  end if;

  v_out := jsonb_strip_nulls(
    jsonb_build_object(
      'type', v_type,
      'scheduled_date', v_date,
      'title_ar', v_title_ar,
      'title_en', v_title_en,
      'notes', v_notes,
      'time_window', v_tw,
      'customer_id', v_customer,
      'service_location_id', v_location,
      'contract_id', v_contract,
      'free_text_team', v_team,
      'free_text_location', v_location_text,
      'participant_employee_ids', to_jsonb(v_participants),
      'meeting_mode', v_meeting_mode,
      'meeting_url', v_meeting_url
    )
  );

  -- Keep empty participant array explicit for stable hashing.
  v_out := v_out || jsonb_build_object('participant_employee_ids', to_jsonb(v_participants));
  if v_tw is null then
    v_out := v_out || jsonb_build_object('time_window', null);
  end if;

  return v_out;
end;
$$;

create or replace function public.normalize_manual_calendar_update_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_data jsonb;
  v_key text;
  v_create_shaped jsonb;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  v_data := public.manual_calendar_strip_ack_keys(p_data);

  for v_key in select jsonb_object_keys(v_data) loop
    if v_key <> all (public.manual_calendar_update_business_keys()) then
      raise exception 'validation_failed';
    end if;
  end loop;

  -- Reuse create normalizer with a synthetic type/date filled by caller merge.
  -- Update payload alone is incomplete; merge happens in the RPC.
  return v_data;
end;
$$;

create or replace function public.normalize_manual_calendar_update_patch(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_data jsonb;
  v_key text;
  v_out jsonb := '{}'::jsonb;
  v_participants uuid[];
  v_tw jsonb;
  v_text text;
  v_uuid uuid;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  v_data := public.manual_calendar_strip_ack_keys(p_data);

  for v_key in select jsonb_object_keys(v_data) loop
    if v_key <> all (public.manual_calendar_update_business_keys()) then
      raise exception 'validation_failed';
    end if;
  end loop;

  -- Canonicalize present whitelist keys only (do not merge current event).
  if v_data ? 'title_ar' then
    v_text := public.manual_calendar_parse_optional_text(v_data, 'title_ar', 500);
    v_out := v_out || jsonb_build_object('title_ar', to_jsonb(v_text));
  end if;
  if v_data ? 'title_en' then
    v_text := public.manual_calendar_parse_optional_text(v_data, 'title_en', 500);
    v_out := v_out || jsonb_build_object('title_en', to_jsonb(v_text));
  end if;
  if v_data ? 'notes' then
    v_text := public.manual_calendar_parse_optional_text(v_data, 'notes', 8000);
    v_out := v_out || jsonb_build_object('notes', to_jsonb(v_text));
  end if;
  if v_data ? 'time_window' then
    v_tw := public.manual_calendar_parse_time_window(v_data);
    v_out := v_out || jsonb_build_object('time_window', v_tw);
  end if;
  if v_data ? 'customer_id' then
    v_uuid := public.manual_calendar_parse_optional_uuid(v_data, 'customer_id');
    v_out := v_out || jsonb_build_object('customer_id', to_jsonb(v_uuid));
  end if;
  if v_data ? 'service_location_id' then
    v_uuid := public.manual_calendar_parse_optional_uuid(v_data, 'service_location_id');
    v_out := v_out || jsonb_build_object('service_location_id', to_jsonb(v_uuid));
  end if;
  if v_data ? 'contract_id' then
    v_uuid := public.manual_calendar_parse_optional_uuid(v_data, 'contract_id');
    v_out := v_out || jsonb_build_object('contract_id', to_jsonb(v_uuid));
  end if;
  if v_data ? 'free_text_team' then
    v_text := public.manual_calendar_parse_optional_text(v_data, 'free_text_team', 500);
    v_out := v_out || jsonb_build_object('free_text_team', to_jsonb(v_text));
  end if;
  if v_data ? 'free_text_location' then
    v_text := public.manual_calendar_parse_optional_text(v_data, 'free_text_location', 500);
    v_out := v_out || jsonb_build_object('free_text_location', to_jsonb(v_text));
  end if;
  if v_data ? 'participant_employee_ids' then
    v_participants := public.manual_calendar_parse_participant_ids(v_data);
    v_out := v_out || jsonb_build_object(
      'participant_employee_ids', to_jsonb(v_participants)
    );
  end if;
  if v_data ? 'meeting_mode' then
    if jsonb_typeof(v_data -> 'meeting_mode') = 'null' then
      v_out := v_out || jsonb_build_object('meeting_mode', null);
    else
      if jsonb_typeof(v_data -> 'meeting_mode') <> 'string' then
        raise exception 'validation_failed';
      end if;
      v_text := btrim(v_data ->> 'meeting_mode');
      if v_text not in ('in_person', 'online') then
        raise exception 'validation_failed';
      end if;
      v_out := v_out || jsonb_build_object('meeting_mode', v_text);
    end if;
  end if;
  if v_data ? 'meeting_url' then
    v_text := public.manual_calendar_parse_optional_text(v_data, 'meeting_url', 2048);
    v_out := v_out || jsonb_build_object('meeting_url', to_jsonb(v_text));
  end if;

  return v_out;
end;
$$;

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

create or replace function public.resolve_manual_event_idempotency(
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
  v_row public.calendar_manual_event_operations%rowtype;
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
  from public.calendar_manual_event_operations op
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

create or replace function public.record_manual_event_operation(
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
  insert into public.calendar_manual_event_operations (
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

-- ---------------------------------------------------------------------------
-- Section K: Link / participant validation + replace
-- ---------------------------------------------------------------------------
create or replace function public.validate_manual_calendar_links(
  p_tenant_id uuid,
  p_type public.calendar_event_type,
  p_customer_id uuid,
  p_service_location_id uuid,
  p_contract_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_type in (
    'internal_meeting'::public.calendar_event_type,
    'internal_task'::public.calendar_event_type,
    'internal_activity'::public.calendar_event_type
  ) then
    if p_customer_id is not null or p_service_location_id is not null or p_contract_id is not null then
      raise exception 'validation_failed';
    end if;
    return;
  end if;

  if p_customer_id is not null then
    if not exists (
      select 1 from public.customers c
      where c.id = p_customer_id and c.tenant_id = p_tenant_id
    ) then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_service_location_id is not null then
    if p_customer_id is null then
      raise exception 'validation_failed';
    end if;
    if not exists (
      select 1 from public.customer_service_locations l
      where l.id = p_service_location_id
        and l.tenant_id = p_tenant_id
        and l.customer_id = p_customer_id
    ) then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_contract_id is not null then
    if not exists (
      select 1 from public.contracts c
      where c.id = p_contract_id
        and c.tenant_id = p_tenant_id
        and (p_customer_id is null or c.customer_id = p_customer_id)
        and (
          p_service_location_id is null
          or c.service_location_id is not distinct from p_service_location_id
        )
    ) then
      raise exception 'validation_failed';
    end if;
  end if;
end;
$$;

create or replace function public.validate_manual_participant_ids(
  p_tenant_id uuid,
  p_participant_ids uuid[],
  p_allow_inactive_existing boolean default false,
  p_existing_ids uuid[] default array[]::uuid[]
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  foreach v_id in array coalesce(p_participant_ids, array[]::uuid[]) loop
    if not exists (
      select 1 from public.employees e
      where e.id = v_id and e.tenant_id = p_tenant_id
    ) then
      raise exception 'validation_failed';
    end if;

    if not exists (
      select 1 from public.employees e
      where e.id = v_id
        and e.tenant_id = p_tenant_id
        and (
          e.is_active = true
          or (
            p_allow_inactive_existing
            and v_id = any (coalesce(p_existing_ids, array[]::uuid[]))
          )
        )
    ) then
      raise exception 'validation_failed';
    end if;
  end loop;
end;
$$;

create or replace function public.replace_calendar_event_participants(
  p_tenant_id uuid,
  p_event_id uuid,
  p_participant_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
begin
  select coalesce(array_agg(distinct x order by x), array[]::uuid[])
  into v_ids
  from unnest(coalesce(p_participant_ids, array[]::uuid[])) as x
  where x is not null;

  delete from public.calendar_event_participants p
  where p.tenant_id = p_tenant_id
    and p.event_id = p_event_id
    and not (p.employee_id = any (v_ids));

  insert into public.calendar_event_participants (
    tenant_id, event_id, employee_id, created_by
  )
  select p_tenant_id, p_event_id, x, auth.uid()
  from unnest(v_ids) as x
  on conflict (tenant_id, event_id, employee_id) do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section L: Schedule/overlap conflict detection
-- ---------------------------------------------------------------------------
create or replace function public.detect_manual_calendar_schedule_warnings(
  p_tenant_id uuid,
  p_scheduled_date date,
  p_start_at timestamptz,
  p_end_at timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_window jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_settings public.tenant_calendar_settings%rowtype;
  v_work_start time;
  v_work_end time;
  v_local_start time;
  v_local_end time;
  v_tz text;
begin
  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = p_tenant_id;

  if not found
    or not coalesce(v_settings.working_schedule_configured, false)
    or v_settings.timezone_name is null
    or not public.is_valid_iana_timezone(v_settings.timezone_name) then
    v_warnings := v_warnings || jsonb_build_array(
      jsonb_build_object('code', 'schedule_unconfigured')
    );
    return v_warnings;
  end if;

  v_window := public.resolve_tenant_working_window(p_tenant_id, p_scheduled_date);

  if coalesce(v_window ->> 'is_day_off', 'false')::boolean then
    v_warnings := v_warnings || jsonb_build_array(
      jsonb_build_object('code', 'non_working_day')
    );
  end if;

  if p_start_at is null or p_end_at is null then
    return v_warnings;
  end if;

  if coalesce(v_window ->> 'is_24_hours', 'false')::boolean then
    return v_warnings;
  end if;

  if not coalesce(v_window ->> 'is_working_hours', 'false')::boolean then
    return v_warnings;
  end if;

  v_tz := v_settings.timezone_name;
  v_work_start := (v_window ->> 'work_start')::time;
  v_work_end := (v_window ->> 'work_end')::time;
  v_local_start := (p_start_at at time zone v_tz)::time;
  v_local_end := (p_end_at at time zone v_tz)::time;

  if v_local_end <= v_work_start or v_local_start >= v_work_end then
    v_warnings := v_warnings || jsonb_build_array(
      jsonb_build_object('code', 'outside_working_window')
    );
  elsif v_local_start < v_work_start or v_local_end > v_work_end then
    v_warnings := v_warnings || jsonb_build_array(
      jsonb_build_object('code', 'partially_outside_working_window')
    );
  end if;

  return v_warnings;
end;
$$;

create or replace function public.detect_manual_calendar_overlap_warnings(
  p_tenant_id uuid,
  p_scheduled_date date,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_participant_ids uuid[],
  p_exclude_event_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rows jsonb := '[]'::jsonb;
  v_total int := 0;
  v_ids uuid[];
begin
  if p_start_at is null or p_end_at is null then
    return jsonb_build_object(
      'overlap_warnings', '[]'::jsonb,
      'overlap_total_count', 0
    );
  end if;

  select coalesce(array_agg(distinct x order by x), array[]::uuid[])
  into v_ids
  from unnest(coalesce(p_participant_ids, array[]::uuid[])) as x
  where x is not null;

  if coalesce(array_length(v_ids, 1), 0) = 0 then
    return jsonb_build_object(
      'overlap_warnings', '[]'::jsonb,
      'overlap_total_count', 0
    );
  end if;

  with busy_overlaps as (
    select
      p.employee_id,
      e.name_ar,
      e.name_en,
      ce.scheduled_start_at as busy_start_at,
      ce.scheduled_end_at as busy_end_at,
      ce.id as busy_event_id
    from public.calendar_event_participants p
    join public.calendar_events ce
      on ce.tenant_id = p.tenant_id
      and ce.id = p.event_id
    join public.employees e
      on e.tenant_id = p.tenant_id
      and e.id = p.employee_id
    where p.tenant_id = p_tenant_id
      and p.employee_id = any (v_ids)
      and ce.scheduled_date = p_scheduled_date
      and ce.status = 'pending'::public.calendar_event_status
      and ce.scheduled_start_at is not null
      and ce.scheduled_end_at is not null
      and ce.scheduled_start_at < p_end_at
      and ce.scheduled_end_at > p_start_at
      and (p_exclude_event_id is null or ce.id is distinct from p_exclude_event_id)
  ),
  grouped as (
    select
      employee_id,
      max(name_ar) as name_ar,
      max(name_en) as name_en,
      min(busy_start_at) as busy_start_at,
      max(busy_end_at) as busy_end_at,
      count(*)::int as overlap_count
    from busy_overlaps
    group by employee_id
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'employee_id', g.employee_id,
          'employee_name_ar', g.name_ar,
          'employee_name_en', g.name_en,
          'busy_start_at', g.busy_start_at,
          'busy_end_at', g.busy_end_at,
          'overlap_count', g.overlap_count
        )
        order by g.employee_id
      ),
      '[]'::jsonb
    ),
    coalesce(sum(g.overlap_count), 0)::int
  into v_rows, v_total
  from grouped g;

  return jsonb_build_object(
    'overlap_warnings', coalesce(v_rows, '[]'::jsonb),
    'overlap_total_count', coalesce(v_total, 0)
  );
end;
$$;

create or replace function public.manual_calendar_conflict_requires_confirmation(
  p_schedule_warnings jsonb,
  p_overlap_total int,
  p_acks jsonb
)
returns boolean
language plpgsql
immutable
as $$
declare
  v_code text;
  v_needs boolean := false;
begin
  if coalesce(p_overlap_total, 0) > 0
    and not coalesce((p_acks ->> 'acknowledge_overlap')::boolean, false) then
    return true;
  end if;

  for v_code in
    select value ->> 'code'
    from jsonb_array_elements(coalesce(p_schedule_warnings, '[]'::jsonb))
  loop
    if v_code = 'non_working_day'
      and (
        not coalesce((p_acks ->> 'acknowledge_non_working_day')::boolean, false)
        or nullif(btrim(coalesce(p_acks ->> 'day_off_override_reason', '')), '') is null
      ) then
      return true;
    end if;
    if v_code = 'schedule_unconfigured'
      and not coalesce((p_acks ->> 'acknowledge_schedule_unconfigured')::boolean, false) then
      return true;
    end if;
    if v_code in ('outside_working_window', 'partially_outside_working_window')
      and not coalesce((p_acks ->> 'acknowledge_outside_working_window')::boolean, false) then
      return true;
    end if;
  end loop;

  return false;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section M: Event DTO builder (mutation + read shared keys)
-- ---------------------------------------------------------------------------
create or replace function public.calendar_event_time_window_json(
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_timezone_name text
)
returns jsonb
language plpgsql
immutable
as $$
begin
  if p_start_at is null or p_end_at is null or p_timezone_name is null then
    return null;
  end if;
  return jsonb_build_object(
    'start_local', to_char(p_start_at at time zone p_timezone_name, 'HH24:MI'),
    'end_local', to_char(p_end_at at time zone p_timezone_name, 'HH24:MI'),
    'timezone_name', p_timezone_name
  );
end;
$$;

create or replace function public.calendar_event_participants_json(
  p_tenant_id uuid,
  p_event_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'employee_id', e.id,
        'name_ar', e.name_ar,
        'name_en', e.name_en,
        'is_active', e.is_active,
        'has_app_account', e.user_id is not null
      )
      order by e.name_ar, e.id
    ),
    '[]'::jsonb
  )
  from public.calendar_event_participants p
  join public.employees e
    on e.tenant_id = p.tenant_id
    and e.id = p.employee_id
  where p.tenant_id = p_tenant_id
    and p.event_id = p_event_id;
$$;

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
  v_can_edit boolean;
  v_is_manual boolean;
  v_pending boolean;
  v_is_organizer boolean;
  v_is_meeting boolean;
  v_can_manage boolean;
  v_can_open boolean;
begin
  v_can_edit := public.user_has_permission('calendar.edit');
  v_is_manual := p_event.source_kind = 'manual'::public.calendar_event_source_kind;
  v_pending := p_event.status = 'pending'::public.calendar_event_status;
  v_is_organizer := p_event.created_by is not distinct from auth.uid();
  v_is_meeting := p_event.type = 'internal_meeting'::public.calendar_event_type;

  if v_is_meeting then
    v_can_manage := v_can_edit and v_is_manual and v_pending and v_is_organizer;
  else
    v_can_manage := v_can_edit and v_is_manual and v_pending;
  end if;

  v_can_open :=
    v_is_meeting
    and p_event.meeting_mode = 'online'::public.calendar_meeting_mode
    and p_event.status <> 'cancelled'::public.calendar_event_status
    and public.calendar_is_safe_https_url(p_event.meeting_url);

  return jsonb_build_object(
    'can_view_customer', public.user_has_permission('customers.view'),
    'can_view_contract', public.user_has_permission('contracts.view'),
    'can_assign', public.user_has_permission('calendar.edit'),
    'can_reschedule', public.user_has_permission('calendar.edit'),
    'can_create_manual', public.user_has_permission('calendar.create'),
    'can_open_directions', coalesce(p_directions_available, false),
    'can_edit_manual', v_can_manage,
    'can_cancel_manual', v_can_manage,
    'can_mark_manual_done', v_can_manage,
    'can_open_meeting_link', v_can_open
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section N: Visibility + reminder recipient fan-out
-- ---------------------------------------------------------------------------
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
    p_tenant_id, p_user_id, 'calendar.view'
  ) then
    return true;
  end if;

  if public.user_has_permission_for_tenant_user(
    p_tenant_id, p_user_id, 'calendar.view_assigned'
  ) then
    select e.id
    into v_employee_id
    from public.employees e
    where e.tenant_id = p_tenant_id
      and e.user_id = p_user_id
      and e.is_active = true
    limit 1;

    if v_employee_id is not null
      and v_event.assigned_agent_id is not distinct from v_employee_id then
      return true;
    end if;

    if v_employee_id is not null
      and exists (
        select 1
        from public.calendar_event_participants p
        where p.tenant_id = p_tenant_id
          and p.event_id = p_event_id
          and p.employee_id = v_employee_id
      ) then
      return true;
    end if;

    if v_event.source_kind = 'manual'::public.calendar_event_source_kind
      and v_event.created_by is not distinct from p_user_id then
      return true;
    end if;
  end if;

  return false;
end;
$$;

create or replace function public.list_calendar_reminder_recipients_for_event(
  p_event public.calendar_events
)
returns table (
  recipient_user_id uuid,
  recipient_employee_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  with candidate_employees as (
    select e.id as employee_id, e.user_id
    from public.employees e
    where e.tenant_id = p_event.tenant_id
      and e.is_active = true
      and e.user_id is not null
      and (
        e.id = p_event.assigned_agent_id
        or exists (
          select 1
          from public.calendar_event_participants p
          where p.tenant_id = p_event.tenant_id
            and p.event_id = p_event.id
            and p.employee_id = e.id
        )
      )
  )
  select distinct c.user_id, c.employee_id
  from candidate_employees c
  join public.tenant_users tu
    on tu.tenant_id = p_event.tenant_id
    and tu.user_id = c.user_id
    and tu.is_active = true
  where public.user_has_calendar_event_visibility(
    p_event.tenant_id,
    c.user_id,
    p_event.id
  );
$$;

create or replace function public.cancel_open_calendar_reminder_plans_for_occurrence(
  p_event_id uuid,
  p_rule_key public.calendar_reminder_rule_key,
  p_occurrence_date date
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
    and crp.rule_key = p_rule_key
    and crp.occurrence_scheduled_date = p_occurrence_date
    and crp.status in (
      'planned'::public.calendar_reminder_plan_status,
      'delivery_pending'::public.calendar_reminder_plan_status,
      'suppressed'::public.calendar_reminder_plan_status,
      'skipped'::public.calendar_reminder_plan_status
    );
end;
$$;

-- Diff-based apply (096 upsert semantics + multi-participant recipients).
-- Never cancel-rebuild open plans unconditionally; preserve delivery_pending
-- when identity/anchors are unchanged.
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
  v_rec record;
  v_existing public.calendar_reminder_plans%rowtype;
  v_anchor_date date;
  v_window jsonb;
  v_local_time time;
  v_dst record;
  v_mode text; -- 'null_recipient' | 'recipients'
  v_status public.calendar_reminder_plan_status;
  v_resolution_code text;
  v_suppressed_reason text;
  v_anchor_local_date date;
  v_anchor_local_time time;
  v_anchor_utc timestamptz;
  v_timezone_name text;
  v_dst_code public.calendar_dst_resolution_code;
  v_dst_shift_seconds int;
  v_desired_employee_ids uuid[] := array[]::uuid[];
  v_reactivate boolean;
  v_reset_retry boolean;
  v_apply_status public.calendar_reminder_plan_status;
  v_open_statuses public.calendar_reminder_plan_status[] := array[
    'planned'::public.calendar_reminder_plan_status,
    'delivery_pending'::public.calendar_reminder_plan_status,
    'suppressed'::public.calendar_reminder_plan_status,
    'skipped'::public.calendar_reminder_plan_status
  ];
  v_allow_insert boolean := true;
begin
  v_status := null;
  v_resolution_code := null;
  v_suppressed_reason := null;
  v_anchor_local_date := null;
  v_anchor_local_time := null;
  v_anchor_utc := null;
  v_timezone_name := null;
  v_dst_code := null;
  v_dst_shift_seconds := null;
  v_local_time := null;

  -- Shared prechecks → null-recipient suppressed.
  if not coalesce(p_settings.working_schedule_configured, false) then
    v_mode := 'null_recipient';
    v_status := 'suppressed'::public.calendar_reminder_plan_status;
    v_suppressed_reason := 'schedule_unconfigured';
    v_allow_insert := false;
  elsif p_settings.timezone_name is null then
    v_mode := 'null_recipient';
    v_status := 'suppressed'::public.calendar_reminder_plan_status;
    v_suppressed_reason := 'timezone_missing';
    v_allow_insert := false;
  elsif not public.is_valid_iana_timezone(p_settings.timezone_name) then
    v_mode := 'null_recipient';
    v_status := 'suppressed'::public.calendar_reminder_plan_status;
    v_suppressed_reason := 'timezone_invalid';
    v_allow_insert := false;
  elsif not coalesce(p_policy_enabled, false) then
    v_mode := 'null_recipient';
    v_status := 'suppressed'::public.calendar_reminder_plan_status;
    v_suppressed_reason := 'policy_disabled';
    v_allow_insert := false;
  else
    -- Shared anchor computation (same for all recipients).
    if p_rule_key = 'event_workday_start'::public.calendar_reminder_rule_key then
      v_anchor_date := p_event.scheduled_date;
      v_window := public.resolve_tenant_working_window(p_event.tenant_id, v_anchor_date);

      if coalesce(v_window ->> 'is_day_off', 'false')::boolean
        or coalesce(v_window ->> 'is_unreviewed', 'false')::boolean
        or nullif(v_window ->> 'day_mode', '') is null then
        v_status := 'skipped'::public.calendar_reminder_plan_status;
        v_resolution_code := 'event_date_day_off';
      elsif coalesce(v_window ->> 'is_24_hours', 'false')::boolean then
        v_local_time := make_time(0, 0, 0);
      elsif coalesce(v_window ->> 'is_working_hours', 'false')::boolean then
        v_local_time := (v_window ->> 'work_start')::time;
      else
        v_status := 'skipped'::public.calendar_reminder_plan_status;
        v_resolution_code := 'event_date_day_off';
      end if;
    else
      v_anchor_date := public.find_previous_working_day(
        p_event.tenant_id, p_event.scheduled_date, 366
      );
      if v_anchor_date is null then
        v_status := 'skipped'::public.calendar_reminder_plan_status;
        v_resolution_code := 'no_prior_working_day_in_horizon';
      else
        v_window := public.resolve_tenant_working_window(p_event.tenant_id, v_anchor_date);
        if coalesce(v_window ->> 'is_24_hours', 'false')::boolean then
          v_local_time := make_time(0, 0, 0);
        elsif coalesce(v_window ->> 'is_working_hours', 'false')::boolean then
          v_local_time := (v_window ->> 'work_start')::time;
        else
          v_status := 'skipped'::public.calendar_reminder_plan_status;
          v_resolution_code := 'no_prior_working_day_in_horizon';
        end if;
      end if;
    end if;

    if v_local_time is not null and v_status is null then
      select * into v_dst
      from public.local_work_start_to_utc(
        p_settings.timezone_name, v_anchor_date, v_local_time
      ) d;
      v_status := 'planned'::public.calendar_reminder_plan_status;
      v_anchor_local_date := v_anchor_date;
      v_anchor_local_time := v_local_time;
      v_anchor_utc := v_dst.anchor_utc;
      v_timezone_name := p_settings.timezone_name;
      v_dst_code := v_dst.dst_resolution_code;
      v_dst_shift_seconds := v_dst.dst_shift_seconds;
    end if;

    if v_status = 'skipped'::public.calendar_reminder_plan_status then
      v_mode := 'null_recipient';
    elsif v_status = 'planned'::public.calendar_reminder_plan_status then
      select coalesce(array_agg(r.recipient_employee_id order by r.recipient_employee_id), array[]::uuid[])
      into v_desired_employee_ids
      from public.list_calendar_reminder_recipients_for_event(p_event) r;

      if coalesce(cardinality(v_desired_employee_ids), 0) = 0 then
        v_mode := 'null_recipient';
        v_status := 'suppressed'::public.calendar_reminder_plan_status;
        v_resolution_code := null;
        v_anchor_local_date := null;
        v_anchor_local_time := null;
        v_anchor_utc := null;
        v_timezone_name := null;
        v_dst_code := null;
        v_dst_shift_seconds := null;

        -- Preserve 096 suppress codes: resolve assignee first, then visibility.
        select *
        into v_rec
        from public.resolve_calendar_reminder_recipient(
          p_event.tenant_id,
          p_event.assigned_agent_id
        ) r;

        if v_rec.suppressed_reason is not null then
          v_suppressed_reason := v_rec.suppressed_reason;
        elsif v_rec.recipient_user_id is not null
          and not public.user_has_calendar_event_visibility(
            p_event.tenant_id,
            v_rec.recipient_user_id,
            p_event.id
          ) then
          v_suppressed_reason := 'recipient_not_calendar_authorized';
        elsif exists (
          select 1
          from public.employees e
          where e.tenant_id = p_event.tenant_id
            and e.is_active = true
            and e.user_id is not null
            and (
              e.id = p_event.assigned_agent_id
              or exists (
                select 1
                from public.calendar_event_participants p
                where p.tenant_id = p_event.tenant_id
                  and p.event_id = p_event.id
                  and p.employee_id = e.id
              )
            )
            and not public.user_has_calendar_event_visibility(
              p_event.tenant_id, e.user_id, p_event.id
            )
        ) then
          v_suppressed_reason := 'recipient_not_calendar_authorized';
        else
          v_suppressed_reason := 'no_assigned_recipient';
        end if;
      else
        v_mode := 'recipients';
      end if;
    else
      -- Anchor resolve failed unexpectedly → suppress safely.
      v_mode := 'null_recipient';
      v_status := 'suppressed'::public.calendar_reminder_plan_status;
      v_suppressed_reason := 'no_assigned_recipient';
    end if;
  end if;

  if v_mode = 'null_recipient' then
    -- Prefer one in-place upsert target so M3 assignee-only and 096 semantics
    -- keep a single active occurrence row (not cancel+orphan).
    -- Priority: open null-recipient > open recipient (convert in place) >
    -- cancelled_superseded null-recipient > insert.
    select *
    into v_existing
    from public.calendar_reminder_plans crp
    where crp.tenant_id = p_event.tenant_id
      and crp.calendar_event_id = p_event.id
      and crp.rule_key = p_rule_key
      and crp.occurrence_scheduled_date = p_event.scheduled_date
      and crp.status in (
        'planned'::public.calendar_reminder_plan_status,
        'delivery_pending'::public.calendar_reminder_plan_status,
        'suppressed'::public.calendar_reminder_plan_status,
        'skipped'::public.calendar_reminder_plan_status,
        'cancelled_superseded'::public.calendar_reminder_plan_status
      )
    order by
      case
        when crp.recipient_employee_id is null
          and crp.status = any (v_open_statuses) then 0
        when crp.recipient_employee_id is not null
          and crp.status = any (v_open_statuses) then 1
        when crp.status = 'cancelled_superseded'::public.calendar_reminder_plan_status
          then 2
        else 3
      end,
      crp.updated_at desc nulls last
    limit 1
    for update;

    if found then
      -- Cancel-supersede OTHER open recipient plans (multi-participant → suppress).
      update public.calendar_reminder_plans crp
      set
        status = 'cancelled_superseded'::public.calendar_reminder_plan_status,
        cancelled_at = now(),
        next_attempt_at = null,
        suppressed_reason = null,
        resolution_code = null,
        updated_at = now()
      where crp.tenant_id = p_event.tenant_id
        and crp.calendar_event_id = p_event.id
        and crp.rule_key = p_rule_key
        and crp.occurrence_scheduled_date = p_event.scheduled_date
        and crp.id is distinct from v_existing.id
        and crp.recipient_employee_id is not null
        and crp.status = any (v_open_statuses);

      -- Never leave two open null-recipient rows.
      update public.calendar_reminder_plans crp
      set
        status = 'cancelled_superseded'::public.calendar_reminder_plan_status,
        cancelled_at = now(),
        next_attempt_at = null,
        suppressed_reason = null,
        resolution_code = null,
        updated_at = now()
      where crp.tenant_id = p_event.tenant_id
        and crp.calendar_event_id = p_event.id
        and crp.rule_key = p_rule_key
        and crp.occurrence_scheduled_date = p_event.scheduled_date
        and crp.recipient_employee_id is null
        and crp.id is distinct from v_existing.id
        and crp.status = any (v_open_statuses);

      update public.calendar_reminder_plans crp
      set
        status = v_status,
        resolution_code = v_resolution_code,
        suppressed_reason = v_suppressed_reason,
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
        last_error_code = null,
        last_error_message = null,
        attempt_count = 0,
        updated_at = now()
      where crp.id = v_existing.id;
    elsif v_allow_insert then
      insert into public.calendar_reminder_plans (
        tenant_id, calendar_event_id, rule_key, occurrence_scheduled_date,
        channel, status, resolution_code, suppressed_reason
      ) values (
        p_event.tenant_id, p_event.id, p_rule_key, p_event.scheduled_date,
        'in_app'::public.notification_channel,
        v_status, v_resolution_code, v_suppressed_reason
      );
    end if;

    return;
  end if;

  -- Recipient-specific planned mode.
  -- Convert one open null-recipient plan into the first desired recipient only when
  -- that recipient has no non-cancelled row yet (avoids unique collisions with an
  -- existing planned/delivered row for the same recipient identity).
  select *
  into v_existing
  from public.calendar_reminder_plans crp
  where crp.tenant_id = p_event.tenant_id
    and crp.calendar_event_id = p_event.id
    and crp.rule_key = p_rule_key
    and crp.occurrence_scheduled_date = p_event.scheduled_date
    and crp.recipient_employee_id is null
    and crp.status = any (v_open_statuses)
  order by crp.updated_at desc nulls last
  limit 1
  for update;

  if found then
    select * into v_rec
    from public.list_calendar_reminder_recipients_for_event(p_event) r
    order by r.recipient_employee_id
    limit 1;

    if found
      and not exists (
        select 1
        from public.calendar_reminder_plans crp
        where crp.tenant_id = p_event.tenant_id
          and crp.calendar_event_id = p_event.id
          and crp.rule_key = p_rule_key
          and crp.occurrence_scheduled_date = p_event.scheduled_date
          and crp.recipient_employee_id = v_rec.recipient_employee_id
          and crp.status not in (
            'cancelled_superseded'::public.calendar_reminder_plan_status,
            'cancelled_event'::public.calendar_reminder_plan_status
          )
      ) then
      v_apply_status := 'planned'::public.calendar_reminder_plan_status;

      update public.calendar_reminder_plans crp
      set
        status = v_apply_status,
        resolution_code = null,
        suppressed_reason = null,
        anchor_local_date = v_anchor_local_date,
        anchor_local_time = v_anchor_local_time,
        anchor_utc = v_anchor_utc,
        timezone_name = v_timezone_name,
        dst_resolution_code = v_dst_code,
        dst_shift_seconds = v_dst_shift_seconds,
        recipient_user_id = v_rec.recipient_user_id,
        recipient_employee_id = v_rec.recipient_employee_id,
        cancelled_at = null,
        last_error_code = null,
        last_error_message = null,
        attempt_count = 0,
        next_attempt_at = null,
        updated_at = now()
      where crp.id = v_existing.id;
    else
      -- Recipient already has a live/terminal row, or no recipients: drop null row.
      update public.calendar_reminder_plans crp
      set
        status = 'cancelled_superseded'::public.calendar_reminder_plan_status,
        cancelled_at = now(),
        next_attempt_at = null,
        suppressed_reason = null,
        resolution_code = null,
        updated_at = now()
      where crp.id = v_existing.id;
    end if;
  end if;

  update public.calendar_reminder_plans crp
  set
    status = 'cancelled_superseded'::public.calendar_reminder_plan_status,
    cancelled_at = now(),
    next_attempt_at = null,
    suppressed_reason = null,
    resolution_code = null,
    updated_at = now()
  where crp.tenant_id = p_event.tenant_id
    and crp.calendar_event_id = p_event.id
    and crp.rule_key = p_rule_key
    and crp.occurrence_scheduled_date = p_event.scheduled_date
    and crp.recipient_employee_id is null
    and crp.status = any (v_open_statuses);

  -- 096-compatible single-plan reassignment: one open outgoing recipient
  -- becomes the sole desired recipient in place (preserve id / no orphan supersede).
  -- 096-compatible single open plan reassignment: retarget the sole open
  -- recipient plan in place only when the destination identity is free.
  if coalesce(cardinality(v_desired_employee_ids), 0) = 1 then
    select *
    into v_existing
    from public.calendar_reminder_plans crp
    where crp.tenant_id = p_event.tenant_id
      and crp.calendar_event_id = p_event.id
      and crp.rule_key = p_rule_key
      and crp.occurrence_scheduled_date = p_event.scheduled_date
      and crp.recipient_employee_id is not null
      and crp.status = any (v_open_statuses)
    order by crp.updated_at desc nulls last
    limit 1
    for update;

    if found
      and v_existing.recipient_employee_id is distinct from v_desired_employee_ids[1]
      and not exists (
        select 1
        from public.calendar_reminder_plans crp
        where crp.tenant_id = p_event.tenant_id
          and crp.calendar_event_id = p_event.id
          and crp.rule_key = p_rule_key
          and crp.occurrence_scheduled_date = p_event.scheduled_date
          and crp.recipient_employee_id = v_desired_employee_ids[1]
          and crp.id is distinct from v_existing.id
          and crp.status not in (
            'cancelled_superseded'::public.calendar_reminder_plan_status,
            'cancelled_event'::public.calendar_reminder_plan_status
          )
      )
      and (
        select count(*)
        from public.calendar_reminder_plans crp
        where crp.tenant_id = p_event.tenant_id
          and crp.calendar_event_id = p_event.id
          and crp.rule_key = p_rule_key
          and crp.occurrence_scheduled_date = p_event.scheduled_date
          and crp.recipient_employee_id is not null
          and crp.status = any (v_open_statuses)
      ) = 1
    then
      select r.recipient_user_id, r.recipient_employee_id
      into v_rec
      from public.list_calendar_reminder_recipients_for_event(p_event) r
      where r.recipient_employee_id = v_desired_employee_ids[1]
      limit 1;

      if found then
        v_apply_status := 'planned'::public.calendar_reminder_plan_status;
        v_reset_retry := true;

        update public.calendar_reminder_plans crp
        set
          status = v_apply_status,
          resolution_code = null,
          suppressed_reason = null,
          anchor_local_date = v_anchor_local_date,
          anchor_local_time = v_anchor_local_time,
          anchor_utc = v_anchor_utc,
          timezone_name = v_timezone_name,
          dst_resolution_code = v_dst_code,
          dst_shift_seconds = v_dst_shift_seconds,
          recipient_user_id = v_rec.recipient_user_id,
          recipient_employee_id = v_rec.recipient_employee_id,
          cancelled_at = null,
          last_error_code = null,
          last_error_message = null,
          attempt_count = 0,
          next_attempt_at = null,
          updated_at = now()
        where crp.id = v_existing.id;

        return;
      end if;
    end if;
  end if;

  -- Cancel-supersede OPEN recipient plans not in the desired set.
  update public.calendar_reminder_plans crp
  set
    status = 'cancelled_superseded'::public.calendar_reminder_plan_status,
    cancelled_at = now(),
    next_attempt_at = null,
    suppressed_reason = null,
    resolution_code = null,
    updated_at = now()
  where crp.tenant_id = p_event.tenant_id
    and crp.calendar_event_id = p_event.id
    and crp.rule_key = p_rule_key
    and crp.occurrence_scheduled_date = p_event.scheduled_date
    and crp.recipient_employee_id is not null
    and not (crp.recipient_employee_id = any (v_desired_employee_ids))
    and crp.status = any (v_open_statuses);

  -- Assignee-only occurrence: if any terminal plan already exists for this
  -- occurrence/rule, preserve 096 "no rematerialize after terminal" semantics.
  if not exists (
    select 1
    from public.calendar_event_participants p
    where p.tenant_id = p_event.tenant_id
      and p.event_id = p_event.id
  ) and exists (
    select 1
    from public.calendar_reminder_plans crp
    where crp.tenant_id = p_event.tenant_id
      and crp.calendar_event_id = p_event.id
      and crp.rule_key = p_rule_key
      and crp.occurrence_scheduled_date = p_event.scheduled_date
      and crp.status in (
        'delivered'::public.calendar_reminder_plan_status,
        'failed'::public.calendar_reminder_plan_status,
        'expired'::public.calendar_reminder_plan_status,
        'cancelled_event'::public.calendar_reminder_plan_status
      )
  ) then
    return;
  end if;

  for v_rec in
    select * from public.list_calendar_reminder_recipients_for_event(p_event)
  loop
    -- Never rewrite delivered/failed/expired/cancelled_event history.
    if exists (
      select 1
      from public.calendar_reminder_plans crp
      where crp.tenant_id = p_event.tenant_id
        and crp.calendar_event_id = p_event.id
        and crp.rule_key = p_rule_key
        and crp.occurrence_scheduled_date = p_event.scheduled_date
        and crp.recipient_employee_id = v_rec.recipient_employee_id
        and crp.status in (
          'delivered'::public.calendar_reminder_plan_status,
          'failed'::public.calendar_reminder_plan_status,
          'expired'::public.calendar_reminder_plan_status,
          'cancelled_event'::public.calendar_reminder_plan_status
        )
    ) then
      continue;
    end if;

    select *
    into v_existing
    from public.calendar_reminder_plans crp
    where crp.tenant_id = p_event.tenant_id
      and crp.calendar_event_id = p_event.id
      and crp.rule_key = p_rule_key
      and crp.occurrence_scheduled_date = p_event.scheduled_date
      and crp.recipient_employee_id = v_rec.recipient_employee_id
      and crp.status in (
        'planned'::public.calendar_reminder_plan_status,
        'delivery_pending'::public.calendar_reminder_plan_status,
        'suppressed'::public.calendar_reminder_plan_status,
        'skipped'::public.calendar_reminder_plan_status,
        'cancelled_superseded'::public.calendar_reminder_plan_status
      )
    order by
      case
        when crp.status = 'cancelled_superseded'::public.calendar_reminder_plan_status then 1
        else 0
      end,
      crp.updated_at desc nulls last
    limit 1
    for update;

    if found then
      v_apply_status := 'planned'::public.calendar_reminder_plan_status;

      v_reactivate := v_existing.status in (
        'suppressed'::public.calendar_reminder_plan_status,
        'skipped'::public.calendar_reminder_plan_status,
        'cancelled_superseded'::public.calendar_reminder_plan_status
      )
      and v_apply_status is distinct from v_existing.status;

      v_reset_retry :=
        v_apply_status in (
          'planned'::public.calendar_reminder_plan_status,
          'delivery_pending'::public.calendar_reminder_plan_status
        )
        and (
          v_reactivate
          or v_existing.recipient_user_id is distinct from v_rec.recipient_user_id
          or v_existing.recipient_employee_id is distinct from v_rec.recipient_employee_id
          or v_existing.anchor_local_date is distinct from v_anchor_local_date
          or v_existing.anchor_local_time is distinct from v_anchor_local_time
          or v_existing.anchor_utc is distinct from v_anchor_utc
          or v_existing.timezone_name is distinct from v_timezone_name
          or v_existing.dst_resolution_code is distinct from v_dst_code
          or v_existing.dst_shift_seconds is distinct from v_dst_shift_seconds
        );

      -- Preserve delivery_pending when identity/anchors unchanged (096).
      if v_existing.status = 'delivery_pending'::public.calendar_reminder_plan_status
        and v_apply_status = 'planned'::public.calendar_reminder_plan_status
        and not v_reset_retry then
        v_apply_status := 'delivery_pending'::public.calendar_reminder_plan_status;
      end if;

      update public.calendar_reminder_plans crp
      set
        status = v_apply_status,
        resolution_code = null,
        suppressed_reason = null,
        anchor_local_date = v_anchor_local_date,
        anchor_local_time = v_anchor_local_time,
        anchor_utc = v_anchor_utc,
        timezone_name = v_timezone_name,
        dst_resolution_code = v_dst_code,
        dst_shift_seconds = v_dst_shift_seconds,
        recipient_user_id = v_rec.recipient_user_id,
        recipient_employee_id = v_rec.recipient_employee_id,
        cancelled_at = case
          when v_existing.status = 'cancelled_superseded'::public.calendar_reminder_plan_status
            and v_apply_status <> 'cancelled_superseded'::public.calendar_reminder_plan_status
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
    else
      insert into public.calendar_reminder_plans (
        tenant_id, calendar_event_id, rule_key, occurrence_scheduled_date,
        channel, recipient_user_id, recipient_employee_id,
        anchor_local_date, anchor_local_time, anchor_utc, timezone_name,
        dst_resolution_code, dst_shift_seconds,
        status, resolution_code, suppressed_reason
      ) values (
        p_event.tenant_id, p_event.id, p_rule_key, p_event.scheduled_date,
        'in_app'::public.notification_channel,
        v_rec.recipient_user_id,
        v_rec.recipient_employee_id,
        v_anchor_local_date, v_anchor_local_time, v_anchor_utc, v_timezone_name,
        v_dst_code, v_dst_shift_seconds,
        'planned'::public.calendar_reminder_plan_status,
        null, null
      );
    end if;
  end loop;
end;
$$;

-- Safely suppress one plan into null-recipient identity without colliding
-- with another open null-recipient row for the same occurrence.
create or replace function public.suppress_calendar_reminder_plan_to_null_recipient(
  p_plan_id uuid,
  p_suppressed_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan public.calendar_reminder_plans%rowtype;
  v_other_id uuid;
begin
  select * into v_plan
  from public.calendar_reminder_plans crp
  where crp.id = p_plan_id
  for update;

  if not found then
    return;
  end if;

  if v_plan.status in (
    'delivered'::public.calendar_reminder_plan_status,
    'expired'::public.calendar_reminder_plan_status,
    'failed'::public.calendar_reminder_plan_status,
    'cancelled_event'::public.calendar_reminder_plan_status
  ) then
    return;
  end if;

  select crp.id
  into v_other_id
  from public.calendar_reminder_plans crp
  where crp.tenant_id = v_plan.tenant_id
    and crp.calendar_event_id = v_plan.calendar_event_id
    and crp.rule_key = v_plan.rule_key
    and crp.occurrence_scheduled_date = v_plan.occurrence_scheduled_date
    and crp.recipient_employee_id is null
    and crp.id is distinct from v_plan.id
    and crp.status in (
      'planned'::public.calendar_reminder_plan_status,
      'delivery_pending'::public.calendar_reminder_plan_status,
      'suppressed'::public.calendar_reminder_plan_status,
      'skipped'::public.calendar_reminder_plan_status
    )
  limit 1
  for update;

  if v_other_id is null then
    update public.calendar_reminder_plans crp
    set
      status = 'suppressed'::public.calendar_reminder_plan_status,
      suppressed_reason = p_suppressed_reason,
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

  -- Another open null-recipient plan exists: supersede this plan, upsert that one.
  update public.calendar_reminder_plans crp
  set
    status = 'cancelled_superseded'::public.calendar_reminder_plan_status,
    cancelled_at = now(),
    next_attempt_at = null,
    suppressed_reason = null,
    resolution_code = null,
    updated_at = now()
  where crp.id = v_plan.id;

  update public.calendar_reminder_plans crp
  set
    status = 'suppressed'::public.calendar_reminder_plan_status,
    suppressed_reason = p_suppressed_reason,
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
  where crp.id = v_other_id;
end;
$$;

-- Delivery path: accept participant recipients (not only assignee).
-- refresh is safe because apply is diff-based and preserves delivery_pending.
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
  v_still_recipient boolean;
begin
  select * into v_plan
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

  select * into v_event
  from public.calendar_events ce
  where ce.id = v_plan.calendar_event_id
    and ce.tenant_id = v_plan.tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  perform public.refresh_calendar_event_reminder_plans(v_event.id);

  select * into v_plan
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

  if v_event.scheduled_date is distinct from v_plan.occurrence_scheduled_date then
    return;
  end if;

  select exists (
    select 1
    from public.list_calendar_reminder_recipients_for_event(v_event) r
    where r.recipient_employee_id = v_plan.recipient_employee_id
      and r.recipient_user_id = v_plan.recipient_user_id
  ) into v_still_recipient;

  if not v_still_recipient then
    return;
  end if;

  select * into v_settings
  from public.tenant_calendar_settings tcs
  where tcs.tenant_id = v_plan.tenant_id;

  if not found
    or not v_settings.working_schedule_configured
    or v_settings.timezone_name is null
    or not public.is_valid_iana_timezone(v_settings.timezone_name) then
    perform public.suppress_calendar_reminder_plan_to_null_recipient(
      v_plan.id,
      case
        when not coalesce(v_settings.working_schedule_configured, false)
          then 'schedule_unconfigured'
        when v_settings.timezone_name is null then 'timezone_missing'
        else 'timezone_invalid'
      end
    );
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
    perform public.suppress_calendar_reminder_plan_to_null_recipient(
      v_plan.id, 'policy_disabled'
    );
    return;
  end if;

  if v_plan.recipient_user_id is null then
    perform public.suppress_calendar_reminder_plan_to_null_recipient(
      v_plan.id, 'no_assigned_recipient'
    );
    return;
  end if;

  if not public.user_has_calendar_event_visibility(
    v_plan.tenant_id, v_plan.recipient_user_id, v_event.id
  ) then
    perform public.suppress_calendar_reminder_plan_to_null_recipient(
      v_plan.id, 'recipient_not_calendar_authorized'
    );
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
    tenant_id, channel, recipient_type, recipient_id, recipient_address,
    subject, body_ar, body_en, template_key, status, sent_at,
    related_entity_table, related_entity_id
  ) values (
    v_plan.tenant_id,
    'in_app'::public.notification_channel,
    'user',
    v_plan.recipient_user_id,
    v_plan.recipient_user_id::text,
    v_subject_ar, v_body_ar, v_body_en,
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

-- Refresh also when time columns change; participants trigger separate.
drop trigger if exists trg_calendar_events_reminder_refresh on public.calendar_events;
create trigger trg_calendar_events_reminder_refresh
  after insert or update of
    scheduled_date,
    assigned_agent_id,
    status,
    scheduled_start_at,
    scheduled_end_at,
    scheduled_timezone_name
  on public.calendar_events
  for each row
  execute function public.trg_refresh_calendar_event_reminder_plans();

create or replace function public.trg_refresh_calendar_event_participants_reminders()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.refresh_calendar_event_reminder_plans(
    coalesce(new.event_id, old.event_id)
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_calendar_event_participants_reminder_refresh
  on public.calendar_event_participants;
create trigger trg_calendar_event_participants_reminder_refresh
  after insert or update or delete on public.calendar_event_participants
  for each row
  execute function public.trg_refresh_calendar_event_participants_reminders();

-- ---------------------------------------------------------------------------
-- Section O: Meeting notices
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

  -- Atomic reservation: unique winner inserts the notice row first.
  insert into public.calendar_meeting_notices (
    tenant_id, calendar_event_id, notice_kind,
    recipient_user_id, recipient_employee_id, operation_id, notification_id
  ) values (
    p_tenant_id, p_event_id, p_notice_kind,
    p_recipient_user_id, p_recipient_employee_id, p_operation_id, null
  )
  on conflict (
    tenant_id, calendar_event_id, notice_kind, recipient_user_id, operation_id
  ) do nothing
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

create or replace function public.emit_meeting_notices_for_operation(
  p_event public.calendar_events,
  p_operation_id uuid,
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
    perform public.emit_calendar_meeting_notice(
      p_event.tenant_id,
      p_event.id,
      p_notice_kind,
      v_emp.user_id,
      v_emp.employee_id,
      p_operation_id,
      p_event
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section P: Resolve timed window from business payload
-- ---------------------------------------------------------------------------
create or replace function public.resolve_manual_event_time_fields(
  p_tenant_id uuid,
  p_scheduled_date date,
  p_time_window jsonb
)
returns table (
  start_at timestamptz,
  end_at timestamptz,
  timezone_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_settings public.tenant_calendar_settings%rowtype;
  v_resolved record;
begin
  if p_time_window is null or jsonb_typeof(p_time_window) = 'null' then
    start_at := null;
    end_at := null;
    timezone_name := null;
    return next;
    return;
  end if;

  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = p_tenant_id;

  if not found
    or not coalesce(v_settings.working_schedule_configured, false)
    or v_settings.timezone_name is null
    or not public.is_valid_iana_timezone(v_settings.timezone_name) then
    raise exception 'calendar_timezone_unconfigured';
  end if;

  select *
  into v_resolved
  from public.resolve_appointment_time_window(
    v_settings.timezone_name,
    p_scheduled_date,
    p_time_window ->> 'start_local',
    p_time_window ->> 'end_local'
  );

  start_at := v_resolved.start_at;
  end_at := v_resolved.end_at;
  timezone_name := v_resolved.timezone_name;
  return next;
end;
$$;

create or replace function public.build_manual_calendar_event_response(
  p_event_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_event public.calendar_events%rowtype;
  v_today date;
  v_filters public.calendar_read_filter_bundle;
  v_row record;
begin
  select * into v_event
  from public.calendar_events ce
  where ce.id = p_event_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  v_today := public.try_tenant_local_today(v_event.tenant_id);
  v_filters := public.parse_calendar_read_filters('{}'::jsonb, 'tenant_wide', null);

  select s.event_json into v_row
  from public.calendar_read_scoped_events(
    v_event.tenant_id,
    'tenant_wide',
    null,
    v_filters,
    v_today
  ) s
  where s.event_id = p_event_id;

  return coalesce(v_row.event_json, jsonb_build_object('id', p_event_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- Section Q: Mutation RPCs
-- ---------------------------------------------------------------------------
create or replace function public.create_manual_calendar_event(
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
  v_business jsonb;
  v_acks jsonb;
  v_hash text;
  v_replay jsonb;
  v_participants uuid[];
  v_type public.calendar_event_type;
  v_date date;
  v_time record;
  v_schedule_warnings jsonb;
  v_overlap jsonb;
  v_event_id uuid;
  v_event public.calendar_events%rowtype;
  v_result jsonb;
  v_op_id uuid;
  v_customer uuid;
  v_location uuid;
  v_contract uuid;
  v_meeting_mode public.calendar_meeting_mode;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.is_manager() and not public.user_has_permission('calendar.create') then
    raise exception 'permission_denied';
  end if;

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_acks := public.manual_calendar_extract_acknowledgements(p_data);
  v_business := public.normalize_manual_calendar_create_payload(p_data);
  v_hash := public.manual_calendar_business_payload_hash(v_business);

  v_replay := public.resolve_manual_event_idempotency('create', p_idempotency_key, v_hash);
  if v_replay is not null then
    return v_replay;
  end if;

  v_type := (v_business ->> 'type')::public.calendar_event_type;
  v_date := (v_business ->> 'scheduled_date')::date;
  select coalesce(array_agg(value::text::uuid order by value::text), array[]::uuid[])
  into v_participants
  from jsonb_array_elements_text(coalesce(v_business -> 'participant_employee_ids', '[]'::jsonb));

  v_customer := nullif(v_business ->> 'customer_id', '')::uuid;
  v_location := nullif(v_business ->> 'service_location_id', '')::uuid;
  v_contract := nullif(v_business ->> 'contract_id', '')::uuid;

  perform public.validate_manual_calendar_links(
    v_tenant_id, v_type, v_customer, v_location, v_contract
  );
  perform public.validate_manual_participant_ids(v_tenant_id, v_participants, false, array[]::uuid[]);

  select * into v_time
  from public.resolve_manual_event_time_fields(
    v_tenant_id, v_date, v_business -> 'time_window'
  );

  perform public.acquire_calendar_conflict_locks(v_tenant_id, v_date, v_participants);

  v_schedule_warnings := public.detect_manual_calendar_schedule_warnings(
    v_tenant_id, v_date, v_time.start_at, v_time.end_at
  );
  v_overlap := public.detect_manual_calendar_overlap_warnings(
    v_tenant_id, v_date, v_time.start_at, v_time.end_at, v_participants, null
  );

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

  if v_business ? 'meeting_mode' and v_business ->> 'meeting_mode' is not null then
    v_meeting_mode := (v_business ->> 'meeting_mode')::public.calendar_meeting_mode;
  else
    v_meeting_mode := null;
  end if;

  insert into public.calendar_events (
    tenant_id, type, status, source_kind, source_key,
    scheduled_date, scheduled_time, original_due_date,
    title_ar, title_en, notes,
    customer_id, service_location_id, contract_id,
    assigned_agent_id, visit_id, product_unit_id,
    completed_at, completed_by,
    is_recurring, recurrence_rule, parent_event_id,
    generated_from_execution_fact_id,
    scheduled_start_at, scheduled_end_at, scheduled_timezone_name,
    free_text_team, free_text_location,
    meeting_mode, meeting_url,
    day_off_override_reason, day_off_override_at, day_off_override_by,
    schedule_version, created_by
  ) values (
    v_tenant_id, v_type, 'pending'::public.calendar_event_status,
    'manual'::public.calendar_event_source_kind, null,
    v_date, null, v_date,
    v_business ->> 'title_ar', v_business ->> 'title_en', v_business ->> 'notes',
    v_customer, v_location, v_contract,
    null, null, null,
    null, null,
    false, null, null,
    null,
    v_time.start_at, v_time.end_at, v_time.timezone_name,
    v_business ->> 'free_text_team', v_business ->> 'free_text_location',
    v_meeting_mode, v_business ->> 'meeting_url',
    case
      when exists (
        select 1 from jsonb_array_elements(v_schedule_warnings) w
        where w.value ->> 'code' = 'non_working_day'
      ) and coalesce((v_acks ->> 'acknowledge_non_working_day')::boolean, false)
      then v_acks ->> 'day_off_override_reason'
      else null
    end,
    case
      when exists (
        select 1 from jsonb_array_elements(v_schedule_warnings) w
        where w.value ->> 'code' = 'non_working_day'
      ) and coalesce((v_acks ->> 'acknowledge_non_working_day')::boolean, false)
      then now()
      else null
    end,
    case
      when exists (
        select 1 from jsonb_array_elements(v_schedule_warnings) w
        where w.value ->> 'code' = 'non_working_day'
      ) and coalesce((v_acks ->> 'acknowledge_non_working_day')::boolean, false)
      then auth.uid()
      else null
    end,
    1,
    auth.uid()
  )
  returning id into v_event_id;

  perform public.replace_calendar_event_participants(
    v_tenant_id, v_event_id, v_participants
  );

  select * into v_event from public.calendar_events where id = v_event_id;

  v_result := jsonb_build_object(
    'status', 'ok',
    'event', public.build_manual_calendar_event_response(v_event_id),
    'acknowledgements', v_acks
  );

  v_op_id := public.record_manual_event_operation(
    'create', p_idempotency_key, v_hash, v_event_id, v_result
  );

  perform public.emit_meeting_notices_for_operation(
    v_event, v_op_id, 'meeting_created', v_participants
  );

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'create', 'calendar_events', v_event_id,
    null, v_result
  );

  return v_result;
end;
$$;

create or replace function public.assert_manual_event_editable(
  p_event public.calendar_events,
  p_require_organizer_for_meeting boolean default true
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_event.source_kind is distinct from 'manual'::public.calendar_event_source_kind then
    raise exception 'validation_failed';
  end if;

  if p_event.status is distinct from 'pending'::public.calendar_event_status then
    raise exception 'validation_failed';
  end if;

  if not public.is_manager() and not public.user_has_permission('calendar.edit') then
    raise exception 'permission_denied';
  end if;

  if p_require_organizer_for_meeting
    and p_event.type = 'internal_meeting'::public.calendar_event_type
    and p_event.created_by is distinct from auth.uid() then
    raise exception 'permission_denied';
  end if;
end;
$$;

create or replace function public.merge_manual_calendar_update_business(
  p_event public.calendar_events,
  p_data jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_data jsonb;
  v_key text;
  v_merged jsonb;
  v_synthetic jsonb;
begin
  v_data := public.normalize_manual_calendar_update_payload(p_data);

  v_merged := jsonb_build_object(
    'type', p_event.type::text,
    'scheduled_date', to_char(p_event.scheduled_date, 'YYYY-MM-DD'),
    'title_ar', p_event.title_ar,
    'title_en', p_event.title_en,
    'notes', p_event.notes,
    'time_window', case
      when p_event.scheduled_start_at is null then null
      else jsonb_build_object(
        'start_local', to_char(
          p_event.scheduled_start_at at time zone p_event.scheduled_timezone_name, 'HH24:MI'
        ),
        'end_local', to_char(
          p_event.scheduled_end_at at time zone p_event.scheduled_timezone_name, 'HH24:MI'
        )
      )
    end,
    'customer_id', p_event.customer_id,
    'service_location_id', p_event.service_location_id,
    'contract_id', p_event.contract_id,
    'free_text_team', p_event.free_text_team,
    'free_text_location', p_event.free_text_location,
    'participant_employee_ids', coalesce(
      (
        select jsonb_agg(to_jsonb(p.employee_id::text) order by p.employee_id)
        from public.calendar_event_participants p
        where p.tenant_id = p_event.tenant_id and p.event_id = p_event.id
      ),
      '[]'::jsonb
    ),
    'meeting_mode', p_event.meeting_mode,
    'meeting_url', p_event.meeting_url
  );

  -- Overlay provided update keys onto current snapshot, then normalize as create.
  for v_key in select jsonb_object_keys(v_data) loop
    v_merged := v_merged || jsonb_build_object(v_key, v_data -> v_key);
  end loop;

  return public.normalize_manual_calendar_create_payload(v_merged);
end;
$$;

create or replace function public.update_manual_calendar_event(
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
  v_business jsonb;
  v_acks jsonb;
  v_patch jsonb;
  v_hash text;
  v_replay jsonb;
  v_old_participants uuid[];
  v_new_participants uuid[];
  v_lock_ids uuid[];
  v_time record;
  v_schedule_warnings jsonb;
  v_overlap jsonb;
  v_customer uuid;
  v_location uuid;
  v_contract uuid;
  v_type public.calendar_event_type;
  v_date date;
  v_meeting_mode public.calendar_meeting_mode;
  v_result jsonb;
  v_op_id uuid;
  v_material_change boolean := false;
  v_added uuid[];
  v_removed uuid[];
  v_remaining uuid[];
  v_before jsonb;
  v_after jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_event_id is null or p_expected_version is null or p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_acks := public.manual_calendar_extract_acknowledgements(p_data);

  -- Hash from client whitelist patch only — never merge current event for identity.
  v_patch := public.normalize_manual_calendar_update_patch(p_data);
  v_hash := public.manual_calendar_business_payload_hash(
    jsonb_build_object(
      'operation_kind', 'update',
      'event_id', p_event_id,
      'expected_version', p_expected_version,
      'patch', v_patch
    )
  );

  v_replay := public.resolve_manual_event_idempotency('update', p_idempotency_key, v_hash);
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

  perform public.assert_manual_event_editable(v_event, true);

  if v_event.schedule_version is distinct from p_expected_version then
    raise exception 'stale_version';
  end if;

  v_before := public.snapshot_manual_calendar_event_audit(p_event_id);

  v_business := public.merge_manual_calendar_update_business(v_event, p_data);

  v_type := v_event.type;
  v_date := v_event.scheduled_date;

  select coalesce(array_agg(p.employee_id order by p.employee_id), array[]::uuid[])
  into v_old_participants
  from public.calendar_event_participants p
  where p.tenant_id = v_tenant_id and p.event_id = p_event_id;

  select coalesce(array_agg(value::text::uuid order by value::text), array[]::uuid[])
  into v_new_participants
  from jsonb_array_elements_text(coalesce(v_business -> 'participant_employee_ids', '[]'::jsonb));

  v_customer := nullif(v_business ->> 'customer_id', '')::uuid;
  v_location := nullif(v_business ->> 'service_location_id', '')::uuid;
  v_contract := nullif(v_business ->> 'contract_id', '')::uuid;

  perform public.validate_manual_calendar_links(
    v_tenant_id, v_type, v_customer, v_location, v_contract
  );
  perform public.validate_manual_participant_ids(
    v_tenant_id, v_new_participants, true, v_old_participants
  );

  select * into v_time
  from public.resolve_manual_event_time_fields(
    v_tenant_id, v_date, v_business -> 'time_window'
  );

  select coalesce(array_agg(distinct x order by x), array[]::uuid[])
  into v_lock_ids
  from unnest(v_old_participants || v_new_participants) as x;

  perform public.acquire_calendar_conflict_locks(v_tenant_id, v_date, v_lock_ids);

  v_schedule_warnings := public.detect_manual_calendar_schedule_warnings(
    v_tenant_id, v_date, v_time.start_at, v_time.end_at
  );
  v_overlap := public.detect_manual_calendar_overlap_warnings(
    v_tenant_id, v_date, v_time.start_at, v_time.end_at, v_new_participants, p_event_id
  );

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

  if v_business ? 'meeting_mode' and v_business ->> 'meeting_mode' is not null then
    v_meeting_mode := (v_business ->> 'meeting_mode')::public.calendar_meeting_mode;
  else
    v_meeting_mode := null;
  end if;

  v_material_change :=
    (v_event.title_ar is distinct from (v_business ->> 'title_ar'))
    or (v_event.title_en is distinct from (v_business ->> 'title_en'))
    or (v_event.notes is distinct from (v_business ->> 'notes'))
    or (v_event.scheduled_start_at is distinct from v_time.start_at)
    or (v_event.scheduled_end_at is distinct from v_time.end_at)
    or (v_event.scheduled_timezone_name is distinct from v_time.timezone_name)
    or (v_event.meeting_mode is distinct from v_meeting_mode)
    or (v_event.free_text_location is distinct from (v_business ->> 'free_text_location'))
    or (v_event.meeting_url is distinct from (v_business ->> 'meeting_url'));

  update public.calendar_events ce
  set
    title_ar = v_business ->> 'title_ar',
    title_en = v_business ->> 'title_en',
    notes = v_business ->> 'notes',
    customer_id = v_customer,
    service_location_id = v_location,
    contract_id = v_contract,
    scheduled_time = null,
    scheduled_start_at = v_time.start_at,
    scheduled_end_at = v_time.end_at,
    scheduled_timezone_name = v_time.timezone_name,
    free_text_team = v_business ->> 'free_text_team',
    free_text_location = v_business ->> 'free_text_location',
    meeting_mode = v_meeting_mode,
    meeting_url = v_business ->> 'meeting_url',
    day_off_override_reason = case
      when exists (
        select 1 from jsonb_array_elements(v_schedule_warnings) w
        where w.value ->> 'code' = 'non_working_day'
      ) and coalesce((v_acks ->> 'acknowledge_non_working_day')::boolean, false)
      then v_acks ->> 'day_off_override_reason'
      else ce.day_off_override_reason
    end,
    day_off_override_at = case
      when exists (
        select 1 from jsonb_array_elements(v_schedule_warnings) w
        where w.value ->> 'code' = 'non_working_day'
      ) and coalesce((v_acks ->> 'acknowledge_non_working_day')::boolean, false)
      then now()
      else ce.day_off_override_at
    end,
    day_off_override_by = case
      when exists (
        select 1 from jsonb_array_elements(v_schedule_warnings) w
        where w.value ->> 'code' = 'non_working_day'
      ) and coalesce((v_acks ->> 'acknowledge_non_working_day')::boolean, false)
      then auth.uid()
      else ce.day_off_override_by
    end,
    schedule_version = ce.schedule_version + 1
  where ce.id = p_event_id;

  perform public.replace_calendar_event_participants(
    v_tenant_id, p_event_id, v_new_participants
  );

  select * into v_event from public.calendar_events where id = p_event_id;

  select coalesce(array_agg(x order by x), array[]::uuid[])
  into v_added
  from unnest(v_new_participants) as x
  where x <> all (v_old_participants);

  select coalesce(array_agg(x order by x), array[]::uuid[])
  into v_removed
  from unnest(v_old_participants) as x
  where x <> all (v_new_participants);

  select coalesce(array_agg(x order by x), array[]::uuid[])
  into v_remaining
  from unnest(v_new_participants) as x
  where x <> all (v_added);

  v_result := jsonb_build_object(
    'status', 'ok',
    'event', public.build_manual_calendar_event_response(p_event_id),
    'acknowledgements', v_acks
  );

  v_op_id := public.record_manual_event_operation(
    'update', p_idempotency_key, v_hash, p_event_id, v_result
  );

  if v_material_change then
    perform public.emit_meeting_notices_for_operation(
      v_event, v_op_id, 'meeting_updated', v_remaining
    );
  end if;
  perform public.emit_meeting_notices_for_operation(
    v_event, v_op_id, 'meeting_invited', v_added
  );
  perform public.emit_meeting_notices_for_operation(
    v_event, v_op_id, 'meeting_removed', v_removed
  );

  v_after := public.snapshot_manual_calendar_event_audit(p_event_id);

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'update', 'calendar_events', p_event_id,
    v_before, v_after
  );

  return v_result;
end;
$$;

create or replace function public.cancel_manual_calendar_event(
  p_event_id uuid,
  p_expected_version int,
  p_reason text,
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
  v_reason text;
  v_hash text;
  v_replay jsonb;
  v_participants uuid[];
  v_result jsonb;
  v_op_id uuid;
  v_before jsonb;
  v_after jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_event_id is null or p_expected_version is null or p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_reason := btrim(coalesce(p_reason, ''));
  if v_reason = '' or length(v_reason) > 1000 then
    raise exception 'validation_failed';
  end if;

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_hash := public.manual_calendar_business_payload_hash(
    jsonb_build_object(
      'event_id', p_event_id,
      'expected_version', p_expected_version,
      'reason', v_reason
    )
  );

  v_replay := public.resolve_manual_event_idempotency('cancel', p_idempotency_key, v_hash);
  if v_replay is not null then
    return v_replay;
  end if;

  select * into v_event
  from public.calendar_events ce
  where ce.id = p_event_id and ce.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  perform public.assert_manual_event_editable(v_event, true);

  if v_event.schedule_version is distinct from p_expected_version then
    raise exception 'stale_version';
  end if;

  select coalesce(array_agg(p.employee_id order by p.employee_id), array[]::uuid[])
  into v_participants
  from public.calendar_event_participants p
  where p.tenant_id = v_tenant_id and p.event_id = p_event_id;

  v_before := public.snapshot_manual_calendar_event_audit(p_event_id);

  update public.calendar_events ce
  set
    status = 'cancelled'::public.calendar_event_status,
    cancellation_reason = v_reason,
    schedule_version = ce.schedule_version + 1
  where ce.id = p_event_id;

  perform public.cancel_open_calendar_reminder_plans_for_event(p_event_id);

  select * into v_event from public.calendar_events where id = p_event_id;

  v_result := jsonb_build_object(
    'status', 'ok',
    'event', public.build_manual_calendar_event_response(p_event_id)
  );

  v_op_id := public.record_manual_event_operation(
    'cancel', p_idempotency_key, v_hash, p_event_id, v_result
  );

  perform public.emit_meeting_notices_for_operation(
    v_event, v_op_id, 'meeting_cancelled', v_participants
  );

  v_after := public.snapshot_manual_calendar_event_audit(p_event_id);

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'cancel', 'calendar_events', p_event_id,
    v_before, v_after
  );

  return v_result;
end;
$$;

create or replace function public.mark_manual_event_done(
  p_event_id uuid,
  p_expected_version int,
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
  v_hash text;
  v_replay jsonb;
  v_result jsonb;
  v_op_id uuid;
  v_before jsonb;
  v_after jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_event_id is null or p_expected_version is null or p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  v_hash := public.manual_calendar_business_payload_hash(
    jsonb_build_object(
      'event_id', p_event_id,
      'expected_version', p_expected_version
    )
  );

  v_replay := public.resolve_manual_event_idempotency('mark_done', p_idempotency_key, v_hash);
  if v_replay is not null then
    return v_replay;
  end if;

  select * into v_event
  from public.calendar_events ce
  where ce.id = p_event_id and ce.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  -- Organizer gate for meetings; calendar.edit for all five manual types.
  perform public.assert_manual_event_editable(v_event, true);

  if v_event.type not in (
    'customer_visit'::public.calendar_event_type,
    'internal_meeting'::public.calendar_event_type,
    'internal_task'::public.calendar_event_type,
    'internal_activity'::public.calendar_event_type,
    'custom'::public.calendar_event_type
  ) then
    raise exception 'validation_failed';
  end if;

  if v_event.schedule_version is distinct from p_expected_version then
    raise exception 'stale_version';
  end if;

  v_before := public.snapshot_manual_calendar_event_audit(p_event_id);

  update public.calendar_events ce
  set
    status = 'done'::public.calendar_event_status,
    completed_at = now(),
    completed_by = auth.uid(),
    schedule_version = ce.schedule_version + 1
  where ce.id = p_event_id;

  perform public.cancel_open_calendar_reminder_plans_for_event(p_event_id);

  v_result := jsonb_build_object(
    'status', 'ok',
    'event', public.build_manual_calendar_event_response(p_event_id)
  );

  v_op_id := public.record_manual_event_operation(
    'mark_done', p_idempotency_key, v_hash, p_event_id, v_result
  );

  -- Close: no participant blast.

  v_after := public.snapshot_manual_calendar_event_audit(p_event_id);

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'mark_done', 'calendar_events', p_event_id,
    v_before, v_after
  );

  return v_result;
end;
$$;

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
        'has_app_account', e.user_id is not null
      )
      order by e.name_ar, e.id
    ),
    '[]'::jsonb
  )
  into v_rows
  from (
    select e.*
    from public.employees e
    where e.tenant_id = v_tenant_id
      and e.is_active = true
      and (
        v_search is null
        or lower(coalesce(e.name_ar, '')) like '%' || v_search || '%'
        or lower(coalesce(e.name_en, '')) like '%' || v_search || '%'
        or lower(coalesce(e.code, '')) like '%' || v_search || '%'
      )
    order by e.name_ar, e.id
    limit v_limit
  ) e;

  return jsonb_build_object('rows', coalesce(v_rows, '[]'::jsonb));
end;
$$;


-- ---------------------------------------------------------------------------
-- Section R: Read supersessions (sort ranks, scope, DTO, dual order/cursors)
-- ---------------------------------------------------------------------------
create or replace function public.calendar_event_type_sort_rank(
  p_type public.calendar_event_type
)
returns int
language sql
immutable
as $$
  select case p_type
    when 'refill_due' then 1
    when 'billing_due' then 2
    when 'payment_due' then 3
    when 'maintenance_due' then 4
    when 'follow_up' then 5
    when 'trial_ending' then 6
    when 'contract_start' then 7
    when 'contract_end' then 8
    when 'customer_visit' then 9
    when 'internal_meeting' then 10
    when 'internal_task' then 11
    when 'internal_activity' then 12
    when 'custom' then 13
    else 99
  end;
$$;

create or replace function public.decode_calendar_list_cursor(p_cursor text)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_raw text;
  v_json jsonb;
  v_last jsonb;
  v_bucket text;
begin
  if p_cursor is null or btrim(p_cursor) = '' then
    raise exception 'validation_failed';
  end if;

  begin
    v_raw := convert_from(decode(p_cursor, 'base64'), 'UTF8');
    v_json := v_raw::jsonb;
  exception
    when others then
      raise exception 'validation_failed';
  end;

  if coalesce((v_json ->> 'version')::int, 0) <> 2 then
    raise exception 'validation_failed';
  end if;

  if v_json ->> 'bucket' not in ('in_range', 'overdue_outside_range') then
    raise exception 'validation_failed';
  end if;

  if v_json -> 'last' is null or jsonb_typeof(v_json -> 'last') <> 'object' then
    raise exception 'validation_failed';
  end if;

  v_last := v_json -> 'last';
  v_bucket := v_json ->> 'bucket';

  if v_bucket = 'in_range' then
    if coalesce(v_last ->> 'bucket', '') <> 'in_range' then
      raise exception 'validation_failed';
    end if;
    if not (v_last ? 'scheduled_date' and v_last ? 'time_bucket' and v_last ? 'type_rank' and v_last ? 'event_id') then
      raise exception 'validation_failed';
    end if;
  else
    if coalesce(v_last ->> 'bucket', '') <> 'overdue' then
      raise exception 'validation_failed';
    end if;
    if not (
      v_last ? 'original_due_date'
      and v_last ? 'scheduled_date'
      and v_last ? 'time_bucket'
      and v_last ? 'type_rank'
      and v_last ? 'event_id'
    ) then
      raise exception 'validation_failed';
    end if;
  end if;

  return v_json;
  end;
$$;

drop function if exists public.calendar_read_scoped_events(
  uuid, text, uuid, public.calendar_read_filter_bundle, date
);

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
      s.working_schedule_configured,
      twd.day_mode,
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
        s.working_schedule_configured, twd.day_mode, ce.day_off_override_at
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
      jsonb_build_object(
        'tenant_id', ce.tenant_id,
        'date', ce.scheduled_date,
        'iso_weekday', extract(isodow from ce.scheduled_date)::int,
        'schedule_configured', s.working_schedule_configured,
        'timezone_name', s.timezone_name,
        'day_mode', twd.day_mode,
        'work_start', to_char(twd.work_start, 'HH24:MI'),
        'work_end', to_char(twd.work_end, 'HH24:MI'),
        'is_unreviewed', twd.day_mode is null,
        'is_day_off', twd.day_mode = 'day_off'::public.tenant_working_day_mode,
        'is_24_hours', twd.day_mode = '24_hours'::public.tenant_working_day_mode,
        'is_working_hours', twd.day_mode = 'working_hours'::public.tenant_working_day_mode
      ) as working_day_json,
      public.calendar_event_participants_json(ce.tenant_id, ce.id) as participants_json,
      public.calendar_event_time_window_json(
        ce.scheduled_start_at, ce.scheduled_end_at, ce.scheduled_timezone_name
      ) as time_window_json
    from public.calendar_events ce
    cross join settings s
    left join public.tenant_working_days twd
      on twd.tenant_id = ce.tenant_id
      and twd.iso_weekday = extract(isodow from ce.scheduled_date)::int
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
          s.working_schedule_configured, twd.day_mode, ce.day_off_override_at
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

create or replace function public.list_calendar_events(
  p_date_from date,
  p_date_to date,
  p_filters jsonb default '{}'::jsonb,
  p_cursor_in_range text default null,
  p_cursor_overdue text default null,
  p_limit int default null,
  p_include_overdue_outside_range boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ctx public.calendar_read_scope_context;
  v_tenant_id uuid;
  v_filters public.calendar_read_filter_bundle;
  v_filters_hash text;
  v_today date;
  v_limit int;
  v_in_rows jsonb := '[]'::jsonb;
  v_overdue_rows jsonb := '[]'::jsonb;
  v_in_next text := null;
  v_overdue_next text := null;
  v_in_has_more boolean := false;
  v_overdue_has_more boolean := false;
  v_last record;
  v_span int;
  v_cursor_in jsonb;
  v_cursor_overdue jsonb;
begin
  v_ctx := public.assert_calendar_event_view();
  v_tenant_id := public.current_tenant_id();
  v_filters := public.parse_calendar_read_filters(
    p_filters, v_ctx.scope, v_ctx.employee_id
  );
  v_filters_hash := public.calendar_read_filters_hash(v_filters);

  if p_date_from is null or p_date_to is null or p_date_from > p_date_to then
    raise exception 'validation_failed';
  end if;

  v_span := (p_date_to - p_date_from + 1);
  if v_span < 1 or v_span > public.calendar_read_max_range_days() then
    raise exception 'validation_failed';
  end if;

  v_limit := greatest(
    least(
      coalesce(p_limit, public.calendar_read_default_page_limit()),
      public.calendar_read_max_page_limit()
    ),
    1
  );

  if p_cursor_overdue is not null and not coalesce(p_include_overdue_outside_range, false) then
    raise exception 'validation_failed';
  end if;

  v_today := public.tenant_local_today(v_tenant_id);

  if p_cursor_in_range is not null then
    v_cursor_in := public.decode_calendar_list_cursor(p_cursor_in_range);
    perform public.validate_calendar_list_cursor_binding(
      v_cursor_in, v_tenant_id, v_ctx.scope, v_ctx.employee_id,
      p_date_from, p_date_to, 'in_range', v_filters_hash
    );
  end if;

  if p_cursor_overdue is not null then
    v_cursor_overdue := public.decode_calendar_list_cursor(p_cursor_overdue);
    perform public.validate_calendar_list_cursor_binding(
      v_cursor_overdue, v_tenant_id, v_ctx.scope, v_ctx.employee_id,
      p_date_from, p_date_to, 'overdue_outside_range', v_filters_hash
    );
  end if;

  with scoped as (
    select * from public.calendar_read_scoped_events(
      v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today
    )
  ),
  in_candidates as (
    select s.*
    from scoped s
    where s.scheduled_date between p_date_from and p_date_to
      and (
        v_cursor_in is null
        or (
          s.scheduled_date,
          s.time_bucket,
          coalesce(s.scheduled_start_at, '-infinity'::timestamptz),
          s.type_rank,
          s.event_id
        ) > (
          (v_cursor_in -> 'last' ->> 'scheduled_date')::date,
          (v_cursor_in -> 'last' ->> 'time_bucket')::int,
          coalesce(
            nullif(v_cursor_in -> 'last' ->> 'scheduled_start_at', '')::timestamptz,
            '-infinity'::timestamptz
          ),
          (v_cursor_in -> 'last' ->> 'type_rank')::int,
          (v_cursor_in -> 'last' ->> 'event_id')::uuid
        )
      )
    order by
      s.scheduled_date asc,
      s.time_bucket asc,
      s.scheduled_start_at asc nulls last,
      s.type_rank asc,
      s.event_id asc
    limit v_limit + 1
  )
  select
    coalesce(
      (
        select jsonb_agg(
          ic.event_json
          order by
            ic.scheduled_date,
            ic.time_bucket,
            ic.scheduled_start_at nulls last,
            ic.type_rank,
            ic.event_id
        )
        from (select * from in_candidates limit v_limit) ic
      ),
      '[]'::jsonb
    ),
    (select count(*) > v_limit from in_candidates)
  into v_in_rows, v_in_has_more;

  if v_in_has_more then
    select
      page.scheduled_date,
      page.time_bucket,
      page.scheduled_start_at,
      page.type_rank,
      page.event_id
    into v_last
    from (
      select s.*
      from public.calendar_read_scoped_events(
        v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today
      ) s
      where s.scheduled_date between p_date_from and p_date_to
        and (
          v_cursor_in is null
          or (
            s.scheduled_date,
            s.time_bucket,
            coalesce(s.scheduled_start_at, '-infinity'::timestamptz),
            s.type_rank,
            s.event_id
          ) > (
            (v_cursor_in -> 'last' ->> 'scheduled_date')::date,
            (v_cursor_in -> 'last' ->> 'time_bucket')::int,
            coalesce(
              nullif(v_cursor_in -> 'last' ->> 'scheduled_start_at', '')::timestamptz,
              '-infinity'::timestamptz
            ),
            (v_cursor_in -> 'last' ->> 'type_rank')::int,
            (v_cursor_in -> 'last' ->> 'event_id')::uuid
          )
        )
      order by
        s.scheduled_date asc,
        s.time_bucket asc,
        s.scheduled_start_at asc nulls last,
        s.type_rank asc,
        s.event_id asc
      limit v_limit
    ) page
    order by
      page.scheduled_date desc,
      page.time_bucket desc,
      page.scheduled_start_at desc nulls first,
      page.type_rank desc,
      page.event_id desc
    limit 1;

    v_in_next := public.encode_calendar_list_cursor(
      jsonb_build_object(
        'version', 2,
        'tenant_id', v_tenant_id,
        'scope', v_ctx.scope,
        'employee_id', v_ctx.employee_id,
        'bucket', 'in_range',
        'date_from', p_date_from,
        'date_to', p_date_to,
        'filters_hash', v_filters_hash,
        'last', jsonb_build_object(
          'bucket', 'in_range',
          'scheduled_date', v_last.scheduled_date,
          'time_bucket', v_last.time_bucket,
          'scheduled_start_at', v_last.scheduled_start_at,
          'type_rank', v_last.type_rank,
          'event_id', v_last.event_id
        )
      )
    );
  end if;

  if coalesce(p_include_overdue_outside_range, false) then
    with scoped as (
      select * from public.calendar_read_scoped_events(
        v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today
      )
    ),
    overdue_candidates as (
      select s.*
      from scoped s
      where s.scheduled_date < p_date_from
        and s.is_overdue
        and (
          v_cursor_overdue is null
          or (
            s.original_due_date,
            s.scheduled_date,
            s.time_bucket,
            coalesce(s.scheduled_start_at, '-infinity'::timestamptz),
            s.type_rank,
            s.event_id
          ) > (
            (v_cursor_overdue -> 'last' ->> 'original_due_date')::date,
            (v_cursor_overdue -> 'last' ->> 'scheduled_date')::date,
            (v_cursor_overdue -> 'last' ->> 'time_bucket')::int,
            coalesce(
              nullif(v_cursor_overdue -> 'last' ->> 'scheduled_start_at', '')::timestamptz,
              '-infinity'::timestamptz
            ),
            (v_cursor_overdue -> 'last' ->> 'type_rank')::int,
            (v_cursor_overdue -> 'last' ->> 'event_id')::uuid
          )
        )
      order by
        s.original_due_date asc,
        s.scheduled_date asc,
        s.time_bucket asc,
        s.scheduled_start_at asc nulls last,
        s.type_rank asc,
        s.event_id asc
      limit v_limit + 1
    )
    select
      coalesce(
        (
          select jsonb_agg(
            oc.event_json
            order by
              oc.original_due_date,
              oc.scheduled_date,
              oc.time_bucket,
              oc.scheduled_start_at nulls last,
              oc.type_rank,
              oc.event_id
          )
          from (select * from overdue_candidates limit v_limit) oc
        ),
        '[]'::jsonb
      ),
      (select count(*) > v_limit from overdue_candidates)
    into v_overdue_rows, v_overdue_has_more;

    if v_overdue_has_more then
      select
        page.original_due_date,
        page.scheduled_date,
        page.time_bucket,
        page.scheduled_start_at,
        page.type_rank,
        page.event_id
      into v_last
      from (
        select s.*
        from public.calendar_read_scoped_events(
          v_tenant_id, v_ctx.scope, v_ctx.employee_id, v_filters, v_today
        ) s
        where s.scheduled_date < p_date_from
          and s.is_overdue
          and (
            v_cursor_overdue is null
            or (
              s.original_due_date,
              s.scheduled_date,
              s.time_bucket,
              coalesce(s.scheduled_start_at, '-infinity'::timestamptz),
              s.type_rank,
              s.event_id
            ) > (
              (v_cursor_overdue -> 'last' ->> 'original_due_date')::date,
              (v_cursor_overdue -> 'last' ->> 'scheduled_date')::date,
              (v_cursor_overdue -> 'last' ->> 'time_bucket')::int,
              coalesce(
                nullif(v_cursor_overdue -> 'last' ->> 'scheduled_start_at', '')::timestamptz,
                '-infinity'::timestamptz
              ),
              (v_cursor_overdue -> 'last' ->> 'type_rank')::int,
              (v_cursor_overdue -> 'last' ->> 'event_id')::uuid
            )
          )
        order by
          s.original_due_date asc,
          s.scheduled_date asc,
          s.time_bucket asc,
          s.scheduled_start_at asc nulls last,
          s.type_rank asc,
          s.event_id asc
        limit v_limit
      ) page
      order by
        page.original_due_date desc,
        page.scheduled_date desc,
        page.time_bucket desc,
        page.scheduled_start_at desc nulls first,
        page.type_rank desc,
        page.event_id desc
      limit 1;

      v_overdue_next := public.encode_calendar_list_cursor(
        jsonb_build_object(
          'version', 2,
          'tenant_id', v_tenant_id,
          'scope', v_ctx.scope,
          'employee_id', v_ctx.employee_id,
          'bucket', 'overdue_outside_range',
          'date_from', p_date_from,
          'date_to', p_date_to,
          'filters_hash', v_filters_hash,
          'last', jsonb_build_object(
            'bucket', 'overdue',
            'original_due_date', v_last.original_due_date,
            'scheduled_date', v_last.scheduled_date,
            'time_bucket', v_last.time_bucket,
            'scheduled_start_at', v_last.scheduled_start_at,
            'type_rank', v_last.type_rank,
            'event_id', v_last.event_id
          )
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'limit', v_limit,
    'scope', v_ctx.scope,
    'tenant_local_today', v_today,
    'filters_hash', v_filters_hash,
    'in_range', jsonb_build_object(
      'rows', coalesce(v_in_rows, '[]'::jsonb),
      'next_cursor', v_in_next,
      'has_more', coalesce(v_in_has_more, false)
    ),
    'overdue_outside_range', jsonb_build_object(
      'rows', coalesce(v_overdue_rows, '[]'::jsonb),
      'next_cursor', v_overdue_next,
      'has_more', coalesce(v_overdue_has_more, false)
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section S: Grants / revokes
-- ---------------------------------------------------------------------------
revoke all on function public.calendar_is_safe_https_url(text)
  from public, anon, authenticated;
revoke all on function public.resolve_appointment_local_timestamptz(text, date, time)
  from public, anon, authenticated;
revoke all on function public.resolve_appointment_time_window(text, date, text, text)
  from public, anon, authenticated;
revoke all on function public.acquire_calendar_conflict_locks(uuid, date, uuid[])
  from public, anon, authenticated;
revoke all on function public.manual_calendar_ack_keys() from public, anon, authenticated;
revoke all on function public.manual_calendar_create_business_keys() from public, anon, authenticated;
revoke all on function public.manual_calendar_update_business_keys() from public, anon, authenticated;
revoke all on function public.manual_calendar_parse_optional_uuid(jsonb, text)
  from public, anon, authenticated;
revoke all on function public.manual_calendar_parse_optional_text(jsonb, text, int)
  from public, anon, authenticated;
revoke all on function public.manual_calendar_parse_participant_ids(jsonb)
  from public, anon, authenticated;
revoke all on function public.manual_calendar_parse_time_window(jsonb)
  from public, anon, authenticated;
revoke all on function public.manual_calendar_extract_acknowledgements(jsonb)
  from public, anon, authenticated;
revoke all on function public.manual_calendar_strip_ack_keys(jsonb)
  from public, anon, authenticated;
revoke all on function public.manual_calendar_business_payload_hash(jsonb)
  from public, anon, authenticated;
revoke all on function public.normalize_manual_calendar_create_payload(jsonb)
  from public, anon, authenticated;
revoke all on function public.normalize_manual_calendar_update_payload(jsonb)
  from public, anon, authenticated;
revoke all on function public.normalize_manual_calendar_update_patch(jsonb)
  from public, anon, authenticated;
revoke all on function public.snapshot_manual_calendar_event_audit(uuid)
  from public, anon, authenticated;
revoke all on function public.suppress_calendar_reminder_plan_to_null_recipient(uuid, text)
  from public, anon, authenticated;

revoke all on function public.resolve_manual_event_idempotency(text, uuid, text)
  from public, anon, authenticated;
revoke all on function public.record_manual_event_operation(text, uuid, text, uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.validate_manual_calendar_links(
  uuid, public.calendar_event_type, uuid, uuid, uuid
) from public, anon, authenticated;
revoke all on function public.validate_manual_participant_ids(uuid, uuid[], boolean, uuid[])
  from public, anon, authenticated;
revoke all on function public.replace_calendar_event_participants(uuid, uuid, uuid[])
  from public, anon, authenticated;
revoke all on function public.detect_manual_calendar_schedule_warnings(uuid, date, timestamptz, timestamptz)
  from public, anon, authenticated;
revoke all on function public.detect_manual_calendar_overlap_warnings(
  uuid, date, timestamptz, timestamptz, uuid[], uuid
) from public, anon, authenticated;
revoke all on function public.manual_calendar_conflict_requires_confirmation(jsonb, int, jsonb)
  from public, anon, authenticated;
revoke all on function public.calendar_event_time_window_json(timestamptz, timestamptz, text)
  from public, anon, authenticated;
revoke all on function public.calendar_event_participants_json(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.calendar_manual_available_actions_json(public.calendar_events, boolean)
  from public, anon, authenticated;
revoke all on function public.list_calendar_reminder_recipients_for_event(public.calendar_events)
  from public, anon, authenticated;
revoke all on function public.cancel_open_calendar_reminder_plans_for_occurrence(
  uuid, public.calendar_reminder_rule_key, date
) from public, anon, authenticated;
revoke all on function public.emit_calendar_meeting_notice(
  uuid, uuid, text, uuid, uuid, uuid, public.calendar_events
) from public, anon, authenticated;
revoke all on function public.emit_meeting_notices_for_operation(
  public.calendar_events, uuid, text, uuid[]
) from public, anon, authenticated;
revoke all on function public.resolve_manual_event_time_fields(uuid, date, jsonb)
  from public, anon, authenticated;
revoke all on function public.build_manual_calendar_event_response(uuid)
  from public, anon, authenticated;
revoke all on function public.assert_manual_event_editable(public.calendar_events, boolean)
  from public, anon, authenticated;
revoke all on function public.merge_manual_calendar_update_business(public.calendar_events, jsonb)
  from public, anon, authenticated;
revoke all on function public.trg_refresh_calendar_event_participants_reminders()
  from public, anon, authenticated;
revoke all on function public.calendar_read_scoped_events(
  uuid, text, uuid, public.calendar_read_filter_bundle, date
) from public, anon, authenticated;
revoke all on function public.decode_calendar_list_cursor(text)
  from public, anon, authenticated;

grant execute on function public.create_manual_calendar_event(jsonb, uuid) to authenticated;
grant execute on function public.update_manual_calendar_event(uuid, int, jsonb, uuid) to authenticated;
grant execute on function public.cancel_manual_calendar_event(uuid, int, text, uuid) to authenticated;
grant execute on function public.mark_manual_event_done(uuid, int, uuid) to authenticated;
grant execute on function public.list_calendar_participant_candidates(text, int) to authenticated;
grant execute on function public.get_calendar_range_summary(date, date, jsonb) to authenticated;
grant execute on function public.list_calendar_events(date, date, jsonb, text, text, int, boolean)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Section T: Postflight
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.ux_employees_tenant_id_id') is null then
    raise exception 'm7a_postflight_failed: missing_employees_unique';
  end if;

  if to_regclass('public.calendar_event_participants') is null then
    raise exception 'm7a_postflight_failed: missing_participants';
  end if;

  if to_regclass('public.calendar_manual_event_operations') is null then
    raise exception 'm7a_postflight_failed: missing_ops_ledger';
  end if;

  if to_regclass('public.calendar_meeting_notices') is null then
    raise exception 'm7a_postflight_failed: missing_meeting_notices';
  end if;

  if to_regclass('public.ux_calendar_reminder_plans_recipient_occurrence') is null
    or to_regclass('public.ux_calendar_reminder_plans_suppressed_occurrence') is null then
    raise exception 'm7a_postflight_failed: missing_reminder_partial_uniques';
  end if;

  if has_table_privilege('authenticated', 'public.calendar_event_participants', 'SELECT') then
    raise exception 'm7a_postflight_failed: authenticated can select participants';
  end if;

  if has_table_privilege('authenticated', 'public.calendar_manual_event_operations', 'SELECT') then
    raise exception 'm7a_postflight_failed: authenticated can select ops ledger';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.create_manual_calendar_event(jsonb, uuid)',
    'EXECUTE'
  ) then
    raise exception 'm7a_postflight_failed: create rpc not granted';
  end if;

  if public.calendar_event_type_sort_rank('customer_visit'::public.calendar_event_type) <> 9
    or public.calendar_event_type_sort_rank('custom'::public.calendar_event_type) <> 13 then
    raise exception 'm7a_postflight_failed: sort_rank_mismatch';
  end if;
end $$;
