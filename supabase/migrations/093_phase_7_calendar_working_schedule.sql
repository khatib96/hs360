-- Phase 7 M1: tenant calendar settings, working days, permissions, and RPCs.

-- ---------------------------------------------------------------------------
-- Section A: enum
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'tenant_working_day_mode') then
    create type public.tenant_working_day_mode as enum (
      'day_off',
      'working_hours',
      '24_hours'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section B: tables
-- ---------------------------------------------------------------------------
create table if not exists public.tenant_calendar_settings (
  tenant_id uuid primary key references public.tenants (id) on delete cascade,
  timezone_name text,
  working_schedule_configured boolean not null default false,
  remind_event_workday_start boolean not null default true,
  remind_previous_workday_start boolean not null default true,
  configured_at timestamptz,
  configured_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table if not exists public.tenant_working_days (
  tenant_id uuid not null references public.tenant_calendar_settings (tenant_id) on delete cascade,
  iso_weekday smallint not null,
  day_mode public.tenant_working_day_mode,
  work_start time,
  work_end time,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  primary key (tenant_id, iso_weekday),
  constraint chk_tenant_working_days_iso_weekday
    check (iso_weekday between 1 and 7),
  constraint chk_tenant_working_days_mode_window
    check (
      (day_mode is null and work_start is null and work_end is null)
      or (
        day_mode = 'day_off'::public.tenant_working_day_mode
        and work_start is null
        and work_end is null
      )
      or (
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
);

create index if not exists idx_tenant_working_days_tenant
  on public.tenant_working_days (tenant_id);

comment on table public.tenant_calendar_settings is
  'Per-tenant calendar timezone and working-schedule configuration. '
  'Timezone is confirmed only after manager saves all seven weekdays atomically.';
comment on column public.tenant_calendar_settings.timezone_name is
  'Manager-selected IANA timezone. Null until confirmed via update_calendar_settings.';
comment on column public.tenant_calendar_settings.working_schedule_configured is
  'Server-owned flag set true only after atomic save of timezone and all seven weekdays.';

-- ---------------------------------------------------------------------------
-- Section C: provisioning
-- ---------------------------------------------------------------------------
create or replace function public.initialize_tenant_calendar_settings()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tenant_calendar_settings (tenant_id)
  values (new.id)
  on conflict (tenant_id) do nothing;

  insert into public.tenant_working_days (tenant_id, iso_weekday)
  select new.id, v.iso_weekday
  from generate_series(1, 7) as v(iso_weekday)
  on conflict (tenant_id, iso_weekday) do nothing;

  return new;
end;
$$;

revoke all on function public.initialize_tenant_calendar_settings()
  from public, anon, authenticated;

drop trigger if exists trg_initialize_tenant_calendar_settings on public.tenants;
create trigger trg_initialize_tenant_calendar_settings
  after insert on public.tenants
  for each row execute function public.initialize_tenant_calendar_settings();

insert into public.tenant_calendar_settings (tenant_id)
select t.id
from public.tenants t
on conflict (tenant_id) do nothing;

insert into public.tenant_working_days (tenant_id, iso_weekday)
select t.id, v.iso_weekday
from public.tenants t
cross join generate_series(1, 7) as v(iso_weekday)
on conflict (tenant_id, iso_weekday) do nothing;

-- ---------------------------------------------------------------------------
-- Section D: permissions catalog
-- ---------------------------------------------------------------------------
insert into public.permissions (
  id,
  module,
  action,
  scope,
  field_name,
  label_ar,
  label_en,
  is_sensitive,
  category,
  sort_order
)
values
  (
    'settings.calendar.view',
    'settings',
    'view',
    'action',
    null,
    'عرض إعدادات التقويم',
    'View calendar settings',
    false,
    'settings',
    181
  ),
  (
    'settings.calendar.edit',
    'settings',
    'edit',
    'action',
    null,
    'تعديل إعدادات التقويم',
    'Edit calendar settings',
    true,
    'settings',
    182
  )
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Section E: permission helpers
-- ---------------------------------------------------------------------------
create or replace function public.assert_calendar_settings_view()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.is_manager() then
    return;
  end if;
  if not (
    public.user_has_permission('settings.calendar.view')
    or public.user_has_permission('settings.calendar.edit')
  ) then
    raise exception 'permission_denied';
  end if;
end;
$$;

create or replace function public.assert_calendar_settings_edit()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.is_manager() then
    return;
  end if;
  if not public.user_has_permission('settings.calendar.edit') then
    raise exception 'permission_denied';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section F: validation helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_valid_iana_timezone(p_timezone_name text)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from pg_timezone_names
    where name = p_timezone_name
  );
$$;

revoke all on function public.is_valid_iana_timezone(text)
  from public, anon, authenticated;

create or replace function public.parse_calendar_work_time(p_value text)
returns time
language plpgsql
immutable
set search_path = public
as $$
declare
  v_trimmed text;
  v_hour int;
  v_minute int;
begin
  v_trimmed := btrim(coalesce(p_value, ''));
  if v_trimmed = '' or v_trimmed !~ '^\d{2}:\d{2}$' then
    raise exception 'validation_failed';
  end if;

  v_hour := substring(v_trimmed from 1 for 2)::int;
  v_minute := substring(v_trimmed from 4 for 2)::int;

  if v_hour < 0 or v_hour > 23 or v_minute < 0 or v_minute > 59 then
    raise exception 'validation_failed';
  end if;

  return make_time(v_hour, v_minute, 0);
exception
  when others then
    raise exception 'validation_failed';
end;
$$;

revoke all on function public.parse_calendar_work_time(text)
  from public, anon, authenticated;

create or replace function public.validate_calendar_working_day_payload(p_day jsonb)
returns void
language plpgsql
immutable
set search_path = public
as $$
declare
  v_iso_weekday int;
  v_mode text;
  v_start time;
  v_end time;
begin
  if jsonb_typeof(p_day) <> 'object' then
    raise exception 'validation_failed';
  end if;

  if not (p_day ? 'iso_weekday') then
    raise exception 'validation_failed';
  end if;

  v_iso_weekday := (p_day ->> 'iso_weekday')::int;
  if v_iso_weekday is null or v_iso_weekday < 1 or v_iso_weekday > 7 then
    raise exception 'validation_failed';
  end if;

  if not (p_day ? 'day_mode') or p_day ->> 'day_mode' is null then
    raise exception 'validation_failed';
  end if;

  v_mode := p_day ->> 'day_mode';
  if v_mode not in ('day_off', 'working_hours', '24_hours') then
    raise exception 'validation_failed';
  end if;

  if v_mode = 'working_hours' then
    v_start := public.parse_calendar_work_time(p_day ->> 'work_start');
    v_end := public.parse_calendar_work_time(p_day ->> 'work_end');
    if v_start >= v_end then
      raise exception 'validation_failed';
    end if;
  elsif v_mode in ('day_off', '24_hours') then
    if nullif(btrim(coalesce(p_day ->> 'work_start', '')), '') is not null
      or nullif(btrim(coalesce(p_day ->> 'work_end', '')), '') is not null then
      raise exception 'validation_failed';
    end if;
  end if;
end;
$$;

revoke all on function public.validate_calendar_working_day_payload(jsonb)
  from public, anon, authenticated;

create or replace function public.build_calendar_settings_json(p_tenant_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_settings public.tenant_calendar_settings%rowtype;
  v_legacy text;
  v_days jsonb;
  v_can_edit boolean;
begin
  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = p_tenant_id;

  if not found then
    raise exception 'tenant_not_found';
  end if;

  select t.timezone into v_legacy
  from public.tenants t
  where t.id = p_tenant_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'iso_weekday', d.iso_weekday,
        'day_mode', d.day_mode,
        'work_start', to_char(d.work_start, 'HH24:MI'),
        'work_end', to_char(d.work_end, 'HH24:MI')
      )
      order by d.iso_weekday
    ),
    '[]'::jsonb
  )
  into v_days
  from public.tenant_working_days d
  where d.tenant_id = p_tenant_id;

  v_can_edit := public.is_manager()
    or public.user_has_permission('settings.calendar.edit');

  return jsonb_build_object(
    'timezone_name', v_settings.timezone_name,
    'timezone_confirmed', v_settings.working_schedule_configured
      and v_settings.timezone_name is not null,
    'legacy_timezone_suggestion', v_legacy,
    'working_schedule_configured', v_settings.working_schedule_configured,
    'remind_event_workday_start', v_settings.remind_event_workday_start,
    'remind_previous_workday_start', v_settings.remind_previous_workday_start,
    'configured_at', v_settings.configured_at,
    'configured_by', v_settings.configured_by,
    'updated_at', v_settings.updated_at,
    'updated_by', v_settings.updated_by,
    'days', v_days,
    'can_edit', v_can_edit
  );
end;
$$;

revoke all on function public.build_calendar_settings_json(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Section G: configured-state invariant (deferred)
-- ---------------------------------------------------------------------------
create or replace function public.enforce_tenant_working_schedule_configured_state()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_settings public.tenant_calendar_settings%rowtype;
  v_day_count int;
  v_null_mode_count int;
begin
  v_tenant_id := coalesce(new.tenant_id, old.tenant_id);

  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = v_tenant_id;

  if not found or not v_settings.working_schedule_configured then
    return coalesce(new, old);
  end if;

  if v_settings.timezone_name is null
    or not public.is_valid_iana_timezone(v_settings.timezone_name) then
    raise exception 'validation_failed';
  end if;

  select count(*)::int, count(*) filter (where day_mode is null)::int
  into v_day_count, v_null_mode_count
  from public.tenant_working_days
  where tenant_id = v_tenant_id;

  if v_day_count <> 7 or v_null_mode_count > 0 then
    raise exception 'validation_failed';
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.enforce_tenant_working_schedule_configured_state()
  from public, anon, authenticated;

drop trigger if exists trg_tenant_calendar_settings_configured_state
  on public.tenant_calendar_settings;
create constraint trigger trg_tenant_calendar_settings_configured_state
  after insert or update on public.tenant_calendar_settings
  deferrable initially deferred
  for each row
  execute function public.enforce_tenant_working_schedule_configured_state();

drop trigger if exists trg_tenant_working_days_configured_state
  on public.tenant_working_days;
create constraint trigger trg_tenant_working_days_configured_state
  after insert or update on public.tenant_working_days
  deferrable initially deferred
  for each row
  execute function public.enforce_tenant_working_schedule_configured_state();

create or replace function public.enforce_tenant_working_day_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.tenant_calendar_settings%rowtype;
begin
  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = old.tenant_id;

  if not found then
    return old;
  end if;

  if v_settings.working_schedule_configured then
    raise exception 'validation_failed';
  end if;

  return old;
end;
$$;

revoke all on function public.enforce_tenant_working_day_delete()
  from public, anon, authenticated;

drop trigger if exists trg_tenant_working_days_delete_guard
  on public.tenant_working_days;
create trigger trg_tenant_working_days_delete_guard
  before delete on public.tenant_working_days
  for each row
  execute function public.enforce_tenant_working_day_delete();

-- ---------------------------------------------------------------------------
-- Section H: RPCs
-- ---------------------------------------------------------------------------
create or replace function public.get_calendar_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_calendar_settings_view();
  return public.build_calendar_settings_json(v_tenant_id);
end;
$$;

create or replace function public.update_calendar_settings(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_user_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_was_configured boolean;
  v_timezone text;
  v_days jsonb;
  v_day jsonb;
  v_iso int;
  v_seen int[] := '{}';
  v_mode public.tenant_working_day_mode;
  v_start time;
  v_end time;
  v_key text;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  v_user_id := auth.uid();
  perform public.assert_calendar_settings_edit();

  if jsonb_typeof(p_data) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_data) loop
    if v_key not in (
      'timezone_name',
      'remind_event_workday_start',
      'remind_previous_workday_start',
      'days'
    ) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if not (p_data ? 'timezone_name') or not (p_data ? 'days') then
    raise exception 'validation_failed';
  end if;

  v_timezone := nullif(btrim(p_data ->> 'timezone_name'), '');
  if v_timezone is null or not public.is_valid_iana_timezone(v_timezone) then
    raise exception 'validation_failed';
  end if;

  v_days := p_data -> 'days';
  if jsonb_typeof(v_days) <> 'array' or jsonb_array_length(v_days) <> 7 then
    raise exception 'validation_failed';
  end if;

  for v_day in select value from jsonb_array_elements(v_days) loop
    perform public.validate_calendar_working_day_payload(v_day);
    v_iso := (v_day ->> 'iso_weekday')::int;
    if v_iso = any (v_seen) then
      raise exception 'validation_failed';
    end if;
    v_seen := array_append(v_seen, v_iso);
  end loop;

  if array_length(v_seen, 1) is distinct from 7 then
    raise exception 'validation_failed';
  end if;

  v_before := public.build_calendar_settings_json(v_tenant_id);

  select working_schedule_configured
  into v_was_configured
  from public.tenant_calendar_settings
  where tenant_id = v_tenant_id
  for update;

  if not found then
    raise exception 'tenant_not_found';
  end if;

  update public.tenant_calendar_settings
  set
    timezone_name = v_timezone,
    remind_event_workday_start = case
      when p_data ? 'remind_event_workday_start'
        then (p_data ->> 'remind_event_workday_start')::boolean
      else remind_event_workday_start
    end,
    remind_previous_workday_start = case
      when p_data ? 'remind_previous_workday_start'
        then (p_data ->> 'remind_previous_workday_start')::boolean
      else remind_previous_workday_start
    end,
    working_schedule_configured = true,
    configured_at = case
      when not v_was_configured then now()
      else configured_at
    end,
    configured_by = case
      when not v_was_configured then v_user_id
      else configured_by
    end,
    updated_at = now(),
    updated_by = v_user_id
  where tenant_id = v_tenant_id;

  for v_day in select value from jsonb_array_elements(v_days) loop
    v_iso := (v_day ->> 'iso_weekday')::int;
    v_mode := (v_day ->> 'day_mode')::public.tenant_working_day_mode;
    if v_mode = 'working_hours'::public.tenant_working_day_mode then
      v_start := public.parse_calendar_work_time(v_day ->> 'work_start');
      v_end := public.parse_calendar_work_time(v_day ->> 'work_end');
    else
      v_start := null;
      v_end := null;
    end if;

    update public.tenant_working_days
    set
      day_mode = v_mode,
      work_start = v_start,
      work_end = v_end,
      updated_at = now(),
      updated_by = v_user_id
    where tenant_id = v_tenant_id
      and iso_weekday = v_iso;
  end loop;

  v_after := public.build_calendar_settings_json(v_tenant_id);

  insert into public.audit_log (
    tenant_id,
    actor_id,
    actor_account_type,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  values (
    v_tenant_id,
    v_user_id,
    public.current_account_type()::text,
    'UPDATE',
    'tenant_calendar_settings',
    v_tenant_id,
    v_before,
    v_after
  );

  return v_after;
end;
$$;

create or replace function public.list_calendar_timezones(p_search text default null)
returns table (timezone_name text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_search text;
begin
  perform public.assert_calendar_settings_view();

  v_search := nullif(btrim(p_search), '');
  if v_search is not null and length(v_search) > 64 then
    raise exception 'validation_failed';
  end if;

  return query
  select tz.name
  from pg_timezone_names tz
  where v_search is null
    or tz.name ilike '%' || replace(replace(v_search, '%', '\%'), '_', '\_') || '%' escape '\'
  order by tz.name
  limit 200;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section I: internal working-window resolver
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

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'date', p_date,
    'iso_weekday', v_iso,
    'schedule_configured', v_settings.working_schedule_configured,
    'timezone_name', v_settings.timezone_name,
    'day_mode', v_day.day_mode,
    'work_start', to_char(v_day.work_start, 'HH24:MI'),
    'work_end', to_char(v_day.work_end, 'HH24:MI'),
    'is_unreviewed', v_day.day_mode is null,
    'is_day_off', v_day.day_mode = 'day_off'::public.tenant_working_day_mode,
    'is_24_hours', v_day.day_mode = '24_hours'::public.tenant_working_day_mode,
    'is_working_hours', v_day.day_mode = 'working_hours'::public.tenant_working_day_mode
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section J: RLS + ACL
-- ---------------------------------------------------------------------------
alter table public.tenant_calendar_settings enable row level security;
alter table public.tenant_working_days enable row level security;

revoke insert, update, delete on public.tenant_calendar_settings
  from public, anon, authenticated;
revoke insert, update, delete on public.tenant_working_days
  from public, anon, authenticated;

grant select on public.tenant_calendar_settings to authenticated;
grant select on public.tenant_working_days to authenticated;

drop policy if exists tenant_calendar_settings_select on public.tenant_calendar_settings;
create policy tenant_calendar_settings_select on public.tenant_calendar_settings
  for select to authenticated
  using (
    tenant_id = public.current_tenant_id()
    and (
      public.is_manager()
      or public.user_has_permission('settings.calendar.view')
      or public.user_has_permission('settings.calendar.edit')
    )
  );

drop policy if exists tenant_working_days_select on public.tenant_working_days;
create policy tenant_working_days_select on public.tenant_working_days
  for select to authenticated
  using (
    tenant_id = public.current_tenant_id()
    and (
      public.is_manager()
      or public.user_has_permission('settings.calendar.view')
      or public.user_has_permission('settings.calendar.edit')
    )
  );

drop trigger if exists trg_touch_tenant_calendar_settings on public.tenant_calendar_settings;
create trigger trg_touch_tenant_calendar_settings
  before update on public.tenant_calendar_settings
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_touch_tenant_working_days on public.tenant_working_days;
create trigger trg_touch_tenant_working_days
  before update on public.tenant_working_days
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Section K: grants
-- ---------------------------------------------------------------------------
revoke all on function public.assert_calendar_settings_view() from public, anon, authenticated;
revoke all on function public.assert_calendar_settings_edit() from public, anon, authenticated;
revoke all on function public.get_calendar_settings() from public, anon, authenticated;
revoke all on function public.update_calendar_settings(jsonb) from public, anon, authenticated;
revoke all on function public.list_calendar_timezones(text) from public, anon, authenticated;
revoke all on function public.resolve_tenant_working_window(uuid, date)
  from public, anon, authenticated;

grant execute on function public.get_calendar_settings() to authenticated;
grant execute on function public.update_calendar_settings(jsonb) to authenticated;
grant execute on function public.list_calendar_timezones(text) to authenticated;
