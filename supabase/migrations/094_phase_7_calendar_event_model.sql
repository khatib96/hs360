-- Phase 7 M1: calendar event provenance hardening and refill execution-fact handoff.

-- ---------------------------------------------------------------------------
-- Section A: composite FK targets
-- ---------------------------------------------------------------------------
create unique index if not exists ux_calendar_events_tenant_id
  on public.calendar_events (tenant_id, id);

create unique index if not exists ux_visits_tenant_id
  on public.visits (tenant_id, id);

-- ---------------------------------------------------------------------------
-- Section B: calendar_events extensions
-- ---------------------------------------------------------------------------
alter table public.calendar_events
  add column if not exists original_due_date date,
  add column if not exists reschedule_reason text,
  add column if not exists rescheduled_at timestamptz,
  add column if not exists rescheduled_by uuid references auth.users (id),
  add column if not exists day_off_override_reason text,
  add column if not exists day_off_override_at timestamptz,
  add column if not exists day_off_override_by uuid references auth.users (id),
  add column if not exists schedule_version int not null default 1;

update public.calendar_events
set original_due_date = scheduled_date
where original_due_date is null;

alter table public.calendar_events
  alter column original_due_date set not null;

comment on column public.calendar_events.original_due_date is
  'Phase 7: immutable contractual due provenance; set from scheduled_date on insert.';
comment on column public.calendar_events.schedule_version is
  'Phase 7 M8: optimistic concurrency for assignment/reschedule RPCs.';

create or replace function public.enforce_calendar_event_original_due_date_insert()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.original_due_date := new.scheduled_date;
  return new;
end;
$$;

create or replace function public.enforce_calendar_event_original_due_date_immutable()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.original_due_date is distinct from old.original_due_date then
    raise exception 'validation_failed';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_calendar_event_original_due_date_insert()
  from public, anon, authenticated;
revoke all on function public.enforce_calendar_event_original_due_date_immutable()
  from public, anon, authenticated;

drop trigger if exists trg_calendar_events_original_due_date_insert on public.calendar_events;
create trigger trg_calendar_events_original_due_date_insert
  before insert on public.calendar_events
  for each row execute function public.enforce_calendar_event_original_due_date_insert();

drop trigger if exists trg_calendar_events_original_due_date_immutable on public.calendar_events;
create trigger trg_calendar_events_original_due_date_immutable
  before update on public.calendar_events
  for each row execute function public.enforce_calendar_event_original_due_date_immutable();

-- ---------------------------------------------------------------------------
-- Section C: refill execution facts
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_refill_execution_facts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  calendar_event_id uuid not null,
  visit_id uuid not null,
  contract_id uuid not null,
  contract_line_id uuid not null,
  product_id uuid not null,
  original_due_date date not null,
  actual_completion_date date not null,
  actual_quantity_delivered numeric(15, 3) not null,
  quantity_unit public.unit_of_measure not null,
  contracted_quantity_per_cycle numeric(15, 3) not null,
  coverage_months int,
  coverage_days int,
  calculated_next_due_date date not null,
  confirmed_next_due_date date not null,
  next_due_overridden boolean not null default false,
  next_due_override_reason text,
  next_due_overridden_by uuid references auth.users (id),
  next_due_overridden_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id),
  updated_at timestamptz,
  updated_by uuid references auth.users (id),
  constraint ux_calendar_refill_execution_facts_event unique (calendar_event_id),
  constraint chk_calendar_refill_execution_facts_quantities_positive check (
    actual_quantity_delivered > 0
    and contracted_quantity_per_cycle > 0
  ),
  constraint chk_calendar_refill_execution_facts_coverage_xor check (
    (coverage_months is not null and coverage_days is null)
    or (coverage_months is null and coverage_days is not null)
  ),
  constraint chk_calendar_refill_execution_facts_coverage_positive check (
    coalesce(coverage_months, 0) > 0
    or coalesce(coverage_days, 0) > 0
  ),
  constraint chk_calendar_refill_execution_facts_override_false check (
    next_due_overridden
    or (
      next_due_override_reason is null
      and next_due_overridden_by is null
      and next_due_overridden_at is null
      and confirmed_next_due_date = calculated_next_due_date
    )
  ),
  constraint chk_calendar_refill_execution_facts_override_true check (
    not next_due_overridden
    or (
      next_due_override_reason is not null
      and btrim(next_due_override_reason) <> ''
      and next_due_overridden_by is not null
      and next_due_overridden_at is not null
    )
  )
);

create index if not exists idx_calendar_refill_execution_facts_tenant
  on public.calendar_refill_execution_facts (tenant_id);

alter table public.calendar_refill_execution_facts
  drop constraint if exists fk_calendar_refill_execution_facts_event;

alter table public.calendar_refill_execution_facts
  add constraint fk_calendar_refill_execution_facts_event
  foreign key (tenant_id, calendar_event_id)
  references public.calendar_events (tenant_id, id);

alter table public.calendar_refill_execution_facts
  drop constraint if exists fk_calendar_refill_execution_facts_contract;

alter table public.calendar_refill_execution_facts
  add constraint fk_calendar_refill_execution_facts_contract
  foreign key (tenant_id, contract_id)
  references public.contracts (tenant_id, id);

alter table public.calendar_refill_execution_facts
  drop constraint if exists fk_calendar_refill_execution_facts_contract_line;

alter table public.calendar_refill_execution_facts
  add constraint fk_calendar_refill_execution_facts_contract_line
  foreign key (tenant_id, contract_id, contract_line_id)
  references public.contract_lines (tenant_id, contract_id, id);

alter table public.calendar_refill_execution_facts
  drop constraint if exists fk_calendar_refill_execution_facts_product;

alter table public.calendar_refill_execution_facts
  add constraint fk_calendar_refill_execution_facts_product
  foreign key (tenant_id, product_id)
  references public.products (tenant_id, id);

alter table public.calendar_refill_execution_facts
  drop constraint if exists fk_calendar_refill_execution_facts_visit;

alter table public.calendar_refill_execution_facts
  add constraint fk_calendar_refill_execution_facts_visit
  foreign key (tenant_id, visit_id)
  references public.visits (tenant_id, id);

comment on table public.calendar_refill_execution_facts is
  'Phase 7 M1 / Phase 8 handoff: trusted refill execution and coverage facts. '
  'No API role access in M1; Phase 8 writes via trusted RPC only.';

-- ---------------------------------------------------------------------------
-- Section D: integrity trigger (deferred)
-- ---------------------------------------------------------------------------
create or replace function public.enforce_calendar_refill_execution_fact_integrity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fact public.calendar_refill_execution_facts%rowtype;
  v_event public.calendar_events%rowtype;
  v_visit public.visits%rowtype;
  v_line public.contract_lines%rowtype;
  v_product public.products%rowtype;
  v_settings public.tenant_calendar_settings%rowtype;
  v_oil_change_id uuid;
  v_oil_product_id uuid;
  v_expected_qty numeric(15, 3);
  v_completion_date date;
begin
  v_fact := new;

  select * into v_settings
  from public.tenant_calendar_settings
  where tenant_id = v_fact.tenant_id;

  if not found
    or not v_settings.working_schedule_configured
    or v_settings.timezone_name is null
    or not public.is_valid_iana_timezone(v_settings.timezone_name) then
    raise exception 'validation_failed';
  end if;

  select * into v_event
  from public.calendar_events
  where id = v_fact.calendar_event_id
    and tenant_id = v_fact.tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_event.type <> 'refill_due'::public.calendar_event_type then
    raise exception 'validation_failed';
  end if;

  if v_event.contract_id is distinct from v_fact.contract_id
    or v_event.contract_line_id is distinct from v_fact.contract_line_id
    or v_event.original_due_date is distinct from v_fact.original_due_date then
    raise exception 'validation_failed';
  end if;

  if v_event.status <> 'done'::public.calendar_event_status then
    raise exception 'validation_failed';
  end if;

  if v_event.visit_id is distinct from v_fact.visit_id then
    raise exception 'validation_failed';
  end if;

  select * into v_line
  from public.contract_lines
  where id = v_fact.contract_line_id
    and contract_id = v_fact.contract_id
    and tenant_id = v_fact.tenant_id;

  if not found or v_line.line_type <> 'consumable'::public.contract_line_type then
    raise exception 'validation_failed';
  end if;

  select * into v_product
  from public.products
  where id = v_fact.product_id
    and tenant_id = v_fact.tenant_id;

  if not found or v_product.product_type <> 'consumable_rental'::public.product_type then
    raise exception 'validation_failed';
  end if;

  if v_fact.quantity_unit is distinct from v_product.unit_primary then
    raise exception 'validation_failed';
  end if;

  v_oil_change_id := nullif(v_event.source_metadata ->> 'contract_oil_change_id', '')::uuid;

  if v_oil_change_id is not null then
    select coc.oil_product_id, coc.qty_per_refill
    into v_oil_product_id, v_expected_qty
    from public.contract_oil_changes coc
    where coc.id = v_oil_change_id
      and coc.tenant_id = v_fact.tenant_id
      and coc.contract_line_id = v_fact.contract_line_id;

    if not found then
      raise exception 'validation_failed';
    end if;

    if v_fact.product_id is distinct from v_oil_product_id then
      raise exception 'validation_failed';
    end if;
  else
    if v_fact.product_id is distinct from v_line.product_id then
      raise exception 'validation_failed';
    end if;

    v_expected_qty := v_line.qty_per_refill;
  end if;

  if v_expected_qty is null
    or v_fact.contracted_quantity_per_cycle is distinct from v_expected_qty then
    raise exception 'validation_failed';
  end if;

  select * into v_visit
  from public.visits
  where id = v_fact.visit_id
    and tenant_id = v_fact.tenant_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_visit.type <> 'refill'::public.visit_type
    or v_visit.status <> 'completed'::public.visit_status
    or v_visit.completed_at is null then
    raise exception 'validation_failed';
  end if;

  if v_visit.contract_id is distinct from v_fact.contract_id then
    raise exception 'validation_failed';
  end if;

  if v_visit.customer_id is distinct from v_event.customer_id then
    raise exception 'validation_failed';
  end if;

  if v_visit.service_location_id is distinct from v_event.service_location_id then
    raise exception 'validation_failed';
  end if;

  v_completion_date := (v_visit.completed_at at time zone v_settings.timezone_name)::date;
  if v_fact.actual_completion_date is distinct from v_completion_date then
    raise exception 'validation_failed';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_calendar_refill_execution_fact_integrity()
  from public, anon, authenticated;

drop trigger if exists trg_calendar_refill_execution_fact_integrity
  on public.calendar_refill_execution_facts;
create constraint trigger trg_calendar_refill_execution_fact_integrity
  after insert or update on public.calendar_refill_execution_facts
  deferrable initially deferred
  for each row
  execute function public.enforce_calendar_refill_execution_fact_integrity();

-- ---------------------------------------------------------------------------
-- Section E: post-fact terminal immutability guards
-- ---------------------------------------------------------------------------
create or replace function public.enforce_calendar_event_post_execution_immutable()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.calendar_refill_execution_facts f
    where f.calendar_event_id = old.id
      and f.tenant_id = old.tenant_id
  ) then
    if new.status is distinct from old.status
      or new.visit_id is distinct from old.visit_id then
      raise exception 'validation_failed';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.enforce_visit_post_execution_immutable()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.calendar_refill_execution_facts f
    where f.visit_id = old.id
      and f.tenant_id = old.tenant_id
  ) then
    if new.status is distinct from old.status
      or new.completed_at is distinct from old.completed_at then
      raise exception 'validation_failed';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_calendar_event_post_execution_immutable()
  from public, anon, authenticated;
revoke all on function public.enforce_visit_post_execution_immutable()
  from public, anon, authenticated;

drop trigger if exists trg_calendar_events_post_execution_immutable on public.calendar_events;
create trigger trg_calendar_events_post_execution_immutable
  before update on public.calendar_events
  for each row execute function public.enforce_calendar_event_post_execution_immutable();

drop trigger if exists trg_visits_post_execution_immutable on public.visits;
create trigger trg_visits_post_execution_immutable
  before update on public.visits
  for each row execute function public.enforce_visit_post_execution_immutable();

-- ---------------------------------------------------------------------------
-- Section F: overdue helpers (internal)
-- ---------------------------------------------------------------------------
create or replace function public.tenant_local_today(p_tenant_id uuid)
returns date
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_timezone text;
begin
  select tcs.timezone_name
  into v_timezone
  from public.tenant_calendar_settings tcs
  where tcs.tenant_id = p_tenant_id
    and tcs.working_schedule_configured
    and tcs.timezone_name is not null;

  if v_timezone is null or not public.is_valid_iana_timezone(v_timezone) then
    return null;
  end if;

  return (now() at time zone v_timezone)::date;
end;
$$;

create or replace function public.derive_calendar_event_overdue(p_event_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_event public.calendar_events%rowtype;
  v_today date;
  v_overdue_days int;
begin
  select * into v_event
  from public.calendar_events
  where id = p_event_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_event.status <> 'pending'::public.calendar_event_status then
    return jsonb_build_object(
      'state', 'not_applicable',
      'is_overdue', false,
      'overdue_days', 0
    );
  end if;

  if exists (
    select 1
    from public.calendar_refill_execution_facts f
    where f.calendar_event_id = v_event.id
  ) then
    return jsonb_build_object(
      'state', 'not_applicable',
      'is_overdue', false,
      'overdue_days', 0
    );
  end if;

  v_today := public.tenant_local_today(v_event.tenant_id);
  if v_today is null then
    return jsonb_build_object(
      'state', 'unconfigured_schedule',
      'is_overdue', false,
      'overdue_days', 0
    );
  end if;

  if v_event.original_due_date >= v_today then
    return jsonb_build_object(
      'state', 'not_overdue',
      'is_overdue', false,
      'overdue_days', 0
    );
  end if;

  v_overdue_days := v_today - v_event.original_due_date;
  return jsonb_build_object(
    'state', 'overdue',
    'is_overdue', true,
    'overdue_days', v_overdue_days
  );
end;
$$;

revoke all on function public.tenant_local_today(uuid) from public, anon, authenticated;
revoke all on function public.derive_calendar_event_overdue(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Section G: execution-facts ACL (no API access in M1)
-- ---------------------------------------------------------------------------
alter table public.calendar_refill_execution_facts enable row level security;

revoke insert, update, delete, select on public.calendar_refill_execution_facts
  from public, anon, authenticated;
