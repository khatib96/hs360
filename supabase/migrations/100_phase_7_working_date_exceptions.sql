-- Phase 7 M7B: working-date exceptions (official holidays, company closures,
-- exceptional working days) that override the tenant weekly working schedule
-- for specific inclusive date ranges.
-- Depends on committed 093 (working schedule) and 099 (manual event schedule
-- warnings). Do not edit 093-099 sources; supersede via CREATE OR REPLACE here.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Section A: Preflight
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_extension where extname = 'btree_gist') then
    raise exception 'migration_preflight_failed: missing_btree_gist';
  end if;

  if to_regclass('public.tenant_calendar_settings') is null
    or to_regclass('public.tenant_working_days') is null then
    raise exception 'migration_preflight_failed: missing_093_calendar_tables';
  end if;

  if to_regprocedure('public.resolve_tenant_working_window(uuid, date)') is null then
    raise exception 'migration_preflight_failed: missing_093_resolve_tenant_working_window';
  end if;

  if to_regprocedure('public.assert_calendar_settings_view()') is null
    or to_regprocedure('public.assert_calendar_settings_edit()') is null then
    raise exception 'migration_preflight_failed: missing_093_calendar_settings_assertions';
  end if;

  if to_regprocedure('public.is_valid_iana_timezone(text)') is null
    or to_regprocedure('public.parse_calendar_work_time(text)') is null then
    raise exception 'migration_preflight_failed: missing_093_calendar_validation_helpers';
  end if;

  if to_regprocedure('public.tenant_local_today(uuid)') is null then
    raise exception 'migration_preflight_failed: missing_094_tenant_local_today';
  end if;

  if to_regprocedure('public.touch_updated_at()') is null then
    raise exception 'migration_preflight_failed: missing_touch_updated_at';
  end if;

  if to_regprocedure('public.bump_reminder_reconcile_generation(uuid)') is null then
    raise exception 'migration_preflight_failed: missing_096_bump_reminder_reconcile_generation';
  end if;

  if to_regprocedure(
    'public.detect_manual_calendar_schedule_warnings(uuid, date, timestamptz, timestamptz)'
  ) is null then
    raise exception 'migration_preflight_failed: missing_099_detect_manual_calendar_schedule_warnings';
  end if;

  if to_regprocedure('public.acquire_finance_idempotency_lock(uuid)') is null then
    raise exception 'migration_preflight_failed: missing_060_acquire_finance_idempotency_lock';
  end if;

  if not exists (
    select 1 from public.permissions where id = 'settings.calendar.view'
  ) or not exists (
    select 1 from public.permissions where id = 'settings.calendar.edit'
  ) then
    raise exception 'migration_preflight_failed: missing_calendar_settings_permissions';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section B: Enums
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_type where typname = 'tenant_working_date_exception_kind'
  ) then
    create type public.tenant_working_date_exception_kind as enum (
      'official_holiday',
      'company_closure',
      'exceptional_working_day'
    );
  end if;

  if not exists (
    select 1 from pg_type where typname = 'tenant_working_date_exception_status'
  ) then
    create type public.tenant_working_date_exception_status as enum (
      'active',
      'cancelled'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section C: tenant_working_date_exceptions
-- ---------------------------------------------------------------------------
create table if not exists public.tenant_working_date_exceptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  kind public.tenant_working_date_exception_kind not null,
  start_date date not null,
  end_date date not null,
  title_ar text,
  title_en text,
  notes text,
  day_mode public.tenant_working_day_mode,
  work_start time,
  work_end time,
  status public.tenant_working_date_exception_status not null default 'active',
  version int not null default 1,
  cancel_reason text,
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null,
  constraint chk_twde_date_order check (end_date >= start_date),
  constraint chk_twde_max_span check ((end_date - start_date) <= 365),
  constraint chk_twde_title_present check (
    nullif(btrim(coalesce(title_ar, '')), '') is not null
    or nullif(btrim(coalesce(title_en, '')), '') is not null
  ),
  constraint chk_twde_title_ar_len check (title_ar is null or char_length(title_ar) <= 200),
  constraint chk_twde_title_en_len check (title_en is null or char_length(title_en) <= 200),
  constraint chk_twde_notes_len check (notes is null or char_length(notes) <= 2000),
  constraint chk_twde_version_positive check (version >= 1),
  constraint chk_twde_mode_matrix check (
    (
      kind in (
        'official_holiday'::public.tenant_working_date_exception_kind,
        'company_closure'::public.tenant_working_date_exception_kind
      )
      and day_mode is null
      and work_start is null
      and work_end is null
    )
    or (
      kind = 'exceptional_working_day'::public.tenant_working_date_exception_kind
      and (
        (
          day_mode = '24_hours'::public.tenant_working_day_mode
          and work_start is null
          and work_end is null
        )
        or (
          day_mode = 'working_hours'::public.tenant_working_day_mode
          and work_start is not null
          and work_end is not null
          and work_start < work_end
        )
      )
    )
  ),
  constraint chk_twde_cancel_consistency check (
    (
      status = 'active'::public.tenant_working_date_exception_status
      and cancelled_at is null
      and cancelled_by is null
      and cancel_reason is null
    )
    or (
      status = 'cancelled'::public.tenant_working_date_exception_status
      and cancelled_at is not null
      and cancel_reason is not null
      and length(btrim(cancel_reason)) between 1 and 1000
    )
  ),
  -- Partial GiST exclusion: any two ACTIVE exceptions for the same tenant
  -- cannot cover overlapping inclusive date ranges, regardless of kind.
  -- This is the only overlap guard; no duplicate plain GiST index is added.
  constraint excl_tenant_working_date_exceptions_active_range
    exclude using gist (
      tenant_id with =,
      daterange(start_date, end_date, '[]') with &&
    )
    where (status = 'active'::public.tenant_working_date_exception_status)
);

comment on table public.tenant_working_date_exceptions is
  'M7B: tenant date-specific overrides of the weekly working schedule '
  '(official holidays, company closures, exceptional working days). '
  'Never rendered as calendar appointment cards.';
comment on column public.tenant_working_date_exceptions.day_mode is
  'Only set for exceptional_working_day (working_hours|24_hours). '
  'Null for official_holiday/company_closure, which always resolve to day_off.';
comment on constraint excl_tenant_working_date_exceptions_active_range
  on public.tenant_working_date_exceptions is
  'Deterministically rejects overlapping active exceptions for one tenant.';

create index if not exists idx_twde_list_order
  on public.tenant_working_date_exceptions (
    tenant_id, start_date, end_date, created_at, id
  );

drop trigger if exists trg_touch_tenant_working_date_exceptions
  on public.tenant_working_date_exceptions;
create trigger trg_touch_tenant_working_date_exceptions
  before update on public.tenant_working_date_exceptions
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Section D: Idempotency ledger
-- ---------------------------------------------------------------------------
create table if not exists public.working_date_exception_operations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  operation_type text not null,
  idempotency_key uuid not null,
  business_payload_hash text not null,
  result_status text not null,
  result_exception_id uuid,
  result_jsonb jsonb,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint chk_wdeo_operation_type check (
    operation_type in ('create', 'update', 'cancel')
  ),
  constraint chk_wdeo_result_status check (
    result_status in ('ok')
  ),
  constraint ux_working_date_exception_operations_idem
    unique (tenant_id, operation_type, idempotency_key)
);

create index if not exists idx_wdeo_result_exception
  on public.working_date_exception_operations (tenant_id, result_exception_id);

comment on table public.working_date_exception_operations is
  'M7B: idempotency ledger for working-date exception mutations.';

-- ---------------------------------------------------------------------------
-- Section E: Reminder reconcile bump trigger (schedule-affecting fields only)
-- ---------------------------------------------------------------------------
create or replace function public.trg_bump_reminder_reconcile_working_date_exception()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.bump_reminder_reconcile_generation(new.tenant_id);
    return new;
  end if;

  if new.start_date is distinct from old.start_date
    or new.end_date is distinct from old.end_date
    or new.kind is distinct from old.kind
    or new.day_mode is distinct from old.day_mode
    or new.work_start is distinct from old.work_start
    or new.work_end is distinct from old.work_end
    or new.status is distinct from old.status then
    perform public.bump_reminder_reconcile_generation(new.tenant_id);
  end if;

  return new;
end;
$$;

comment on function public.trg_bump_reminder_reconcile_working_date_exception() is
  'M7B: bumps the reminder reconcile generation on insert or whenever a '
  'schedule-affecting field changes; title/notes-only edits do not bump.';

drop trigger if exists trg_tenant_working_date_exceptions_reminder_enqueue
  on public.tenant_working_date_exceptions;
create trigger trg_tenant_working_date_exceptions_reminder_enqueue
  after insert or update on public.tenant_working_date_exceptions
  for each row
  execute function public.trg_bump_reminder_reconcile_working_date_exception();

-- ---------------------------------------------------------------------------
-- Section F: RLS + ACL (tables)
-- ---------------------------------------------------------------------------
alter table public.tenant_working_date_exceptions enable row level security;
alter table public.working_date_exception_operations enable row level security;

revoke all on table public.tenant_working_date_exceptions
  from public, anon, authenticated, service_role;
revoke all on table public.working_date_exception_operations
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Section G: Core helpers (snapshot / safe projection / hash / idempotency)
-- ---------------------------------------------------------------------------
create or replace function public.snapshot_working_date_exception_audit(p_exception_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', twde.id,
    'tenant_id', twde.tenant_id,
    'kind', twde.kind,
    'start_date', twde.start_date,
    'end_date', twde.end_date,
    'title_ar', twde.title_ar,
    'title_en', twde.title_en,
    'notes', twde.notes,
    'day_mode', twde.day_mode,
    'work_start', to_char(twde.work_start, 'HH24:MI'),
    'work_end', to_char(twde.work_end, 'HH24:MI'),
    'status', twde.status,
    'version', twde.version,
    'cancel_reason', twde.cancel_reason,
    'cancelled_at', twde.cancelled_at,
    'cancelled_by', twde.cancelled_by,
    'created_by', twde.created_by,
    'created_at', twde.created_at,
    'updated_by', twde.updated_by,
    'updated_at', twde.updated_at
  )
  from public.tenant_working_date_exceptions twde
  where twde.id = p_exception_id;
$$;

create or replace function public.safe_date_exception_json(
  p_exception public.tenant_working_date_exceptions
)
returns jsonb
language plpgsql
immutable
as $$
begin
  if p_exception is null or p_exception.id is null then
    return null;
  end if;
  return jsonb_build_object(
    'kind', p_exception.kind,
    'title_ar', p_exception.title_ar,
    'title_en', p_exception.title_en
  );
end;
$$;

comment on function public.safe_date_exception_json(public.tenant_working_date_exceptions) is
  'M7B: minimal safe projection (kind, title_ar, title_en only) for embedding '
  'an active exception inside working-window/warning payloads.';

create or replace function public.working_date_exception_payload_hash(p_payload jsonb)
returns text
language sql
stable
set search_path = public, extensions
as $$
  select encode(
    extensions.digest(convert_to(coalesce(p_payload, '{}'::jsonb)::text, 'UTF8'), 'sha256'),
    'hex'
  );
$$;

create or replace function public.resolve_working_date_exception_idempotency(
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
  v_row public.working_date_exception_operations%rowtype;
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
  from public.working_date_exception_operations op
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

create or replace function public.record_working_date_exception_operation(
  p_operation_type text,
  p_idempotency_key uuid,
  p_payload_hash text,
  p_result_exception_id uuid,
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
  insert into public.working_date_exception_operations (
    tenant_id, operation_type, idempotency_key, business_payload_hash,
    result_status, result_exception_id, result_jsonb, created_by
  ) values (
    public.current_tenant_id(), p_operation_type, p_idempotency_key, p_payload_hash,
    'ok', p_result_exception_id, p_result_jsonb, auth.uid()
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section H: Validation matrix + normalize (create/update) + merge
-- ---------------------------------------------------------------------------
create or replace function public.validate_working_date_exception_business_payload(p_business jsonb)
returns void
language plpgsql
immutable
set search_path = public
as $$
declare
  v_kind text;
  v_start_text text;
  v_end_text text;
  v_start date;
  v_end date;
  v_day_mode text;
  v_work_start time;
  v_work_end time;
begin
  if p_business is null or jsonb_typeof(p_business) <> 'object' then
    raise exception 'validation_failed';
  end if;

  v_kind := p_business ->> 'kind';
  if v_kind is null
    or v_kind not in ('official_holiday', 'company_closure', 'exceptional_working_day') then
    raise exception 'validation_failed';
  end if;

  v_start_text := p_business ->> 'start_date';
  v_end_text := p_business ->> 'end_date';
  if v_start_text is null
    or v_end_text is null
    or v_start_text !~ '^\d{4}-\d{2}-\d{2}$'
    or v_end_text !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'validation_failed';
  end if;

  begin
    v_start := v_start_text::date;
    v_end := v_end_text::date;
  exception
    when others then
      raise exception 'validation_failed';
  end;
  if v_start is null
    or v_end is null
    or to_char(v_start, 'YYYY-MM-DD') is distinct from v_start_text
    or to_char(v_end, 'YYYY-MM-DD') is distinct from v_end_text
    or v_end < v_start
    or (v_end - v_start) > 365 then
    raise exception 'validation_failed';
  end if;

  if nullif(btrim(coalesce(p_business ->> 'title_ar', '')), '') is null
    and nullif(btrim(coalesce(p_business ->> 'title_en', '')), '') is null then
    raise exception 'validation_failed';
  end if;

  if length(coalesce(p_business ->> 'title_ar', '')) > 200
    or length(coalesce(p_business ->> 'title_en', '')) > 200
    or length(coalesce(p_business ->> 'notes', '')) > 2000 then
    raise exception 'validation_failed';
  end if;

  v_day_mode := p_business ->> 'day_mode';

  if v_kind in ('official_holiday', 'company_closure') then
    if v_day_mode is not null
      or nullif(btrim(coalesce(p_business ->> 'work_start', '')), '') is not null
      or nullif(btrim(coalesce(p_business ->> 'work_end', '')), '') is not null then
      raise exception 'validation_failed';
    end if;
  else
    if v_day_mode is null or v_day_mode not in ('working_hours', '24_hours') then
      raise exception 'validation_failed';
    end if;

    if v_day_mode = 'working_hours' then
      v_work_start := public.parse_calendar_work_time(p_business ->> 'work_start');
      v_work_end := public.parse_calendar_work_time(p_business ->> 'work_end');
      if v_work_start >= v_work_end then
        raise exception 'validation_failed';
      end if;
    else
      if nullif(btrim(coalesce(p_business ->> 'work_start', '')), '') is not null
        or nullif(btrim(coalesce(p_business ->> 'work_end', '')), '') is not null then
        raise exception 'validation_failed';
      end if;
    end if;
  end if;
end;
$$;

create or replace function public.normalize_working_date_exception_create_payload(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_key text;
  v_out jsonb;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_data) loop
    if v_key <> all (array[
      'kind', 'start_date', 'end_date', 'title_ar', 'title_en',
      'notes', 'day_mode', 'work_start', 'work_end'
    ]) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if not (p_data ? 'kind') or not (p_data ? 'start_date') or not (p_data ? 'end_date') then
    raise exception 'validation_failed';
  end if;

  if jsonb_typeof(p_data -> 'kind') <> 'string'
    or jsonb_typeof(p_data -> 'start_date') <> 'string'
    or jsonb_typeof(p_data -> 'end_date') <> 'string' then
    raise exception 'validation_failed';
  end if;

  foreach v_key in array array[
    'title_ar', 'title_en', 'notes', 'day_mode', 'work_start', 'work_end'
  ] loop
    if p_data ? v_key
      and jsonb_typeof(p_data -> v_key) not in ('string', 'null') then
      raise exception 'validation_failed';
    end if;
  end loop;

  v_out := jsonb_build_object(
    'kind', p_data ->> 'kind',
    'start_date', p_data ->> 'start_date',
    'end_date', p_data ->> 'end_date',
    'title_ar', nullif(btrim(coalesce(p_data ->> 'title_ar', '')), ''),
    'title_en', nullif(btrim(coalesce(p_data ->> 'title_en', '')), ''),
    'notes', nullif(btrim(coalesce(p_data ->> 'notes', '')), ''),
    'day_mode', p_data ->> 'day_mode',
    'work_start', p_data ->> 'work_start',
    'work_end', p_data ->> 'work_end'
  );

  perform public.validate_working_date_exception_business_payload(v_out);

  return v_out;
end;
$$;

create or replace function public.normalize_working_date_exception_update_patch(p_data jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_key text;
  v_out jsonb := '{}'::jsonb;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_data) loop
    if v_key <> all (array[
      'kind', 'start_date', 'end_date', 'title_ar', 'title_en',
      'notes', 'day_mode', 'work_start', 'work_end'
    ]) then
      raise exception 'validation_failed';
    end if;
  end loop;

  foreach v_key in array array[
    'kind', 'start_date', 'end_date', 'title_ar', 'title_en',
    'notes', 'day_mode', 'work_start', 'work_end'
  ] loop
    if p_data ? v_key
      and jsonb_typeof(p_data -> v_key) not in ('string', 'null') then
      raise exception 'validation_failed';
    end if;
  end loop;

  if p_data ? 'kind' then
    if jsonb_typeof(p_data -> 'kind') <> 'string' then
      raise exception 'validation_failed';
    end if;
    v_out := v_out || jsonb_build_object('kind', p_data ->> 'kind');
  end if;

  if p_data ? 'start_date' then
    if jsonb_typeof(p_data -> 'start_date') <> 'string' then
      raise exception 'validation_failed';
    end if;
    v_out := v_out || jsonb_build_object('start_date', p_data ->> 'start_date');
  end if;

  if p_data ? 'end_date' then
    if jsonb_typeof(p_data -> 'end_date') <> 'string' then
      raise exception 'validation_failed';
    end if;
    v_out := v_out || jsonb_build_object('end_date', p_data ->> 'end_date');
  end if;

  if p_data ? 'title_ar' then
    v_out := v_out || jsonb_build_object(
      'title_ar', nullif(btrim(coalesce(p_data ->> 'title_ar', '')), '')
    );
  end if;

  if p_data ? 'title_en' then
    v_out := v_out || jsonb_build_object(
      'title_en', nullif(btrim(coalesce(p_data ->> 'title_en', '')), '')
    );
  end if;

  if p_data ? 'notes' then
    v_out := v_out || jsonb_build_object(
      'notes', nullif(btrim(coalesce(p_data ->> 'notes', '')), '')
    );
  end if;

  if p_data ? 'day_mode' then
    v_out := v_out || jsonb_build_object('day_mode', p_data ->> 'day_mode');
  end if;

  if p_data ? 'work_start' then
    v_out := v_out || jsonb_build_object('work_start', p_data ->> 'work_start');
  end if;

  if p_data ? 'work_end' then
    v_out := v_out || jsonb_build_object('work_end', p_data ->> 'work_end');
  end if;

  if v_out = '{}'::jsonb then
    raise exception 'validation_failed';
  end if;

  return v_out;
end;
$$;

create or replace function public.merge_working_date_exception_update_business(
  p_exception public.tenant_working_date_exceptions,
  p_patch jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_merged jsonb;
  v_key text;
begin
  v_merged := jsonb_build_object(
    'kind', p_exception.kind::text,
    'start_date', to_char(p_exception.start_date, 'YYYY-MM-DD'),
    'end_date', to_char(p_exception.end_date, 'YYYY-MM-DD'),
    'title_ar', p_exception.title_ar,
    'title_en', p_exception.title_en,
    'notes', p_exception.notes,
    'day_mode', p_exception.day_mode::text,
    'work_start', to_char(p_exception.work_start, 'HH24:MI'),
    'work_end', to_char(p_exception.work_end, 'HH24:MI')
  );

  for v_key in select jsonb_object_keys(p_patch) loop
    v_merged := v_merged || jsonb_build_object(v_key, p_patch -> v_key);
  end loop;

  perform public.validate_working_date_exception_business_payload(v_merged);

  return v_merged;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section I: Active exception lookup
-- ---------------------------------------------------------------------------
create or replace function public.load_active_working_date_exception(
  p_tenant_id uuid,
  p_date date
)
returns public.tenant_working_date_exceptions
language sql
stable
security definer
set search_path = public
as $$
  select twde.*
  from public.tenant_working_date_exceptions twde
  where twde.tenant_id = p_tenant_id
    and twde.status = 'active'::public.tenant_working_date_exception_status
    and p_date is not null
    and daterange(twde.start_date, twde.end_date, '[]') @> p_date
  limit 1;
$$;

comment on function public.load_active_working_date_exception(uuid, date) is
  'M7B: at most one row can match because active ranges never overlap '
  '(excl_tenant_working_date_exceptions_active_range).';

-- ---------------------------------------------------------------------------
-- Section J: CREATE OR REPLACE resolve_tenant_working_window (093 override)
-- ---------------------------------------------------------------------------
create or replace function public.resolve_tenant_working_window(
  p_tenant_id uuid,
  p_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_settings public.tenant_calendar_settings%rowtype;
  v_iso int;
  v_day public.tenant_working_days%rowtype;
  v_exception public.tenant_working_date_exceptions%rowtype;
  v_day_mode public.tenant_working_day_mode;
  v_work_start time;
  v_work_end time;
  v_is_unreviewed boolean;
  v_date_exception jsonb;
begin
  if p_tenant_id is null or p_date is null then
    raise exception 'validation_failed';
  end if;

  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = p_tenant_id;

  if not found then
    raise exception 'tenant_not_found';
  end if;

  v_iso := extract(isodow from p_date)::int;

  select * into v_day
  from public.tenant_working_days
  where tenant_id = p_tenant_id
    and iso_weekday = v_iso;

  v_day_mode := v_day.day_mode;
  v_work_start := v_day.work_start;
  v_work_end := v_day.work_end;
  v_is_unreviewed := v_day.day_mode is null;

  -- M7B: an active date exception overrides the weekly window even when the
  -- schedule is still unconfigured (is_unreviewed becomes false; schedule_configured
  -- remains false so reminders stay suppressed). Safe projection always surfaced.
  v_exception := public.load_active_working_date_exception(p_tenant_id, p_date);
  v_date_exception := public.safe_date_exception_json(v_exception);

  if v_exception.id is not null then
    if v_exception.kind in (
      'official_holiday'::public.tenant_working_date_exception_kind,
      'company_closure'::public.tenant_working_date_exception_kind
    ) then
      v_day_mode := 'day_off'::public.tenant_working_day_mode;
      v_work_start := null;
      v_work_end := null;
    else
      v_day_mode := v_exception.day_mode;
      v_work_start := v_exception.work_start;
      v_work_end := v_exception.work_end;
    end if;
    v_is_unreviewed := false;
  end if;

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'date', p_date,
    'iso_weekday', v_iso,
    'schedule_configured', v_settings.working_schedule_configured,
    'timezone_name', v_settings.timezone_name,
    'day_mode', v_day_mode,
    'work_start', to_char(v_work_start, 'HH24:MI'),
    'work_end', to_char(v_work_end, 'HH24:MI'),
    'is_unreviewed', v_is_unreviewed,
    'is_day_off', v_day_mode = 'day_off'::public.tenant_working_day_mode,
    'is_24_hours', v_day_mode = '24_hours'::public.tenant_working_day_mode,
    'is_working_hours', v_day_mode = 'working_hours'::public.tenant_working_day_mode,
    'date_exception', v_date_exception
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section K: CREATE OR REPLACE detect_manual_calendar_schedule_warnings (099)
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
  v_settings_found boolean;
begin
  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = p_tenant_id;
  v_settings_found := found;

  -- Resolve first: a date-specific exception remains authoritative even while
  -- the weekly schedule/timezone is awaiting owner configuration.
  v_window := public.resolve_tenant_working_window(p_tenant_id, p_scheduled_date);

  if not v_settings_found
    or not coalesce(v_settings.working_schedule_configured, false)
    or v_settings.timezone_name is null
    or not public.is_valid_iana_timezone(v_settings.timezone_name) then
    v_warnings := v_warnings || jsonb_build_array(
      jsonb_build_object('code', 'schedule_unconfigured')
    );
  end if;

  if coalesce(v_window ->> 'is_day_off', 'false')::boolean then
    -- M7B: always carry the safe exception projection alongside this code,
    -- whether or not an active exception is the reason for the day off.
    v_warnings := v_warnings || jsonb_build_array(
      jsonb_build_object(
        'code', 'non_working_day',
        'date_exception', v_window -> 'date_exception'
      )
    );
  end if;

  -- Without a confirmed timezone/weekly schedule there is no safe basis for
  -- comparing timestamptz values to a local working-hours window. The resolved
  -- day-off exception warning above is still preserved.
  if not v_settings_found
    or not coalesce(v_settings.working_schedule_configured, false)
    or v_settings.timezone_name is null
    or not public.is_valid_iana_timezone(v_settings.timezone_name) then
    return v_warnings;
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

-- ---------------------------------------------------------------------------
-- Section L: DTO builder
-- ---------------------------------------------------------------------------
create or replace function public.build_working_date_exception_response(p_exception_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', twde.id,
    'kind', twde.kind,
    'start_date', twde.start_date,
    'end_date', twde.end_date,
    'title_ar', twde.title_ar,
    'title_en', twde.title_en,
    'notes', twde.notes,
    'day_mode', twde.day_mode,
    'work_start', to_char(twde.work_start, 'HH24:MI'),
    'work_end', to_char(twde.work_end, 'HH24:MI'),
    'status', twde.status,
    'version', twde.version,
    'cancel_reason', twde.cancel_reason,
    'cancelled_at', twde.cancelled_at,
    'cancelled_by', twde.cancelled_by,
    'created_at', twde.created_at,
    'created_by', twde.created_by,
    'updated_at', twde.updated_at,
    'updated_by', twde.updated_by
  )
  from public.tenant_working_date_exceptions twde
  where twde.id = p_exception_id;
$$;

-- ---------------------------------------------------------------------------
-- Section M: Mutation RPCs (create / update / cancel)
-- ---------------------------------------------------------------------------
create or replace function public.create_working_date_exception(
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
  v_hash text;
  v_replay jsonb;
  v_exception_id uuid;
  v_result jsonb;
  v_op_id uuid;
begin
  -- 1. tenant + args
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_calendar_settings_edit();

  if p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  -- 2. idempotency lock
  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  -- 3. normalize payload
  v_business := public.normalize_working_date_exception_create_payload(p_data);

  -- 4. hash (operation_kind + business)
  v_hash := public.working_date_exception_payload_hash(
    jsonb_build_object('operation_kind', 'create', 'business', v_business)
  );

  -- 5. resolve idempotency BEFORE any row is loaded/mutated
  v_replay := public.resolve_working_date_exception_idempotency('create', p_idempotency_key, v_hash);
  if v_replay is not null then
    return v_replay;
  end if;

  -- 6. mutate (no existing row to load for create)
  begin
    insert into public.tenant_working_date_exceptions (
      tenant_id, kind, start_date, end_date, title_ar, title_en, notes,
      day_mode, work_start, work_end, status, version, created_by, updated_by
    ) values (
      v_tenant_id,
      (v_business ->> 'kind')::public.tenant_working_date_exception_kind,
      (v_business ->> 'start_date')::date,
      (v_business ->> 'end_date')::date,
      v_business ->> 'title_ar',
      v_business ->> 'title_en',
      v_business ->> 'notes',
      (v_business ->> 'day_mode')::public.tenant_working_day_mode,
      case
        when v_business ->> 'day_mode' = 'working_hours'
          then public.parse_calendar_work_time(v_business ->> 'work_start')
        else null
      end,
      case
        when v_business ->> 'day_mode' = 'working_hours'
          then public.parse_calendar_work_time(v_business ->> 'work_end')
        else null
      end,
      'active'::public.tenant_working_date_exception_status,
      1,
      auth.uid(),
      auth.uid()
    )
    returning id into v_exception_id;
  exception
    when exclusion_violation then
      raise exception 'working_date_exception_overlap';
  end;

  v_result := jsonb_build_object(
    'status', 'ok',
    'exception', public.build_working_date_exception_response(v_exception_id)
  );

  v_op_id := public.record_working_date_exception_operation(
    'create', p_idempotency_key, v_hash, v_exception_id, v_result
  );

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'create', 'tenant_working_date_exceptions', v_exception_id,
    null, public.snapshot_working_date_exception_audit(v_exception_id)
  );

  return v_result;
end;
$$;

create or replace function public.update_working_date_exception(
  p_exception_id uuid,
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
  v_exception public.tenant_working_date_exceptions%rowtype;
  v_patch jsonb;
  v_business jsonb;
  v_hash text;
  v_replay jsonb;
  v_before jsonb;
  v_after jsonb;
  v_result jsonb;
  v_op_id uuid;
begin
  -- 1. tenant + args
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_calendar_settings_edit();

  if p_exception_id is null or p_expected_version is null or p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  -- 2. idempotency lock
  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  -- 3. normalize the strict, whitelisted business patch.
  v_patch := public.normalize_working_date_exception_update_patch(p_data);

  -- 4. hash (operation_kind + ids/version + patch)
  v_hash := public.working_date_exception_payload_hash(
    jsonb_build_object(
      'operation_kind', 'update',
      'exception_id', p_exception_id,
      'expected_version', p_expected_version,
      'patch', v_patch
    )
  );

  -- 5. resolve idempotency BEFORE loading the row
  v_replay := public.resolve_working_date_exception_idempotency('update', p_idempotency_key, v_hash);
  if v_replay is not null then
    return v_replay;
  end if;

  -- 6. load, validate, mutate
  select * into v_exception
  from public.tenant_working_date_exceptions twde
  where twde.id = p_exception_id
    and twde.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_exception.status is distinct from 'active'::public.tenant_working_date_exception_status then
    raise exception 'validation_failed';
  end if;

  if v_exception.version is distinct from p_expected_version then
    raise exception 'stale_version';
  end if;

  v_before := public.snapshot_working_date_exception_audit(p_exception_id);

  v_business := public.merge_working_date_exception_update_business(v_exception, v_patch);

  begin
    update public.tenant_working_date_exceptions
    set
      kind = (v_business ->> 'kind')::public.tenant_working_date_exception_kind,
      start_date = (v_business ->> 'start_date')::date,
      end_date = (v_business ->> 'end_date')::date,
      title_ar = v_business ->> 'title_ar',
      title_en = v_business ->> 'title_en',
      notes = v_business ->> 'notes',
      day_mode = (v_business ->> 'day_mode')::public.tenant_working_day_mode,
      work_start = case
        when v_business ->> 'day_mode' = 'working_hours'
          then public.parse_calendar_work_time(v_business ->> 'work_start')
        else null
      end,
      work_end = case
        when v_business ->> 'day_mode' = 'working_hours'
          then public.parse_calendar_work_time(v_business ->> 'work_end')
        else null
      end,
      version = version + 1,
      updated_by = auth.uid()
    where id = p_exception_id;
  exception
    when exclusion_violation then
      raise exception 'working_date_exception_overlap';
  end;

  v_after := public.snapshot_working_date_exception_audit(p_exception_id);

  v_result := jsonb_build_object(
    'status', 'ok',
    'exception', public.build_working_date_exception_response(p_exception_id)
  );

  v_op_id := public.record_working_date_exception_operation(
    'update', p_idempotency_key, v_hash, p_exception_id, v_result
  );

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'update', 'tenant_working_date_exceptions', p_exception_id,
    v_before, v_after
  );

  return v_result;
end;
$$;

create or replace function public.cancel_working_date_exception(
  p_exception_id uuid,
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
  v_exception public.tenant_working_date_exceptions%rowtype;
  v_reason text;
  v_hash text;
  v_replay jsonb;
  v_before jsonb;
  v_after jsonb;
  v_result jsonb;
  v_op_id uuid;
begin
  -- 1. tenant + args
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_calendar_settings_edit();

  if p_exception_id is null or p_expected_version is null or p_idempotency_key is null then
    raise exception 'validation_failed';
  end if;

  v_reason := btrim(coalesce(p_reason, ''));
  if v_reason = '' or length(v_reason) > 1000 then
    raise exception 'validation_failed';
  end if;

  -- 2. idempotency lock
  perform public.acquire_finance_idempotency_lock(p_idempotency_key);

  -- 3/4. normalize + hash (operation_kind + ids/version + reason)
  v_hash := public.working_date_exception_payload_hash(
    jsonb_build_object(
      'operation_kind', 'cancel',
      'exception_id', p_exception_id,
      'expected_version', p_expected_version,
      'reason', v_reason
    )
  );

  -- 5. resolve idempotency BEFORE loading the row
  v_replay := public.resolve_working_date_exception_idempotency('cancel', p_idempotency_key, v_hash);
  if v_replay is not null then
    return v_replay;
  end if;

  -- 6. load, validate, mutate
  select * into v_exception
  from public.tenant_working_date_exceptions twde
  where twde.id = p_exception_id
    and twde.tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_exception.status is distinct from 'active'::public.tenant_working_date_exception_status then
    raise exception 'validation_failed';
  end if;

  if v_exception.version is distinct from p_expected_version then
    raise exception 'stale_version';
  end if;

  v_before := public.snapshot_working_date_exception_audit(p_exception_id);

  update public.tenant_working_date_exceptions
  set
    status = 'cancelled'::public.tenant_working_date_exception_status,
    cancel_reason = v_reason,
    cancelled_at = now(),
    cancelled_by = auth.uid(),
    version = version + 1,
    updated_by = auth.uid()
  where id = p_exception_id;

  v_after := public.snapshot_working_date_exception_audit(p_exception_id);

  v_result := jsonb_build_object(
    'status', 'ok',
    'exception', public.build_working_date_exception_response(p_exception_id)
  );

  v_op_id := public.record_working_date_exception_operation(
    'cancel', p_idempotency_key, v_hash, p_exception_id, v_result
  );

  insert into public.audit_log (
    tenant_id, actor_id, actor_account_type, action, entity_type, entity_id,
    before_json, after_json
  ) values (
    v_tenant_id, auth.uid(), public.current_account_type()::text,
    'cancel', 'tenant_working_date_exceptions', p_exception_id,
    v_before, v_after
  );

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section N: Read RPCs (get / list)
-- ---------------------------------------------------------------------------
create or replace function public.get_working_date_exception(p_exception_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_exists boolean;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_calendar_settings_view();

  if p_exception_id is null then
    raise exception 'validation_failed';
  end if;

  select exists (
    select 1
    from public.tenant_working_date_exceptions twde
    where twde.id = p_exception_id
      and twde.tenant_id = v_tenant_id
  ) into v_exists;

  if not v_exists then
    -- Keep missing and cross-tenant ids indistinguishable while preserving the
    -- calendar repository's stable validation_failed contract.
    raise exception 'validation_failed';
  end if;

  return public.build_working_date_exception_response(p_exception_id);
end;
$$;

create or replace function public.list_working_date_exceptions(
  p_filters jsonb default '{}'::jsonb,
  p_cursor text default null,
  p_limit int default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_status text;
  v_kind text;
  v_date_from date;
  v_date_to date;
  v_today date;
  v_has_from boolean;
  v_has_to boolean;
  v_limit int;
  v_filters_canonical jsonb;
  v_filters_hash text;
  v_cursor jsonb;
  v_rows jsonb;
  v_has_more boolean;
  v_next_cursor text;
  v_last record;
  v_key text;
  v_cursor_version int;
  v_cursor_tenant_id uuid;
  v_cursor_date_from date;
  v_cursor_date_to date;
  v_cursor_last_start_date date;
  v_cursor_last_end_date date;
  v_cursor_last_created_at timestamptz;
  v_cursor_last_id uuid;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_calendar_settings_view();

  if p_filters is null or jsonb_typeof(p_filters) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_filters) loop
    if v_key <> all (array['status', 'kind', 'date_from', 'date_to']) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if p_filters ? 'status' then
    if jsonb_typeof(p_filters -> 'status') <> 'string' then
      raise exception 'validation_failed';
    end if;
    v_status := p_filters ->> 'status';
    if v_status not in ('active', 'cancelled', 'all') then
      raise exception 'validation_failed';
    end if;
  else
    v_status := 'active';
  end if;

  if p_filters ? 'kind' then
    if jsonb_typeof(p_filters -> 'kind') <> 'string' then
      raise exception 'validation_failed';
    end if;
    v_kind := p_filters ->> 'kind';
    if v_kind not in ('official_holiday', 'company_closure', 'exceptional_working_day') then
      raise exception 'validation_failed';
    end if;
  else
    v_kind := null;
  end if;

  v_has_from := coalesce(p_filters ? 'date_from', false);
  v_has_to := coalesce(p_filters ? 'date_to', false);
  if v_has_from is distinct from v_has_to then
    raise exception 'validation_failed';
  end if;

  if not v_has_from then
    v_today := public.tenant_local_today(v_tenant_id);
    if v_today is null then
      raise exception 'validation_failed';
    end if;
    v_date_from := v_today - 30;
    v_date_to := v_today + 366;
  else
    if jsonb_typeof(p_filters -> 'date_from') <> 'string'
      or jsonb_typeof(p_filters -> 'date_to') <> 'string' then
      raise exception 'validation_failed';
    end if;
    begin
      v_date_from := (p_filters ->> 'date_from')::date;
      v_date_to := (p_filters ->> 'date_to')::date;
    exception
      when others then
        raise exception 'validation_failed';
    end;
    if (p_filters ->> 'date_from') !~ '^\d{4}-\d{2}-\d{2}$'
      or (p_filters ->> 'date_to') !~ '^\d{4}-\d{2}-\d{2}$'
      or to_char(v_date_from, 'YYYY-MM-DD') is distinct from (p_filters ->> 'date_from')
      or to_char(v_date_to, 'YYYY-MM-DD') is distinct from (p_filters ->> 'date_to')
      or v_date_from is null
      or v_date_to is null
      or v_date_to < v_date_from then
      raise exception 'validation_failed';
    end if;
    if (v_date_to - v_date_from) > 1095 then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_limit is not null and (p_limit < 1 or p_limit > 100) then
    raise exception 'validation_failed';
  end if;
  v_limit := coalesce(p_limit, 50);

  v_filters_canonical := jsonb_strip_nulls(jsonb_build_object(
    'status', v_status,
    'kind', v_kind,
    'date_from', v_date_from,
    'date_to', v_date_to
  ));
  v_filters_hash := public.working_date_exception_payload_hash(v_filters_canonical);

  if p_cursor is not null then
    begin
      v_cursor := convert_from(decode(p_cursor, 'base64'), 'UTF8')::jsonb;
      if v_cursor is null or jsonb_typeof(v_cursor) <> 'object' then
        raise exception 'validation_failed';
      end if;
      v_cursor_version := (v_cursor ->> 'version')::int;
      v_cursor_tenant_id := (v_cursor ->> 'tenant_id')::uuid;
      v_cursor_date_from := (v_cursor ->> 'date_from')::date;
      v_cursor_date_to := (v_cursor ->> 'date_to')::date;
      if v_cursor -> 'last' is null
        or jsonb_typeof(v_cursor -> 'last') <> 'object' then
        raise exception 'validation_failed';
      end if;
      v_cursor_last_start_date := (v_cursor -> 'last' ->> 'start_date')::date;
      v_cursor_last_end_date := (v_cursor -> 'last' ->> 'end_date')::date;
      v_cursor_last_created_at := (v_cursor -> 'last' ->> 'created_at')::timestamptz;
      v_cursor_last_id := (v_cursor -> 'last' ->> 'id')::uuid;
      if v_cursor_version is null
        or v_cursor_tenant_id is null
        or v_cursor_date_from is null
        or v_cursor_date_to is null
        or v_cursor_last_start_date is null
        or v_cursor_last_end_date is null
        or v_cursor_last_created_at is null
        or v_cursor_last_id is null then
        raise exception 'validation_failed';
      end if;
    exception
      when others then
        raise exception 'validation_failed';
    end;

    if coalesce(v_cursor_version, 0) <> 1 then
      raise exception 'validation_failed';
    end if;
    if v_cursor_tenant_id is distinct from v_tenant_id then
      raise exception 'validation_failed';
    end if;
    if v_cursor ->> 'status' is distinct from v_status then
      raise exception 'validation_failed';
    end if;
    if v_cursor ->> 'kind' is distinct from v_kind then
      raise exception 'validation_failed';
    end if;
    if v_cursor_date_from is distinct from v_date_from then
      raise exception 'validation_failed';
    end if;
    if v_cursor_date_to is distinct from v_date_to then
      raise exception 'validation_failed';
    end if;
    if v_cursor ->> 'filters_hash' is distinct from v_filters_hash then
      raise exception 'validation_failed';
    end if;
  end if;

  with candidates as (
    select
      twde.id,
      twde.start_date,
      twde.end_date,
      twde.created_at,
      public.build_working_date_exception_response(twde.id) as row_json
    from public.tenant_working_date_exceptions twde
    where twde.tenant_id = v_tenant_id
      and (v_status = 'all' or twde.status::text = v_status)
      and (v_kind is null or twde.kind::text = v_kind)
      and daterange(twde.start_date, twde.end_date, '[]')
        && daterange(v_date_from, v_date_to, '[]')
      and (
        v_cursor is null
        or (
          twde.start_date,
          twde.end_date,
          twde.created_at,
          twde.id
        ) > (
          v_cursor_last_start_date,
          v_cursor_last_end_date,
          v_cursor_last_created_at,
          v_cursor_last_id
        )
      )
    order by twde.start_date asc, twde.end_date asc, twde.created_at asc, twde.id asc
    limit v_limit + 1
  )
  select
    coalesce(
      (
        select jsonb_agg(c.row_json order by c.start_date, c.end_date, c.created_at, c.id)
        from (select * from candidates limit v_limit) c
      ),
      '[]'::jsonb
    ),
    (select count(*) > v_limit from candidates)
  into v_rows, v_has_more;

  if v_has_more then
    select c.start_date, c.end_date, c.created_at, c.id
    into v_last
    from (
      select *
      from (
        select
          twde.id,
          twde.start_date,
          twde.end_date,
          twde.created_at
        from public.tenant_working_date_exceptions twde
        where twde.tenant_id = v_tenant_id
          and (v_status = 'all' or twde.status::text = v_status)
          and (v_kind is null or twde.kind::text = v_kind)
          and daterange(twde.start_date, twde.end_date, '[]')
            && daterange(v_date_from, v_date_to, '[]')
          and (
            v_cursor is null
            or (
              twde.start_date,
              twde.end_date,
              twde.created_at,
              twde.id
            ) > (
              v_cursor_last_start_date,
              v_cursor_last_end_date,
              v_cursor_last_created_at,
              v_cursor_last_id
            )
          )
        order by twde.start_date asc, twde.end_date asc, twde.created_at asc, twde.id asc
        limit v_limit
      ) page
      order by page.start_date desc, page.end_date desc, page.created_at desc, page.id desc
      limit 1
    ) c;

    v_next_cursor := encode(
      convert_to(
        jsonb_build_object(
          'version', 1,
          'tenant_id', v_tenant_id,
          'status', v_status,
          'kind', v_kind,
          'date_from', v_date_from,
          'date_to', v_date_to,
          'filters_hash', v_filters_hash,
          'last', jsonb_build_object(
            'start_date', v_last.start_date,
            'end_date', v_last.end_date,
            'created_at', v_last.created_at,
            'id', v_last.id
          )
        )::text,
        'UTF8'
      ),
      'base64'
    );
  end if;

  return jsonb_build_object(
    'items', v_rows,
    'has_more', coalesce(v_has_more, false),
    'next_cursor', v_next_cursor,
    'filters_applied', jsonb_build_object(
      'status', v_status,
      'kind', v_kind,
      'date_from', v_date_from,
      'date_to', v_date_to,
      'limit', v_limit
    ),
    'filters_hash', v_filters_hash
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section O: Grants / revokes
-- ---------------------------------------------------------------------------
revoke all on function public.snapshot_working_date_exception_audit(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.safe_date_exception_json(public.tenant_working_date_exceptions)
  from public, anon, authenticated, service_role;
revoke all on function public.working_date_exception_payload_hash(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.resolve_working_date_exception_idempotency(text, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.record_working_date_exception_operation(text, uuid, text, uuid, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.validate_working_date_exception_business_payload(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.normalize_working_date_exception_create_payload(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.normalize_working_date_exception_update_patch(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.merge_working_date_exception_update_business(
  public.tenant_working_date_exceptions, jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.load_active_working_date_exception(uuid, date)
  from public, anon, authenticated, service_role;
revoke all on function public.build_working_date_exception_response(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.trg_bump_reminder_reconcile_working_date_exception()
  from public, anon, authenticated, service_role;

-- Defensive re-assertion: both CREATE OR REPLACE'd functions must remain
-- unreachable by client roles even though grants are independent of the
-- function body and are not reset by CREATE OR REPLACE.
revoke all on function public.resolve_tenant_working_window(uuid, date)
  from public, anon, authenticated, service_role;
revoke all on function public.detect_manual_calendar_schedule_warnings(
  uuid, date, timestamptz, timestamptz
) from public, anon, authenticated, service_role;

revoke all on function public.list_working_date_exceptions(jsonb, text, int)
  from public, anon, authenticated, service_role;
revoke all on function public.get_working_date_exception(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.create_working_date_exception(jsonb, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.update_working_date_exception(uuid, int, jsonb, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.cancel_working_date_exception(uuid, int, text, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.list_working_date_exceptions(jsonb, text, int) to authenticated;
grant execute on function public.get_working_date_exception(uuid) to authenticated;
grant execute on function public.create_working_date_exception(jsonb, uuid) to authenticated;
grant execute on function public.update_working_date_exception(uuid, int, jsonb, uuid) to authenticated;
grant execute on function public.cancel_working_date_exception(uuid, int, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Section P: Postflight
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'excl_tenant_working_date_exceptions_active_range'
  ) then
    raise exception 'm7b_postflight_failed: missing_exclusion_constraint';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'ux_working_date_exception_operations_idem'
  ) then
    raise exception 'm7b_postflight_failed: missing_operations_idem_unique';
  end if;

  if not (
    select relrowsecurity from pg_class
    where oid = 'public.tenant_working_date_exceptions'::regclass
  ) then
    raise exception 'm7b_postflight_failed: rls_not_enabled_exceptions';
  end if;

  if not (
    select relrowsecurity from pg_class
    where oid = 'public.working_date_exception_operations'::regclass
  ) then
    raise exception 'm7b_postflight_failed: rls_not_enabled_operations';
  end if;

  if has_table_privilege('authenticated', 'public.tenant_working_date_exceptions', 'SELECT')
    or has_table_privilege('anon', 'public.tenant_working_date_exceptions', 'SELECT')
    or has_table_privilege('service_role', 'public.tenant_working_date_exceptions', 'SELECT') then
    raise exception 'm7b_postflight_failed: exceptions_table_grant_leak';
  end if;

  if has_table_privilege('authenticated', 'public.working_date_exception_operations', 'SELECT')
    or has_table_privilege('anon', 'public.working_date_exception_operations', 'SELECT')
    or has_table_privilege('service_role', 'public.working_date_exception_operations', 'SELECT') then
    raise exception 'm7b_postflight_failed: operations_table_grant_leak';
  end if;

  if not has_function_privilege(
    'authenticated', 'public.list_working_date_exceptions(jsonb, text, int)', 'EXECUTE'
  ) then
    raise exception 'm7b_postflight_failed: list_rpc_not_granted';
  end if;

  if not has_function_privilege(
    'authenticated', 'public.get_working_date_exception(uuid)', 'EXECUTE'
  ) then
    raise exception 'm7b_postflight_failed: get_rpc_not_granted';
  end if;

  if not has_function_privilege(
    'authenticated', 'public.create_working_date_exception(jsonb, uuid)', 'EXECUTE'
  ) then
    raise exception 'm7b_postflight_failed: create_rpc_not_granted';
  end if;

  if not has_function_privilege(
    'authenticated', 'public.update_working_date_exception(uuid, int, jsonb, uuid)', 'EXECUTE'
  ) then
    raise exception 'm7b_postflight_failed: update_rpc_not_granted';
  end if;

  if not has_function_privilege(
    'authenticated', 'public.cancel_working_date_exception(uuid, int, text, uuid)', 'EXECUTE'
  ) then
    raise exception 'm7b_postflight_failed: cancel_rpc_not_granted';
  end if;

  if has_function_privilege(
      'anon', 'public.list_working_date_exceptions(jsonb, text, int)', 'EXECUTE'
    )
    or has_function_privilege(
      'anon', 'public.get_working_date_exception(uuid)', 'EXECUTE'
    )
    or has_function_privilege(
      'anon', 'public.create_working_date_exception(jsonb, uuid)', 'EXECUTE'
    )
    or has_function_privilege(
      'anon', 'public.update_working_date_exception(uuid, int, jsonb, uuid)', 'EXECUTE'
    )
    or has_function_privilege(
      'anon', 'public.cancel_working_date_exception(uuid, int, text, uuid)', 'EXECUTE'
    ) then
    raise exception 'm7b_postflight_failed: anon_rpc_execute_leak';
  end if;

  if has_function_privilege(
    'authenticated', 'public.resolve_tenant_working_window(uuid, date)', 'EXECUTE'
  ) then
    raise exception 'm7b_postflight_failed: resolve_working_window_leak';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.detect_manual_calendar_schedule_warnings(uuid, date, timestamptz, timestamptz)',
    'EXECUTE'
  ) then
    raise exception 'm7b_postflight_failed: detect_schedule_warnings_leak';
  end if;

  if has_function_privilege(
    'authenticated', 'public.load_active_working_date_exception(uuid, date)', 'EXECUTE'
  ) then
    raise exception 'm7b_postflight_failed: load_active_exception_leak';
  end if;
end $$;
