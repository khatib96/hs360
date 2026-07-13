-- Phase 7 M2: Event generation engine — confirmed-execution refill chain,
-- deferred lifecycle reconciliation, entry/core sync split, batch observability.

-- ---------------------------------------------------------------------------
-- Section A: Preflight (before schema mutations that assume clean state)
-- ---------------------------------------------------------------------------
do $$
declare
  v_orphan_rescheduled int;
  v_multi_locked int;
  v_multi_outstanding int;
begin
  select count(*)
  into v_orphan_rescheduled
  from public.calendar_events ce
  where ce.status = 'rescheduled'::public.calendar_event_status
    and ce.rescheduled_at is null;

  if v_orphan_rescheduled > 0 then
    raise exception 'migration_preflight_failed: orphan_rescheduled_status (%)',
      v_orphan_rescheduled;
  end if;

  select count(*)
  into v_multi_locked
  from (
    select ce.tenant_id, ce.contract_id, ce.contract_line_id, count(*) as cnt
    from public.calendar_events ce
    where ce.type = 'refill_due'::public.calendar_event_type
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.status in (
        'pending'::public.calendar_event_status,
        'rescheduled'::public.calendar_event_status
      )
      and (
        ce.assigned_agent_id is not null
        or ce.rescheduled_at is not null
        or ce.visit_id is not null
        or ce.day_off_override_at is not null
        or exists (
          select 1
          from public.calendar_refill_execution_facts f
          where f.calendar_event_id = ce.id
        )
      )
    group by ce.tenant_id, ce.contract_id, ce.contract_line_id
    having count(*) > 1
  ) q;

  if v_multi_locked > 0 then
    raise exception 'migration_preflight_failed: multiple_locked_outstanding_refill (%)',
      v_multi_locked;
  end if;

  select count(*)
  into v_multi_outstanding
  from (
    select ce.tenant_id, ce.contract_id, ce.contract_line_id, count(*) as cnt
    from public.calendar_events ce
    where ce.type = 'refill_due'::public.calendar_event_type
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.status in (
        'pending'::public.calendar_event_status,
        'rescheduled'::public.calendar_event_status
      )
    group by ce.tenant_id, ce.contract_id, ce.contract_line_id
    having count(*) > 1
  ) q;

  -- Unlocked duplicates are intentionally allowed through this preflight and
  -- are consolidated deterministically in Section D. Only multiple locked
  -- rows (above) are unsafe to repair automatically.
  if v_multi_outstanding > 0 then
    raise notice 'migration_preflight: consolidating duplicate outstanding refill groups (%)',
      v_multi_outstanding;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section B: Schema — oil change materialization + generation tables
-- ---------------------------------------------------------------------------
alter table public.contract_oil_changes
  add column if not exists calendar_materialization_status text,
  add column if not exists calendar_conflict_code text,
  add column if not exists calendar_event_id uuid,
  add column if not exists calendar_queued_after_event_id uuid,
  add column if not exists calendar_conflict_event_id uuid;

alter table public.contract_oil_changes
  drop constraint if exists chk_contract_oil_changes_materialization_state;

alter table public.contract_oil_changes
  add constraint chk_contract_oil_changes_materialization_status
  check (
    calendar_materialization_status is null
    or calendar_materialization_status in (
      'materialized', 'queued', 'conflict_requires_decision'
    )
  );

alter table public.contract_oil_changes
  add constraint chk_contract_oil_changes_materialization_state
  check (
    (
      calendar_materialization_status is null
      and calendar_event_id is null
      and calendar_queued_after_event_id is null
      and calendar_conflict_event_id is null
      and calendar_conflict_code is null
    )
    or (
      calendar_materialization_status = 'queued'
      and calendar_queued_after_event_id is not null
      and calendar_event_id is null
      and calendar_conflict_event_id is null
      and calendar_conflict_code is null
    )
    or (
      calendar_materialization_status = 'materialized'
      and calendar_event_id is not null
      and calendar_conflict_event_id is null
      and calendar_conflict_code is null
    )
    or (
      calendar_materialization_status = 'conflict_requires_decision'
      and calendar_event_id is null
      and calendar_queued_after_event_id is null
      and calendar_conflict_event_id is not null
      and calendar_conflict_code is not null
      and btrim(calendar_conflict_code) <> ''
    )
  );

alter table public.calendar_events
  add column if not exists generated_from_execution_fact_id uuid;

create table if not exists public.calendar_deferred_lifecycle_reconciliations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  contract_id uuid not null references public.contracts (id) on delete cascade,
  operation text not null
    check (operation in ('suspend', 'reactivate')),
  occurred_at timestamptz not null,
  processed_at timestamptz,
  attempt_count int not null default 0,
  last_attempt_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  constraint chk_deferred_processed_after_occurred
    check (processed_at is null or processed_at >= occurred_at)
);

create index if not exists idx_calendar_deferred_unprocessed
  on public.calendar_deferred_lifecycle_reconciliations (tenant_id, contract_id, occurred_at)
  where processed_at is null;

create table if not exists public.calendar_generation_runs (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null default 'running'
    check (status in ('running', 'completed', 'partial', 'failed', 'skipped_duplicate')),
  horizon_days int not null,
  tenants_total int not null default 0,
  tenants_completed int not null default 0,
  tenants_failed int not null default 0,
  tenants_skipped_setup int not null default 0,
  error_summary text
);

create table if not exists public.calendar_generation_run_tenants (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.calendar_generation_runs (id) on delete cascade,
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  status text not null
    check (status in (
      'completed', 'failed', 'skipped_calendar_setup_required'
    )),
  contracts_synced int not null default 0,
  error_code text,
  created_at timestamptz not null default now()
);

create index if not exists idx_calendar_generation_run_tenants_run
  on public.calendar_generation_run_tenants (run_id);

alter table public.calendar_deferred_lifecycle_reconciliations enable row level security;
alter table public.calendar_generation_runs enable row level security;
alter table public.calendar_generation_run_tenants enable row level security;

revoke all on table public.calendar_deferred_lifecycle_reconciliations
  from public, anon, authenticated, service_role;
revoke all on table public.calendar_generation_runs
  from public, anon, authenticated, service_role;
revoke all on table public.calendar_generation_run_tenants
  from public, anon, authenticated, service_role;

-- Composite FK targets (defer until after backfill for event FKs on oil_changes)
alter table public.calendar_refill_execution_facts
  drop constraint if exists ux_calendar_refill_execution_facts_tenant_id;

alter table public.calendar_refill_execution_facts
  add constraint ux_calendar_refill_execution_facts_tenant_id
  unique (tenant_id, id);

-- ---------------------------------------------------------------------------
-- Section C: Normalize legacy rescheduled → pending
-- ---------------------------------------------------------------------------
update public.calendar_events ce
set status = 'pending'::public.calendar_event_status
where ce.status = 'rescheduled'::public.calendar_event_status
  and ce.rescheduled_at is not null;

-- ---------------------------------------------------------------------------
-- Section D: Consolidate duplicate outstanding refill rows per line
-- ---------------------------------------------------------------------------
do $$
declare
  v_group record;
  v_keep_id uuid;
  v_cancel_id uuid;
begin
  for v_group in
    select
      ce.tenant_id,
      ce.contract_id,
      ce.contract_line_id,
      array_agg(ce.id order by
        case when (
          ce.assigned_agent_id is not null
          or ce.rescheduled_at is not null
          or ce.visit_id is not null
          or ce.day_off_override_at is not null
          or exists (
            select 1 from public.calendar_refill_execution_facts f
            where f.calendar_event_id = ce.id
          )
        ) then 0 else 1 end,
        ce.original_due_date,
        ce.scheduled_date,
        ce.id
      ) as event_ids
    from public.calendar_events ce
    where ce.type = 'refill_due'::public.calendar_event_type
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.status = 'pending'::public.calendar_event_status
    group by ce.tenant_id, ce.contract_id, ce.contract_line_id
    having count(*) > 1
  loop
    v_keep_id := v_group.event_ids[1];
    foreach v_cancel_id in array v_group.event_ids[2:array_length(v_group.event_ids, 1)]
    loop
      update public.calendar_events ce
      set
        status = 'cancelled'::public.calendar_event_status,
        source_metadata = ce.source_metadata || jsonb_build_object(
          'cancellation_reason', 'm2_chain_consolidation',
          'superseded_by_event_id', v_keep_id::text
        )
      where ce.id = v_cancel_id;
    end loop;
  end loop;
end $$;

do $$
declare
  v_dupes int;
begin
  select count(*)
  into v_dupes
  from (
    select ce.contract_line_id
    from public.calendar_events ce
    where ce.type = 'refill_due'::public.calendar_event_type
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.status = 'pending'::public.calendar_event_status
    group by ce.tenant_id, ce.contract_id, ce.contract_line_id
    having count(*) > 1
  ) q;

  if v_dupes > 0 then
    raise exception 'migration_postflight_failed: outstanding_refill_not_unique (%)', v_dupes;
  end if;
end $$;

-- Oil-change composite FKs (after calendar_events tenant id index exists from 094)
alter table public.contract_oil_changes
  drop constraint if exists fk_contract_oil_changes_calendar_event;

alter table public.contract_oil_changes
  add constraint fk_contract_oil_changes_calendar_event
  foreign key (tenant_id, calendar_event_id)
  references public.calendar_events (tenant_id, id);

alter table public.contract_oil_changes
  drop constraint if exists fk_contract_oil_changes_queued_after_event;

alter table public.contract_oil_changes
  add constraint fk_contract_oil_changes_queued_after_event
  foreign key (tenant_id, calendar_queued_after_event_id)
  references public.calendar_events (tenant_id, id);

alter table public.contract_oil_changes
  drop constraint if exists fk_contract_oil_changes_conflict_event;

alter table public.contract_oil_changes
  add constraint fk_contract_oil_changes_conflict_event
  foreign key (tenant_id, calendar_conflict_event_id)
  references public.calendar_events (tenant_id, id);

alter table public.calendar_events
  drop constraint if exists fk_calendar_events_generated_from_fact;

alter table public.calendar_events
  add constraint fk_calendar_events_generated_from_fact
  foreign key (tenant_id, generated_from_execution_fact_id)
  references public.calendar_refill_execution_facts (tenant_id, id);

create unique index if not exists ux_calendar_events_generated_from_fact
  on public.calendar_events (tenant_id, generated_from_execution_fact_id)
  where generated_from_execution_fact_id is not null;

create unique index if not exists ux_calendar_events_outstanding_refill
  on public.calendar_events (tenant_id, contract_id, contract_line_id)
  where type = 'refill_due'::public.calendar_event_type
    and status = 'pending'::public.calendar_event_status
    and source_kind = 'contract_generated'::public.calendar_event_source_kind;

-- ---------------------------------------------------------------------------
-- Section E: Metadata whitelist extension + helpers
-- ---------------------------------------------------------------------------
create or replace function public.calendar_event_metadata_is_whitelisted(p_metadata jsonb)
returns boolean
language plpgsql
immutable
as $$
declare
  v_key text;
  v_allowed constant text[] := array[
    'coverage_month_key',
    'billing_day',
    'action_kind',
    'contract_oil_change_id',
    'oil_product_id',
    'previous_oil_product_id',
    'qty_per_refill',
    'cancellation_reason',
    'replaces_event_id',
    'reinstated_at',
    'superseded_by_event_id'
  ];
begin
  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    return false;
  end if;

  for v_key in select jsonb_object_keys(p_metadata) loop
    if not (v_key = any (v_allowed)) then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

create or replace function public.sanitize_sql_error_code(p_sqlstate text)
returns text
language sql
immutable
as $$
  select case
    when p_sqlstate ~ '^[0-9A-Z]{5}$' then p_sqlstate
    else 'P0001'
  end;
$$;

create or replace function public.calendar_timezone_ready(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tenant_calendar_settings tcs
    where tcs.tenant_id = p_tenant_id
      and tcs.timezone_name is not null
      and public.is_valid_iana_timezone(tcs.timezone_name)
  );
$$;

create or replace function public.try_tenant_local_today(p_tenant_id uuid)
returns date
language sql
stable
security definer
set search_path = public
as $$
  select (now() at time zone tcs.timezone_name)::date
  from public.tenant_calendar_settings tcs
  where tcs.tenant_id = p_tenant_id
    and tcs.timezone_name is not null
    and public.is_valid_iana_timezone(tcs.timezone_name);
$$;

create or replace function public.calendar_event_is_regen_safe(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select
        ce.status = 'pending'::public.calendar_event_status
        and ce.assigned_agent_id is null
        and ce.rescheduled_at is null
        and ce.visit_id is null
        and ce.day_off_override_at is null
        and not exists (
          select 1
          from public.calendar_refill_execution_facts f
          where f.calendar_event_id = ce.id
        )
      from public.calendar_events ce
      where ce.id = p_event_id
    ),
    false
  );
$$;

create or replace function public.compute_first_cadence_date_on_or_after(
  p_start_date date,
  p_freq_months int,
  p_refill_day int,
  p_on_or_after date
)
returns date
language plpgsql
immutable
as $$
declare
  v_freq int;
  v_cadence_base_month date;
  v_on_or_after_month date;
  v_month_delta int;
  v_n int;
  v_adjust int;
  v_month_start date;
  v_candidate date;
begin
  if p_start_date is null
    or p_on_or_after is null
    or p_refill_day is null then
    return null;
  end if;

  v_freq := greatest(coalesce(p_freq_months, 1), 1);
  v_cadence_base_month := date_trunc('month', p_start_date)::date;
  v_on_or_after_month := date_trunc('month', p_on_or_after)::date;
  v_month_delta :=
    (extract(year from v_on_or_after_month)::int - extract(year from v_cadence_base_month)::int) * 12
    + (extract(month from v_on_or_after_month)::int - extract(month from v_cadence_base_month)::int);
  v_n := greatest(1, floor(v_month_delta::numeric / v_freq)::int);

  for v_adjust in 0..2 loop
    v_month_start := (v_cadence_base_month + (v_n * v_freq) * interval '1 month')::date;
    v_candidate := public.calendar_make_day_in_month(v_month_start, p_refill_day);
    if v_candidate >= p_start_date and v_candidate >= p_on_or_after then
      return v_candidate;
    end if;
    v_n := v_n + 1;
  end loop;

  return null;
end;
$$;

drop function if exists public.build_contract_calendar_source_key(uuid, text, uuid, date, date);
drop function if exists public.build_contract_calendar_source_key(uuid, text, uuid, date, date, uuid);

create or replace function public.build_contract_calendar_source_key(
  p_contract_id uuid,
  p_kind text,
  p_contract_line_id uuid default null,
  p_date date default null,
  p_coverage_month_key date default null,
  p_tail_uuid uuid default null
)
returns text
language sql
immutable
as $$
  select case p_kind
    when 'trial_ending' then format('contract:%s:trial_ending', p_contract_id)
    when 'trial_ending_versioned' then format(
      'contract:%s:trial_ending:%s', p_contract_id, to_char(p_date, 'YYYY-MM-DD')
    )
    when 'contract_end' then format('contract:%s:contract_end', p_contract_id)
    when 'contract_end_versioned' then format(
      'contract:%s:contract_end:%s', p_contract_id, to_char(p_date, 'YYYY-MM-DD')
    )
    when 'billing' then format(
      'contract:%s:billing:%s',
      p_contract_id,
      to_char(p_coverage_month_key, 'YYYY-MM-DD')
    )
    when 'refill' then format(
      'contract:%s:refill:%s:%s',
      p_contract_id,
      p_contract_line_id,
      to_char(p_date, 'YYYY-MM-DD')
    )
    when 'refill_initial' then format(
      'contract:%s:refill:%s:initial', p_contract_id, p_contract_line_id
    )
    when 'refill_from_fact' then format(
      'contract:%s:refill:%s:from_fact:%s', p_contract_id, p_contract_line_id, p_tail_uuid
    )
    when 'refill_queued' then format(
      'contract:%s:refill:%s:queued:%s', p_contract_id, p_contract_line_id, p_tail_uuid
    )
    when 'refill_replacement' then format(
      'contract:%s:refill:%s:replacement:%s', p_contract_id, p_contract_line_id, p_tail_uuid
    )
    when 'refill_oil_change' then format(
      'contract:%s:refill:%s:oil_change:%s', p_contract_id, p_contract_line_id, p_tail_uuid
    )
    when 'refill_reactivation' then format(
      'contract:%s:refill:%s:reactivation:%s', p_contract_id, p_contract_line_id, p_tail_uuid
    )
    else null
  end;
$$;

create or replace function public.calendar_event_source_requires_execution_fact(p_source_key text)
returns boolean
language sql
immutable
as $$
  select
    p_source_key ~ '^contract:[0-9a-f-]{36}:refill:[0-9a-f-]{36}:from_fact:[0-9a-f-]{36}$'
    or p_source_key ~ '^contract:[0-9a-f-]{36}:refill:[0-9a-f-]{36}:queued:[0-9a-f-]{36}$';
$$;

create or replace function public.parse_calendar_refill_source_key(p_source_key text)
returns table (
  kind text,
  contract_id uuid,
  contract_line_id uuid,
  tail_uuid uuid
)
language plpgsql
immutable
as $$
begin
  if p_source_key ~ '^contract:([0-9a-f-]{36}):refill:([0-9a-f-]{36}):initial$' then
    kind := 'initial';
    contract_id := (regexp_match(p_source_key, '^contract:([0-9a-f-]{36})'))[1]::uuid;
    contract_line_id := (regexp_match(p_source_key, ':refill:([0-9a-f-]{36})'))[1]::uuid;
    tail_uuid := null;
    return next;
    return;
  end if;

  if p_source_key ~ '^contract:[0-9a-f-]{36}:refill:[0-9a-f-]{36}:(from_fact|queued|replacement|oil_change|reactivation):[0-9a-f-]{36}$' then
    kind := (regexp_match(p_source_key, ':(from_fact|queued|replacement|oil_change|reactivation):'))[1];
    contract_id := (regexp_match(p_source_key, '^contract:([0-9a-f-]{36})'))[1]::uuid;
    contract_line_id := (regexp_match(p_source_key, ':refill:([0-9a-f-]{36})'))[1]::uuid;
    tail_uuid := (
      regexp_match(
        p_source_key,
        '(from_fact|queued|replacement|oil_change|reactivation):([0-9a-f-]{36})$'
      )
    )[2]::uuid;
    return next;
    return;
  end if;

  if p_source_key ~ '^contract:[0-9a-f-]{36}:refill:[0-9a-f-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    kind := 'legacy_date';
    contract_id := (regexp_match(p_source_key, '^contract:([0-9a-f-]{36})'))[1]::uuid;
    contract_line_id := (regexp_match(p_source_key, ':refill:([0-9a-f-]{36})'))[1]::uuid;
    tail_uuid := null;
    return next;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section F: Upsert with regen-safe preservation
-- ---------------------------------------------------------------------------
create or replace function public.merge_calendar_event_metadata_safe(
  p_existing jsonb,
  p_incoming jsonb
)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_result jsonb := coalesce(p_existing, '{}'::jsonb);
  v_key text;
  v_allowed constant text[] := array[
    'action_kind',
    'contract_oil_change_id',
    'oil_product_id',
    'previous_oil_product_id',
    'qty_per_refill',
    'coverage_month_key',
    'billing_day'
  ];
begin
  if p_incoming is null or jsonb_typeof(p_incoming) <> 'object' then
    return v_result;
  end if;

  for v_key in select jsonb_object_keys(p_incoming) loop
    if v_key = any (v_allowed) then
      v_result := v_result || jsonb_build_object(v_key, p_incoming -> v_key);
    end if;
  end loop;

  return v_result;
end;
$$;

create or replace function public.upsert_contract_calendar_event(
  p_tenant_id uuid,
  p_contract_id uuid,
  p_customer_id uuid,
  p_service_location_id uuid,
  p_contract_line_id uuid,
  p_type public.calendar_event_type,
  p_scheduled_date date,
  p_source_key text,
  p_source_metadata jsonb,
  p_title_ar text,
  p_title_en text,
  p_reminder_offsets_minutes int[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_id uuid;
  v_existing public.calendar_events%rowtype;
  v_metadata jsonb := coalesce(p_source_metadata, '{}'::jsonb);
  v_regen_safe boolean;
begin
  if not public.calendar_event_metadata_is_whitelisted(v_metadata) then
    raise exception 'validation_failed';
  end if;

  select *
  into v_existing
  from public.calendar_events ce
  where ce.tenant_id = p_tenant_id
    and ce.source_key = p_source_key
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
  for update;

  if found then
    v_event_id := v_existing.id;

    if v_existing.status <> 'pending'::public.calendar_event_status then
      return v_event_id;
    end if;

    v_regen_safe := public.calendar_event_is_regen_safe(v_existing.id);

    if v_regen_safe then
      update public.calendar_events ce
      set
        scheduled_date = p_scheduled_date,
        type = p_type,
        contract_line_id = p_contract_line_id,
        customer_id = p_customer_id,
        service_location_id = p_service_location_id,
        source_metadata = v_metadata,
        title_ar = p_title_ar,
        title_en = p_title_en,
        reminder_offsets_minutes = p_reminder_offsets_minutes
      where ce.id = v_existing.id;
    else
      update public.calendar_events ce
      set
        type = p_type,
        contract_line_id = p_contract_line_id,
        customer_id = p_customer_id,
        service_location_id = p_service_location_id,
        source_metadata = public.merge_calendar_event_metadata_safe(
          ce.source_metadata,
          v_metadata
        ),
        title_ar = p_title_ar,
        title_en = p_title_en,
        reminder_offsets_minutes = p_reminder_offsets_minutes
      where ce.id = v_existing.id;
    end if;

    return v_event_id;
  end if;

  insert into public.calendar_events (
    tenant_id,
    type,
    status,
    scheduled_date,
    reminder_offsets_minutes,
    contract_id,
    customer_id,
    service_location_id,
    contract_line_id,
    title_ar,
    title_en,
    source_kind,
    source_key,
    source_metadata
  )
  values (
    p_tenant_id,
    p_type,
    'pending'::public.calendar_event_status,
    p_scheduled_date,
    p_reminder_offsets_minutes,
    p_contract_id,
    p_customer_id,
    p_service_location_id,
    p_contract_line_id,
    p_title_ar,
    p_title_en,
    'contract_generated'::public.calendar_event_source_kind,
    p_source_key,
    v_metadata
  )
  returning id into v_event_id;

  return v_event_id;
end;
$$;

create or replace function public.upsert_contract_calendar_event_recorded(
  p_tenant_id uuid,
  p_contract_id uuid,
  p_customer_id uuid,
  p_service_location_id uuid,
  p_contract_line_id uuid,
  p_type public.calendar_event_type,
  p_scheduled_date date,
  p_source_key text,
  p_source_metadata jsonb,
  p_title_ar text,
  p_title_en text,
  p_reminder_offsets_minutes int[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing_id uuid;
  v_event_id uuid;
  v_action text;
begin
  select ce.id
  into v_existing_id
  from public.calendar_events ce
  where ce.tenant_id = p_tenant_id
    and ce.source_key = p_source_key
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind;

  v_event_id := public.upsert_contract_calendar_event(
    p_tenant_id,
    p_contract_id,
    p_customer_id,
    p_service_location_id,
    p_contract_line_id,
    p_type,
    p_scheduled_date,
    p_source_key,
    p_source_metadata,
    p_title_ar,
    p_title_en,
    p_reminder_offsets_minutes
  );

  if v_existing_id is null then
    v_action := 'inserted';
  elsif public.calendar_event_is_regen_safe(v_existing_id) then
    v_action := 'updated';
  else
    v_action := 'preserved';
  end if;

  return jsonb_build_object(
    'event_id', v_event_id,
    'action', v_action
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section G: Refill event INSERT helper
-- ---------------------------------------------------------------------------
create or replace function public.create_contract_refill_calendar_event(
  p_tenant_id uuid,
  p_contract_id uuid,
  p_customer_id uuid,
  p_service_location_id uuid,
  p_contract_line_id uuid,
  p_scheduled_date date,
  p_source_key text,
  p_source_metadata jsonb,
  p_title_ar text,
  p_title_en text,
  p_reminder_offsets_minutes int[],
  p_generated_from_execution_fact_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_id uuid;
  v_metadata jsonb := coalesce(p_source_metadata, '{}'::jsonb);
begin
  if not public.calendar_event_metadata_is_whitelisted(v_metadata) then
    raise exception 'validation_failed';
  end if;

  insert into public.calendar_events (
    tenant_id,
    type,
    status,
    scheduled_date,
    reminder_offsets_minutes,
    contract_id,
    customer_id,
    service_location_id,
    contract_line_id,
    title_ar,
    title_en,
    source_kind,
    source_key,
    source_metadata,
    generated_from_execution_fact_id
  )
  values (
    p_tenant_id,
    'refill_due'::public.calendar_event_type,
    'pending'::public.calendar_event_status,
    p_scheduled_date,
    p_reminder_offsets_minutes,
    p_contract_id,
    p_customer_id,
    p_service_location_id,
    p_contract_line_id,
    p_title_ar,
    p_title_en,
    'contract_generated'::public.calendar_event_source_kind,
    p_source_key,
    v_metadata,
    p_generated_from_execution_fact_id
  )
  returning id into v_event_id;

  return v_event_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section H: Deferred lifecycle reconciliation + suspension
-- ---------------------------------------------------------------------------
create or replace function public.enqueue_calendar_deferred_lifecycle(
  p_tenant_id uuid,
  p_contract_id uuid,
  p_operation text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_operation not in ('suspend', 'reactivate') then
    raise exception 'validation_failed';
  end if;

  insert into public.calendar_deferred_lifecycle_reconciliations (
    tenant_id,
    contract_id,
    operation,
    occurred_at
  )
  values (
    p_tenant_id,
    p_contract_id,
    p_operation,
    clock_timestamp()
  );
end;
$$;

create or replace function public.suspend_contract_generated_events_at_date(
  p_contract_id uuid,
  p_as_of_date date
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  update public.calendar_events ce
  set
    status = 'cancelled'::public.calendar_event_status,
    source_metadata = ce.source_metadata || jsonb_build_object(
      'cancellation_reason', 'suspension'
    )
  where ce.contract_id = p_contract_id
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.status = 'pending'::public.calendar_event_status
    and ce.type in (
      'billing_due'::public.calendar_event_type,
      'refill_due'::public.calendar_event_type
    )
    and ce.scheduled_date >= p_as_of_date;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.suspend_contract_generated_events(
  p_contract_id uuid
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contract public.contracts%rowtype;
  v_today date;
begin
  select *
  into v_contract
  from public.contracts c
  where c.id = p_contract_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if not public.calendar_timezone_ready(v_contract.tenant_id) then
    perform public.enqueue_calendar_deferred_lifecycle(
      v_contract.tenant_id,
      v_contract.id,
      'suspend'
    );
    return 0;
  end if;

  v_today := public.try_tenant_local_today(v_contract.tenant_id);
  if v_today is null then
    perform public.enqueue_calendar_deferred_lifecycle(
      v_contract.tenant_id,
      v_contract.id,
      'suspend'
    );
    return 0;
  end if;

  return public.suspend_contract_generated_events_at_date(p_contract_id, v_today);
end;
$$;

create or replace function public.reconcile_deferred_reactivation(
  p_contract_id uuid,
  p_reactivation_as_of_date date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contract public.contracts%rowtype;
  v_effective_end date;
  v_cancelled record;
  v_line public.contract_lines%rowtype;
  v_anchor date;
  v_freq int;
  v_queued record;
  v_source_key text;
  v_metadata jsonb;
  v_title_ar text;
  v_title_en text;
  v_product_name_ar text;
  v_product_name_en text;
  v_prev_product_id uuid;
  v_event_id uuid;
begin
  select *
  into v_contract
  from public.contracts c
  where c.id = p_contract_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  v_effective_end := public.resolve_contract_effective_end(v_contract);

  -- Case A: reinstate suspension-cancelled rows still on or after reactivation date.
  update public.calendar_events ce
  set
    status = 'pending'::public.calendar_event_status,
    source_metadata = ce.source_metadata || jsonb_build_object(
      'reinstated_at', to_char(clock_timestamp() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    )
  where ce.contract_id = p_contract_id
    and ce.tenant_id = v_contract.tenant_id
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.status = 'cancelled'::public.calendar_event_status
    and ce.source_metadata ->> 'cancellation_reason' = 'suspension'
    and ce.scheduled_date >= p_reactivation_as_of_date
    and (
      v_effective_end is null
      or ce.scheduled_date <= v_effective_end
    )
    and (
      ce.type <> 'billing_due'::public.calendar_event_type
      or not exists (
        select 1
        from public.rental_invoice_coverages ric
        where ric.tenant_id = ce.tenant_id
          and ric.contract_id = ce.contract_id
          and ric.coverage_month_key = nullif(
            ce.source_metadata ->> 'coverage_month_key',
            ''
          )::date
      )
    );

  -- Case B: replacement refill rows for dates that passed during suspension.
  for v_cancelled in
    select ce.*
    from public.calendar_events ce
    where ce.contract_id = p_contract_id
      and ce.tenant_id = v_contract.tenant_id
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.type = 'refill_due'::public.calendar_event_type
      and ce.status = 'cancelled'::public.calendar_event_status
      and ce.source_metadata ->> 'cancellation_reason' = 'suspension'
      and ce.scheduled_date < p_reactivation_as_of_date
      and (
        v_effective_end is null
        or ce.scheduled_date <= v_effective_end
      )
    order by ce.scheduled_date, ce.id
  loop
    v_source_key := public.build_contract_calendar_source_key(
      p_contract_id,
      'refill_reactivation',
      v_cancelled.contract_line_id,
      null,
      null,
      v_cancelled.id
    );

    if exists (
      select 1
      from public.calendar_events ce
      where ce.tenant_id = v_contract.tenant_id
        and ce.source_key = v_source_key
        and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    ) then
      continue;
    end if;

    if exists (
      select 1
      from public.calendar_events ce
      where ce.tenant_id = v_contract.tenant_id
        and ce.contract_id = p_contract_id
        and ce.contract_line_id = v_cancelled.contract_line_id
        and ce.type = 'refill_due'::public.calendar_event_type
        and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
        and ce.status = 'pending'::public.calendar_event_status
    ) then
      continue;
    end if;

    select *
    into v_line
    from public.contract_lines cl
    where cl.id = v_cancelled.contract_line_id
      and cl.contract_id = p_contract_id
      and cl.tenant_id = v_contract.tenant_id;

    if not found or v_contract.refill_day is null then
      continue;
    end if;

    v_freq := greatest(coalesce(v_line.refill_frequency_months, 1), 1);

    select
      coc.id,
      coc.effective_from,
      coc.oil_product_id,
      coc.qty_per_refill,
      p.name_ar,
      p.name_en
    into v_queued
    from public.contract_oil_changes coc
    join public.products p
      on p.id = coc.oil_product_id
      and p.tenant_id = coc.tenant_id
    where coc.tenant_id = v_contract.tenant_id
      and coc.contract_line_id = v_cancelled.contract_line_id
      and coc.calendar_queued_after_event_id = v_cancelled.id
      and coc.calendar_materialization_status = 'queued'
    order by coc.effective_from, coc.id
    limit 1;

    if v_queued.id is not null then
      v_anchor := v_queued.effective_from;
      v_metadata := jsonb_build_object(
        'action_kind', 'refill_with_consumable_change',
        'contract_oil_change_id', v_queued.id,
        'oil_product_id', v_queued.oil_product_id,
        'qty_per_refill', v_queued.qty_per_refill::text,
        'replaces_event_id', v_cancelled.id::text
      );
      v_title_ar := 'تعبئة مع تغيير مستهلك — ' || coalesce(v_queued.name_ar, '');
      v_title_en := 'Refill with consumable change — ' || coalesce(v_queued.name_en, '');
    else
      v_anchor := public.compute_first_cadence_date_on_or_after(
        v_contract.start_date,
        v_freq,
        v_contract.refill_day,
        p_reactivation_as_of_date
      );

      if v_anchor is null then
        continue;
      end if;

      select p.name_ar, p.name_en
      into v_product_name_ar, v_product_name_en
      from public.contract_oil_changes coc
      join public.products p
        on p.id = coc.oil_product_id
        and p.tenant_id = coc.tenant_id
      where coc.contract_line_id = v_cancelled.contract_line_id
        and coc.tenant_id = v_contract.tenant_id
        and coc.effective_from <= v_anchor
        and (coc.effective_to is null or coc.effective_to >= v_anchor)
      order by coc.effective_from desc, coc.created_at desc, coc.id desc
      limit 1;

      v_metadata := jsonb_build_object(
        'action_kind', 'refill',
        'replaces_event_id', v_cancelled.id::text
      );
      v_title_ar := 'تعبئة — ' || coalesce(v_product_name_ar, '');
      v_title_en := 'Refill — ' || coalesce(v_product_name_en, '');
    end if;

    v_event_id := public.create_contract_refill_calendar_event(
      v_contract.tenant_id,
      v_contract.id,
      v_contract.customer_id,
      v_contract.service_location_id,
      v_cancelled.contract_line_id,
      v_anchor,
      v_source_key,
      v_metadata,
      v_title_ar,
      v_title_en,
      array[1440, 60],
      null
    );

    if v_queued.id is not null then
      update public.contract_oil_changes coc
      set
        calendar_materialization_status = 'materialized',
        calendar_event_id = v_event_id,
        calendar_conflict_event_id = null,
        calendar_conflict_code = null
      where coc.id = v_queued.id;
      -- calendar_queued_after_event_id is retained as immutable audit lineage.
    end if;
  end loop;
end;
$$;

create or replace function public.reconcile_deferred_calendar_lifecycle_ops(
  p_tenant_id uuid,
  p_contract_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contract record;
  v_row public.calendar_deferred_lifecycle_reconciliations%rowtype;
  v_contract_failed boolean;
  v_local_date date;
  v_timezone_name text;
begin
  if not public.calendar_timezone_ready(p_tenant_id) then
    return;
  end if;

  select tcs.timezone_name
  into v_timezone_name
  from public.tenant_calendar_settings tcs
  where tcs.tenant_id = p_tenant_id;

  for v_contract in
    select c.id as contract_id
    from public.contracts c
    where c.tenant_id = p_tenant_id
      and (p_contract_id is null or c.id = p_contract_id)
      and exists (
        select 1
        from public.calendar_deferred_lifecycle_reconciliations d
        where d.tenant_id = c.tenant_id
          and d.contract_id = c.id
          and d.processed_at is null
      )
    order by c.id
    for update of c skip locked
  loop
    v_contract_failed := false;

    for v_row in
      select *
      from public.calendar_deferred_lifecycle_reconciliations d
      where d.tenant_id = p_tenant_id
        and d.contract_id = v_contract.contract_id
        and d.processed_at is null
      order by d.occurred_at, d.id
      for update
    loop
      if v_contract_failed then
        exit;
      end if;

      begin
        v_local_date := (v_row.occurred_at at time zone v_timezone_name)::date;

        if v_row.operation = 'suspend' then
          perform public.suspend_contract_generated_events_at_date(
            v_row.contract_id,
            v_local_date
          );
        elsif v_row.operation = 'reactivate' then
          perform public.reconcile_deferred_reactivation(
            v_row.contract_id,
            v_local_date
          );
          perform public.sync_contract_calendar_events_core_internal(
            v_row.contract_id,
            public.calendar_default_horizon_days()
          );
        else
          raise exception 'validation_failed';
        end if;

        update public.calendar_deferred_lifecycle_reconciliations d
        set
          attempt_count = d.attempt_count + 1,
          last_attempt_at = clock_timestamp(),
          processed_at = clock_timestamp(),
          last_error_code = null
        where d.id = v_row.id;

      exception
        when others then
          update public.calendar_deferred_lifecycle_reconciliations d
          set
            attempt_count = d.attempt_count + 1,
            last_attempt_at = clock_timestamp(),
            last_error_code = public.sanitize_sql_error_code(sqlstate),
            processed_at = null
          where d.id = v_row.id;
          v_contract_failed := true;
      end;
    end loop;
  end loop;
end;
$$;

create or replace function public.reinstate_suspended_calendar_events(
  p_contract_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contract public.contracts%rowtype;
  v_today date;
begin
  select *
  into v_contract
  from public.contracts c
  where c.id = p_contract_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if not public.calendar_timezone_ready(v_contract.tenant_id) then
    perform public.enqueue_calendar_deferred_lifecycle(
      v_contract.tenant_id,
      v_contract.id,
      'reactivate'
    );
    return;
  end if;

  v_today := public.try_tenant_local_today(v_contract.tenant_id);
  if v_today is null then
    perform public.enqueue_calendar_deferred_lifecycle(
      v_contract.tenant_id,
      v_contract.id,
      'reactivate'
    );
    return;
  end if;

  perform public.reconcile_deferred_reactivation(p_contract_id, v_today);
  perform public.sync_contract_calendar_events_core_internal(
    p_contract_id,
    public.calendar_default_horizon_days()
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section I: Consumable-change calendar materialization (Rules 0–3)
-- ---------------------------------------------------------------------------
create or replace function public.apply_consumable_change_to_calendar(
  p_oil_change_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_oil public.contract_oil_changes%rowtype;
  v_contract public.contracts%rowtype;
  v_outstanding public.calendar_events%rowtype;
  v_predecessor public.calendar_events%rowtype;
  v_prev_product_id uuid;
  v_metadata jsonb;
  v_title_ar text;
  v_title_en text;
  v_source_key text;
  v_event_id uuid;
  v_locked boolean;
begin
  select *
  into v_oil
  from public.contract_oil_changes coc
  where coc.id = p_oil_change_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_oil.calendar_materialization_status = 'materialized'
    or v_oil.calendar_materialization_status = 'conflict_requires_decision' then
    return jsonb_build_object('skipped', true, 'reason', 'already_materialized');
  end if;

  select *
  into v_contract
  from public.contracts c
  where c.id = v_oil.contract_id
    and c.tenant_id = v_oil.tenant_id;

  if not found
    or v_contract.type <> 'rental'::public.contract_type
    or v_contract.status <> 'active'::public.contract_status then
    return jsonb_build_object('skipped', true, 'reason', 'inactive_contract');
  end if;

  select *
  into v_outstanding
  from public.calendar_events ce
  where ce.tenant_id = v_oil.tenant_id
    and ce.contract_id = v_oil.contract_id
    and ce.contract_line_id = v_oil.contract_line_id
    and ce.type = 'refill_due'::public.calendar_event_type
    and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
    and ce.status = 'pending'::public.calendar_event_status
  for update;

  if not found then
    -- Rule 0 is valid only before a refill chain has a done predecessor. If a
    -- predecessor exists, bind the change to it and wait for the execution
    -- fact instead of creating a successor prematurely.
    select ce.*
    into v_predecessor
    from public.calendar_events ce
    left join public.calendar_refill_execution_facts f
      on f.tenant_id = ce.tenant_id
      and f.calendar_event_id = ce.id
    where ce.tenant_id = v_oil.tenant_id
      and ce.contract_id = v_oil.contract_id
      and ce.contract_line_id = v_oil.contract_line_id
      and ce.type = 'refill_due'::public.calendar_event_type
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.status = 'done'::public.calendar_event_status
    order by f.actual_completion_date desc nulls last, ce.scheduled_date desc, ce.id desc
    limit 1
    for update of ce;

    if found then
      update public.contract_oil_changes coc
      set
        calendar_materialization_status = 'queued',
        calendar_queued_after_event_id = v_predecessor.id,
        calendar_event_id = null,
        calendar_conflict_event_id = null,
        calendar_conflict_code = null
      where coc.id = v_oil.id;

      return jsonb_build_object(
        'rule', 3,
        'reason', 'awaiting_execution_fact',
        'queued_after_event_id', v_predecessor.id
      );
    end if;

    -- Rule 0: no outstanding and no predecessor — materialize at
    -- effective_from when eligible.
    if v_oil.calendar_materialization_status is not null
      and v_oil.calendar_materialization_status <> 'queued' then
      return jsonb_build_object('skipped', true, 'reason', 'not_eligible');
    end if;

    v_source_key := public.build_contract_calendar_source_key(
      v_contract.id,
      'refill_oil_change',
      v_oil.contract_line_id,
      null,
      null,
      v_oil.id
    );

    select p.name_ar, p.name_en
    into v_title_ar, v_title_en
    from public.products p
    where p.id = v_oil.oil_product_id
      and p.tenant_id = v_oil.tenant_id;

    v_metadata := jsonb_build_object(
      'action_kind', 'consumable_change',
      'contract_oil_change_id', v_oil.id,
      'oil_product_id', v_oil.oil_product_id,
      'qty_per_refill', v_oil.qty_per_refill::text
    );

    v_event_id := public.create_contract_refill_calendar_event(
      v_contract.tenant_id,
      v_contract.id,
      v_contract.customer_id,
      v_contract.service_location_id,
      v_oil.contract_line_id,
      v_oil.effective_from,
      v_source_key,
      v_metadata,
      'تغيير مستهلك — ' || coalesce(v_title_ar, ''),
      'Consumable change — ' || coalesce(v_title_en, ''),
      array[1440, 60],
      null
    );

    update public.contract_oil_changes coc
    set
      calendar_materialization_status = 'materialized',
      calendar_event_id = v_event_id,
      calendar_queued_after_event_id = null,
      calendar_conflict_event_id = null,
      calendar_conflict_code = null
    where coc.id = v_oil.id;

    return jsonb_build_object('rule', 0, 'event_id', v_event_id);
  end if;

  select coc.oil_product_id
  into v_prev_product_id
  from public.contract_oil_changes coc
  where coc.contract_line_id = v_oil.contract_line_id
    and coc.tenant_id = v_oil.tenant_id
    and coc.effective_from < v_oil.effective_from
  order by coc.effective_from desc, coc.created_at desc, coc.id desc
  limit 1;

  if v_oil.effective_from = v_outstanding.scheduled_date then
  -- Rule 1: merge metadata only (source_key identity preserved).
    v_metadata := jsonb_build_object(
      'action_kind', 'refill_with_consumable_change',
      'contract_oil_change_id', v_oil.id,
      'oil_product_id', v_oil.oil_product_id,
      'previous_oil_product_id', v_prev_product_id,
      'qty_per_refill', v_oil.qty_per_refill::text
    );

    select p.name_ar, p.name_en
    into v_title_ar, v_title_en
    from public.products p
    where p.id = v_oil.oil_product_id
      and p.tenant_id = v_oil.tenant_id;

    v_event_id := public.upsert_contract_calendar_event(
      v_contract.tenant_id,
      v_contract.id,
      v_contract.customer_id,
      v_contract.service_location_id,
      v_oil.contract_line_id,
      'refill_due'::public.calendar_event_type,
      v_outstanding.scheduled_date,
      v_outstanding.source_key,
      v_metadata,
      'تعبئة مع تغيير مستهلك — ' || coalesce(v_title_ar, ''),
      'Refill with consumable change — ' || coalesce(v_title_en, ''),
      array[1440, 60]
    );

    update public.contract_oil_changes coc
    set
      calendar_materialization_status = 'materialized',
      calendar_event_id = v_event_id,
      calendar_queued_after_event_id = null,
      calendar_conflict_event_id = null,
      calendar_conflict_code = null
    where coc.id = v_oil.id;

    return jsonb_build_object('rule', 1, 'event_id', v_event_id);
  end if;

  if v_oil.effective_from < v_outstanding.scheduled_date then
  -- Rule 2: replacement or locked conflict.
    v_locked := not public.calendar_event_is_regen_safe(v_outstanding.id);

    if v_locked then
      update public.contract_oil_changes coc
      set
        calendar_materialization_status = 'conflict_requires_decision',
        calendar_conflict_event_id = v_outstanding.id,
        calendar_conflict_code = 'consumable_change_locked_conflict',
        calendar_event_id = null,
        calendar_queued_after_event_id = null
      where coc.id = v_oil.id;

      return jsonb_build_object(
        'rule', 2,
        'conflict', true,
        'conflict_event_id', v_outstanding.id,
        'conflict_code', 'consumable_change_locked_conflict'
      );
    end if;

    update public.calendar_events ce
    set
      status = 'cancelled'::public.calendar_event_status,
      source_metadata = ce.source_metadata || jsonb_build_object(
        'cancellation_reason', 'consumable_change_replacement'
      )
    where ce.id = v_outstanding.id;

    v_source_key := public.build_contract_calendar_source_key(
      v_contract.id,
      'refill_replacement',
      v_oil.contract_line_id,
      null,
      null,
      v_oil.id
    );

    select p.name_ar, p.name_en
    into v_title_ar, v_title_en
    from public.products p
    where p.id = v_oil.oil_product_id
      and p.tenant_id = v_oil.tenant_id;

    v_metadata := jsonb_build_object(
      'action_kind', 'consumable_change',
      'contract_oil_change_id', v_oil.id,
      'oil_product_id', v_oil.oil_product_id,
      'previous_oil_product_id', v_prev_product_id,
      'qty_per_refill', v_oil.qty_per_refill::text,
      'replaces_event_id', v_outstanding.id::text
    );

    v_event_id := public.create_contract_refill_calendar_event(
      v_contract.tenant_id,
      v_contract.id,
      v_contract.customer_id,
      v_contract.service_location_id,
      v_oil.contract_line_id,
      v_oil.effective_from,
      v_source_key,
      v_metadata,
      'تغيير مستهلك — ' || coalesce(v_title_ar, ''),
      'Consumable change — ' || coalesce(v_title_en, ''),
      array[1440, 60],
      null
    );

    update public.contract_oil_changes coc
    set
      calendar_materialization_status = 'materialized',
      calendar_event_id = v_event_id,
      calendar_queued_after_event_id = null,
      calendar_conflict_event_id = null,
      calendar_conflict_code = null
    where coc.id = v_oil.id;

    return jsonb_build_object('rule', 2, 'event_id', v_event_id);
  end if;

  -- Rule 3: queue after outstanding event.
  update public.contract_oil_changes coc
  set
    calendar_materialization_status = 'queued',
    calendar_queued_after_event_id = v_outstanding.id,
    calendar_event_id = null,
    calendar_conflict_event_id = null,
    calendar_conflict_code = null
  where coc.id = v_oil.id;

  return jsonb_build_object(
    'rule', 3,
    'queued_after_event_id', v_outstanding.id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section J: Confirmed-execution refill chain sync
-- ---------------------------------------------------------------------------
create or replace function public.sync_contract_refill_chain_internal(
  p_contract public.contracts,
  p_v_today date
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  v_line public.contract_lines%rowtype;
  v_effective_end date;
  v_outstanding public.calendar_events%rowtype;
  v_predecessor public.calendar_events%rowtype;
  v_fact public.calendar_refill_execution_facts%rowtype;
  v_queued record;
  v_oil record;
  v_anchor date;
  v_freq int;
  v_source_key text;
  v_metadata jsonb;
  v_title_ar text;
  v_title_en text;
  v_product_name_ar text;
  v_product_name_en text;
  v_prev_product_id uuid;
  v_event_id uuid;
begin
  if p_contract.type <> 'rental'::public.contract_type
    or p_contract.status <> 'active'::public.contract_status
    or p_contract.refill_day is null then
    return 0;
  end if;

  v_effective_end := public.resolve_contract_effective_end(p_contract);

  for v_line in
    select *
    from public.contract_lines cl
    where cl.contract_id = p_contract.id
      and cl.tenant_id = p_contract.tenant_id
      and cl.line_type = 'consumable'::public.contract_line_type
    order by cl.line_order, cl.id
  loop
    select *
    into v_outstanding
    from public.calendar_events ce
    where ce.tenant_id = p_contract.tenant_id
      and ce.contract_id = p_contract.id
      and ce.contract_line_id = v_line.id
      and ce.type = 'refill_due'::public.calendar_event_type
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.status = 'pending'::public.calendar_event_status
    for update;

    if found then
      if public.calendar_event_is_regen_safe(v_outstanding.id)
        and coalesce(v_outstanding.source_metadata ->> 'action_kind', 'refill') = 'refill' then
        select p.name_ar, p.name_en
        into v_product_name_ar, v_product_name_en
        from public.contract_oil_changes coc
        join public.products p
          on p.id = coc.oil_product_id
          and p.tenant_id = coc.tenant_id
        where coc.contract_line_id = v_line.id
          and coc.tenant_id = p_contract.tenant_id
          and coc.effective_from <= v_outstanding.scheduled_date
          and (coc.effective_to is null or coc.effective_to >= v_outstanding.scheduled_date)
        order by coc.effective_from desc, coc.created_at desc, coc.id desc
        limit 1;

        perform public.upsert_contract_calendar_event(
          p_contract.tenant_id,
          p_contract.id,
          p_contract.customer_id,
          p_contract.service_location_id,
          v_line.id,
          'refill_due'::public.calendar_event_type,
          v_outstanding.scheduled_date,
          v_outstanding.source_key,
          coalesce(v_outstanding.source_metadata, '{}'::jsonb)
            || jsonb_build_object('action_kind', 'refill'),
          'تعبئة — ' || coalesce(v_product_name_ar, ''),
          'Refill — ' || coalesce(v_product_name_en, ''),
          array[1440, 60]
        );
      end if;
      continue;
    end if;

    select ce.*
    into v_predecessor
    from public.calendar_events ce
    left join public.calendar_refill_execution_facts f
      on f.tenant_id = ce.tenant_id
      and f.calendar_event_id = ce.id
    where ce.tenant_id = p_contract.tenant_id
      and ce.contract_id = p_contract.id
      and ce.contract_line_id = v_line.id
      and ce.type = 'refill_due'::public.calendar_event_type
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.status = 'done'::public.calendar_event_status
    order by f.actual_completion_date desc nulls last, ce.scheduled_date desc, ce.id desc
    limit 1
    for update of ce;

    if found then
      select *
      into v_fact
      from public.calendar_refill_execution_facts f
      where f.tenant_id = p_contract.tenant_id
        and f.calendar_event_id = v_predecessor.id
      for update;

      if not found then
        -- A done event without confirmed execution facts must never advance
        -- the cadence or fall through into Rule 0 / initial generation.
        continue;
      end if;

      if exists (
        select 1
        from public.calendar_events ce
        where ce.tenant_id = v_fact.tenant_id
          and ce.generated_from_execution_fact_id = v_fact.id
      ) then
        -- The fact is already consumed, even if that successor was later
        -- cancelled. Do not create an unrelated replacement implicitly.
        continue;
      end if;

        select
          coc.id,
          coc.effective_from,
          coc.oil_product_id,
          coc.qty_per_refill,
          p.name_ar,
          p.name_en
        into v_queued
        from public.contract_oil_changes coc
        join public.products p
          on p.id = coc.oil_product_id
          and p.tenant_id = coc.tenant_id
        where coc.tenant_id = p_contract.tenant_id
          and coc.contract_line_id = v_line.id
          and coc.calendar_queued_after_event_id = v_predecessor.id
          and coc.calendar_materialization_status = 'queued'
        order by coc.effective_from, coc.id
        limit 1
        for update of coc;

        if v_queued.id is not null then
          v_anchor := v_queued.effective_from;
          v_source_key := public.build_contract_calendar_source_key(
            p_contract.id,
            'refill_queued',
            v_line.id,
            null,
            null,
            v_queued.id
          );
          v_metadata := jsonb_build_object(
            'action_kind', 'refill_with_consumable_change',
            'contract_oil_change_id', v_queued.id,
            'oil_product_id', v_queued.oil_product_id,
            'qty_per_refill', v_queued.qty_per_refill::text
          );
          v_title_ar := 'تعبئة مع تغيير مستهلك — ' || coalesce(v_queued.name_ar, '');
          v_title_en := 'Refill with consumable change — ' || coalesce(v_queued.name_en, '');

          v_event_id := public.create_contract_refill_calendar_event(
            p_contract.tenant_id,
            p_contract.id,
            p_contract.customer_id,
            p_contract.service_location_id,
            v_line.id,
            v_anchor,
            v_source_key,
            v_metadata,
            v_title_ar,
            v_title_en,
            array[1440, 60],
            v_fact.id
          );

          update public.contract_oil_changes coc
          set
            calendar_materialization_status = 'materialized',
            calendar_event_id = v_event_id
          where coc.id = v_queued.id;

          v_count := v_count + 1;
          continue;
        end if;

        if v_fact.confirmed_next_due_date is not null
          and (v_effective_end is null or v_fact.confirmed_next_due_date <= v_effective_end) then
          v_source_key := public.build_contract_calendar_source_key(
            p_contract.id,
            'refill_from_fact',
            v_line.id,
            null,
            null,
            v_fact.id
          );

          select p.name_ar, p.name_en
          into v_product_name_ar, v_product_name_en
          from public.contract_oil_changes coc
          join public.products p
            on p.id = coc.oil_product_id
            and p.tenant_id = coc.tenant_id
          where coc.contract_line_id = v_line.id
            and coc.tenant_id = p_contract.tenant_id
            and coc.effective_from <= v_fact.confirmed_next_due_date
            and (coc.effective_to is null or coc.effective_to >= v_fact.confirmed_next_due_date)
          order by coc.effective_from desc, coc.created_at desc, coc.id desc
          limit 1;

          v_metadata := jsonb_build_object('action_kind', 'refill');

          perform public.create_contract_refill_calendar_event(
            p_contract.tenant_id,
            p_contract.id,
            p_contract.customer_id,
            p_contract.service_location_id,
            v_line.id,
            v_fact.confirmed_next_due_date,
            v_source_key,
            v_metadata,
            'تعبئة — ' || coalesce(v_product_name_ar, ''),
            'Refill — ' || coalesce(v_product_name_en, ''),
            array[1440, 60],
            v_fact.id
          );
          v_count := v_count + 1;
          continue;
        end if;

      -- A confirmed predecessor with no eligible successor date is still a
      -- terminal chain decision for this sync; never fall through to Rule 0.
      continue;
    end if;

    -- Rule 0: materialize earliest eligible oil change before initial cadence.
    select
      coc.id,
      coc.effective_from,
      coc.oil_product_id,
      coc.qty_per_refill,
      p.name_ar,
      p.name_en
    into v_oil
    from public.contract_oil_changes coc
    join public.products p
      on p.id = coc.oil_product_id
      and p.tenant_id = coc.tenant_id
    where coc.tenant_id = p_contract.tenant_id
      and coc.contract_line_id = v_line.id
      and (
        coc.calendar_materialization_status is null
        or coc.calendar_materialization_status = 'queued'
      )
    order by coc.effective_from, coc.created_at, coc.id
    limit 1
    for update of coc;

    if v_oil.id is not null then
      v_source_key := public.build_contract_calendar_source_key(
        p_contract.id,
        'refill_oil_change',
        v_line.id,
        null,
        null,
        v_oil.id
      );
      v_metadata := jsonb_build_object(
        'action_kind', 'consumable_change',
        'contract_oil_change_id', v_oil.id,
        'oil_product_id', v_oil.oil_product_id,
        'qty_per_refill', v_oil.qty_per_refill::text
      );

      v_event_id := public.create_contract_refill_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        v_line.id,
        v_oil.effective_from,
        v_source_key,
        v_metadata,
        'تغيير مستهلك — ' || coalesce(v_oil.name_ar, ''),
        'Consumable change — ' || coalesce(v_oil.name_en, ''),
        array[1440, 60],
        null
      );

      update public.contract_oil_changes coc
      set
        calendar_materialization_status = 'materialized',
        calendar_event_id = v_event_id
      where coc.id = v_oil.id;

      v_count := v_count + 1;
      continue;
    end if;

    v_freq := greatest(coalesce(v_line.refill_frequency_months, 1), 1);
    v_anchor := public.compute_first_cadence_date_on_or_after(
      p_contract.start_date,
      v_freq,
      p_contract.refill_day,
      p_v_today
    );

    if v_anchor is null
      or (v_effective_end is not null and v_anchor > v_effective_end) then
      continue;
    end if;

    v_source_key := public.build_contract_calendar_source_key(
      p_contract.id,
      'refill_initial',
      v_line.id,
      null,
      null,
      null
    );

    select p.name_ar, p.name_en
    into v_product_name_ar, v_product_name_en
    from public.contract_oil_changes coc
    join public.products p
      on p.id = coc.oil_product_id
      and p.tenant_id = coc.tenant_id
    where coc.contract_line_id = v_line.id
      and coc.tenant_id = p_contract.tenant_id
      and coc.effective_from <= v_anchor
      and (coc.effective_to is null or coc.effective_to >= v_anchor)
    order by coc.effective_from desc, coc.created_at desc, coc.id desc
    limit 1;

    perform public.upsert_contract_calendar_event(
      p_contract.tenant_id,
      p_contract.id,
      p_contract.customer_id,
      p_contract.service_location_id,
      v_line.id,
      'refill_due'::public.calendar_event_type,
      v_anchor,
      v_source_key,
      jsonb_build_object('action_kind', 'refill'),
      'تعبئة — ' || coalesce(v_product_name_ar, ''),
      'Refill — ' || coalesce(v_product_name_en, ''),
      array[1440, 60]
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section K: Billing + trial/contract-end planners
-- ---------------------------------------------------------------------------
create or replace function public.sync_contract_billing_events_internal(
  p_contract public.contracts,
  p_policy public.first_rental_invoice_policy,
  p_horizon_end date,
  p_v_today date
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  v_effective_end date;
  v_month_start date;
  v_scheduled date;
  v_coverage_month_key date;
  v_billing_day int;
begin
  if p_contract.type <> 'rental'::public.contract_type
    or p_contract.status <> 'active'::public.contract_status
    or p_contract.billing_day is null
    or p_policy = 'manual'::public.first_rental_invoice_policy then
    return 0;
  end if;

  v_effective_end := public.resolve_contract_effective_end(p_contract);
  v_billing_day := p_contract.billing_day;

  if p_policy = 'on_activation'::public.first_rental_invoice_policy then
    if p_contract.start_date >= p_v_today
      and p_contract.start_date <= p_horizon_end
      and (v_effective_end is null or p_contract.start_date <= v_effective_end)
      and not exists (
        select 1
        from public.rental_invoice_coverages ric
        where ric.tenant_id = p_contract.tenant_id
          and ric.contract_id = p_contract.id
          and ric.coverage_month_key = date_trunc('month', p_contract.start_date)::date
      ) then
      v_coverage_month_key := date_trunc('month', p_contract.start_date)::date;
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'billing_due'::public.calendar_event_type,
        p_contract.start_date,
        public.build_contract_calendar_source_key(
          p_contract.id, 'billing', null, null, v_coverage_month_key
        ),
        jsonb_build_object(
          'coverage_month_key', to_char(v_coverage_month_key, 'YYYY-MM-DD'),
          'billing_day', v_billing_day
        ),
        'استحقاق فوترة — ' || p_contract.contract_number,
        'Billing due — ' || p_contract.contract_number,
        array[1440, 60]
      );
      v_count := v_count + 1;
    end if;
    v_month_start := (date_trunc('month', p_contract.start_date) + interval '1 month')::date;
  else
    v_month_start := date_trunc('month', p_contract.start_date)::date;
  end if;

  while v_month_start <= p_horizon_end loop
    v_coverage_month_key := date_trunc('month', v_month_start)::date;
    v_scheduled := public.calendar_make_day_in_month(v_month_start, v_billing_day);

    if v_scheduled >= p_contract.start_date
      and v_scheduled >= p_v_today
      and v_scheduled <= p_horizon_end
      and (v_effective_end is null or v_scheduled <= v_effective_end)
      and not exists (
        select 1
        from public.rental_invoice_coverages ric
        where ric.tenant_id = p_contract.tenant_id
          and ric.contract_id = p_contract.id
          and ric.coverage_month_key = v_coverage_month_key
      ) then
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'billing_due'::public.calendar_event_type,
        v_scheduled,
        public.build_contract_calendar_source_key(
          p_contract.id, 'billing', null, null, v_coverage_month_key
        ),
        jsonb_build_object(
          'coverage_month_key', to_char(v_coverage_month_key, 'YYYY-MM-DD'),
          'billing_day', v_billing_day
        ),
        'استحقاق فوترة — ' || p_contract.contract_number,
        'Billing due — ' || p_contract.contract_number,
        array[1440, 60]
      );
      v_count := v_count + 1;
    end if;

    v_month_start := (v_month_start + interval '1 month')::date;
  end loop;

  return v_count;
end;
$$;

create or replace function public.sync_contract_trial_and_end_events_internal(
  p_contract public.contracts,
  p_horizon_end date,
  p_v_today date
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  v_effective_end date;
  v_legacy_key text;
  v_versioned_key text;
  v_existing_id uuid;
begin
  v_effective_end := public.resolve_contract_effective_end(p_contract);

  if p_contract.type = 'trial'::public.contract_type
    and p_contract.status in ('active'::public.contract_status, 'suspended'::public.contract_status)
    and p_contract.trial_end_date is not null
    and p_contract.returned_at is null
    and p_contract.closed_at is null
    and p_contract.converted_to_contract_id is null
    and p_contract.trial_end_date >= p_v_today
    and p_contract.trial_end_date <= p_horizon_end then
    v_legacy_key := public.build_contract_calendar_source_key(
      p_contract.id, 'trial_ending', null, null, null
    );
    v_versioned_key := public.build_contract_calendar_source_key(
      p_contract.id,
      'trial_ending_versioned',
      null,
      p_contract.trial_end_date,
      null
    );

    select ce.id
    into v_existing_id
    from public.calendar_events ce
    where ce.tenant_id = p_contract.tenant_id
      and ce.contract_id = p_contract.id
      and ce.type = 'trial_ending'::public.calendar_event_type
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.status = 'pending'::public.calendar_event_status
      and ce.source_key = v_legacy_key
      and ce.original_due_date = p_contract.trial_end_date
    limit 1;

    if v_existing_id is not null then
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'trial_ending'::public.calendar_event_type,
        p_contract.trial_end_date,
        v_legacy_key,
        '{}'::jsonb,
        'انتهاء التجربة — ' || p_contract.contract_number,
        'Trial ending — ' || p_contract.contract_number,
        array[10080, 1440, 60]
      );
    elsif exists (
      select 1
      from public.calendar_events ce
      where ce.tenant_id = p_contract.tenant_id
        and ce.contract_id = p_contract.id
        and ce.type = 'trial_ending'::public.calendar_event_type
        and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
        and ce.status = 'pending'::public.calendar_event_status
        and ce.original_due_date = p_contract.trial_end_date
        and ce.source_key = v_versioned_key
    ) then
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'trial_ending'::public.calendar_event_type,
        p_contract.trial_end_date,
        v_versioned_key,
        '{}'::jsonb,
        'انتهاء التجربة — ' || p_contract.contract_number,
        'Trial ending — ' || p_contract.contract_number,
        array[10080, 1440, 60]
      );
    elsif exists (
      select 1
      from public.calendar_events ce
      where ce.tenant_id = p_contract.tenant_id
        and ce.contract_id = p_contract.id
        and ce.type = 'trial_ending'::public.calendar_event_type
        and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
        and ce.status = 'pending'::public.calendar_event_status
        and ce.original_due_date is distinct from p_contract.trial_end_date
    ) then
      update public.calendar_events ce
      set
        status = 'cancelled'::public.calendar_event_status,
        source_metadata = ce.source_metadata || jsonb_build_object(
          'cancellation_reason', 'trial_extended'
        )
      where ce.tenant_id = p_contract.tenant_id
        and ce.contract_id = p_contract.id
        and ce.type = 'trial_ending'::public.calendar_event_type
        and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
        and ce.status = 'pending'::public.calendar_event_status;

      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'trial_ending'::public.calendar_event_type,
        p_contract.trial_end_date,
        v_versioned_key,
        '{}'::jsonb,
        'انتهاء التجربة — ' || p_contract.contract_number,
        'Trial ending — ' || p_contract.contract_number,
        array[10080, 1440, 60]
      );
    else
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'trial_ending'::public.calendar_event_type,
        p_contract.trial_end_date,
        v_versioned_key,
        '{}'::jsonb,
        'انتهاء التجربة — ' || p_contract.contract_number,
        'Trial ending — ' || p_contract.contract_number,
        array[10080, 1440, 60]
      );
    end if;
    v_count := v_count + 1;
  end if;

  if p_contract.type = 'rental'::public.contract_type
    and p_contract.end_date is not null
    and p_contract.status in ('active'::public.contract_status, 'suspended'::public.contract_status)
    and p_contract.end_date >= p_v_today
    and p_contract.end_date <= p_horizon_end
    and (v_effective_end is null or p_contract.end_date <= v_effective_end) then
    v_legacy_key := public.build_contract_calendar_source_key(
      p_contract.id, 'contract_end', null, null, null
    );
    v_versioned_key := public.build_contract_calendar_source_key(
      p_contract.id,
      'contract_end_versioned',
      null,
      p_contract.end_date,
      null
    );

    select ce.id
    into v_existing_id
    from public.calendar_events ce
    where ce.tenant_id = p_contract.tenant_id
      and ce.contract_id = p_contract.id
      and ce.type = 'contract_end'::public.calendar_event_type
      and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and ce.status = 'pending'::public.calendar_event_status
      and ce.source_key = v_legacy_key
      and ce.original_due_date = p_contract.end_date
    limit 1;

    if v_existing_id is not null then
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'contract_end'::public.calendar_event_type,
        p_contract.end_date,
        v_legacy_key,
        '{}'::jsonb,
        'انتهاء العقد — ' || p_contract.contract_number,
        'Contract end — ' || p_contract.contract_number,
        array[10080, 1440, 60]
      );
    elsif exists (
      select 1
      from public.calendar_events ce
      where ce.tenant_id = p_contract.tenant_id
        and ce.contract_id = p_contract.id
        and ce.type = 'contract_end'::public.calendar_event_type
        and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
        and ce.status = 'pending'::public.calendar_event_status
        and ce.source_key = v_versioned_key
    ) then
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'contract_end'::public.calendar_event_type,
        p_contract.end_date,
        v_versioned_key,
        '{}'::jsonb,
        'انتهاء العقد — ' || p_contract.contract_number,
        'Contract end — ' || p_contract.contract_number,
        array[10080, 1440, 60]
      );
    elsif exists (
      select 1
      from public.calendar_events ce
      where ce.tenant_id = p_contract.tenant_id
        and ce.contract_id = p_contract.id
        and ce.type = 'contract_end'::public.calendar_event_type
        and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
        and ce.status = 'pending'::public.calendar_event_status
        and ce.original_due_date is distinct from p_contract.end_date
    ) then
      update public.calendar_events ce
      set
        status = 'cancelled'::public.calendar_event_status,
        source_metadata = ce.source_metadata || jsonb_build_object(
          'cancellation_reason', 'contract_end_changed'
        )
      where ce.tenant_id = p_contract.tenant_id
        and ce.contract_id = p_contract.id
        and ce.type = 'contract_end'::public.calendar_event_type
        and ce.source_kind = 'contract_generated'::public.calendar_event_source_kind
        and ce.status = 'pending'::public.calendar_event_status;

      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'contract_end'::public.calendar_event_type,
        p_contract.end_date,
        v_versioned_key,
        '{}'::jsonb,
        'انتهاء العقد — ' || p_contract.contract_number,
        'Contract end — ' || p_contract.contract_number,
        array[10080, 1440, 60]
      );
    else
      perform public.upsert_contract_calendar_event(
        p_contract.tenant_id,
        p_contract.id,
        p_contract.customer_id,
        p_contract.service_location_id,
        null,
        'contract_end'::public.calendar_event_type,
        p_contract.end_date,
        v_versioned_key,
        '{}'::jsonb,
        'انتهاء العقد — ' || p_contract.contract_number,
        'Contract end — ' || p_contract.contract_number,
        array[10080, 1440, 60]
      );
    end if;
    v_count := v_count + 1;
  end if;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Section L: Sync entry/core split
-- ---------------------------------------------------------------------------
create or replace function public.sync_contract_calendar_events_core_internal(
  p_contract_id uuid,
  p_horizon_days int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contract public.contracts%rowtype;
  v_policy public.first_rental_invoice_policy;
  v_horizon_days int;
  v_horizon_end date;
  v_v_today date;
  v_billing int := 0;
  v_refill int := 0;
  v_trial_end int := 0;
  v_effective_end date;
begin
  v_horizon_days := coalesce(
    p_horizon_days,
    public.calendar_default_horizon_days()
  );
  if v_horizon_days < 1 or v_horizon_days > public.calendar_max_horizon_days() then
    raise exception 'validation_failed';
  end if;

  select *
  into v_contract
  from public.contracts c
  where c.id = p_contract_id
  for update;

  if not found then
    raise exception 'validation_failed';
  end if;

  if v_contract.status not in (
    'active'::public.contract_status,
    'suspended'::public.contract_status
  ) then
    return jsonb_build_object('skipped', true, 'reason', 'inactive_status');
  end if;

  v_v_today := public.try_tenant_local_today(v_contract.tenant_id);
  if v_v_today is null then
    return jsonb_build_object('skipped', true, 'reason', 'calendar_setup_required');
  end if;

  v_horizon_end := v_v_today + v_horizon_days;
  v_effective_end := public.resolve_contract_effective_end(v_contract);

  if v_effective_end is not null and v_effective_end < v_v_today then
    return jsonb_build_object('skipped', true, 'reason', 'past_effective_end');
  end if;

  select ts.first_rental_invoice_policy
  into v_policy
  from public.tenant_settings ts
  where ts.tenant_id = v_contract.tenant_id;

  v_policy := coalesce(v_policy, 'first_billing_day'::public.first_rental_invoice_policy);

  v_trial_end := public.sync_contract_trial_and_end_events_internal(
    v_contract,
    v_horizon_end,
    v_v_today
  );

  if v_contract.type = 'rental'::public.contract_type
    and v_contract.status = 'active'::public.contract_status then
    v_billing := public.sync_contract_billing_events_internal(
      v_contract,
      v_policy,
      v_horizon_end,
      v_v_today
    );
    v_refill := public.sync_contract_refill_chain_internal(v_contract, v_v_today);
  end if;

  return jsonb_build_object(
    'contract_id', v_contract.id,
    'horizon_days', v_horizon_days,
    'billing_upserts', v_billing,
    'refill_upserts', v_refill,
    'trial_end_upserts', v_trial_end
  );
end;
$$;

create or replace function public.sync_contract_calendar_events_entry_internal(
  p_contract_id uuid,
  p_horizon_days int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  select c.tenant_id
  into v_tenant_id
  from public.contracts c
  where c.id = p_contract_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if not public.calendar_timezone_ready(v_tenant_id) then
    return jsonb_build_object(
      'skipped', true,
      'reason', 'calendar_setup_required',
      'contract_id', p_contract_id
    );
  end if;

  perform public.reconcile_deferred_calendar_lifecycle_ops(v_tenant_id, p_contract_id);

  return public.sync_contract_calendar_events_core_internal(p_contract_id, p_horizon_days);
end;
$$;

create or replace function public.sync_contract_calendar_events_internal(
  p_contract_id uuid,
  p_horizon_days int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.sync_contract_calendar_events_entry_internal(p_contract_id, p_horizon_days);
end;
$$;

-- ---------------------------------------------------------------------------
-- Section M: Execution-fact linkage trigger
-- ---------------------------------------------------------------------------
create or replace function public.enforce_calendar_event_execution_fact_linkage()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parsed record;
  v_fact public.calendar_refill_execution_facts%rowtype;
  v_predecessor public.calendar_events%rowtype;
  v_oil public.contract_oil_changes%rowtype;
  v_metadata_oil_id uuid;
  v_replaced_event_id uuid;
begin
  if new.generated_from_execution_fact_id is not null
    and new.source_kind <> 'contract_generated'::public.calendar_event_source_kind then
    raise exception 'validation_failed';
  end if;

  if new.source_kind <> 'contract_generated'::public.calendar_event_source_kind then
    return new;
  end if;

  if public.calendar_event_source_requires_execution_fact(new.source_key) then
    if new.generated_from_execution_fact_id is null then
      raise exception 'validation_failed';
    end if;
  elsif new.generated_from_execution_fact_id is not null then
    raise exception 'validation_failed';
  end if;

  if new.type = 'refill_due'::public.calendar_event_type
    and new.source_key is not null
    and new.source_key ~ '^contract:[0-9a-f-]{36}:refill:' then
    select *
    into v_parsed
    from public.parse_calendar_refill_source_key(new.source_key) p
    limit 1;

    if v_parsed.contract_id is null
      or v_parsed.contract_id is distinct from new.contract_id
      or v_parsed.contract_line_id is distinct from new.contract_line_id then
      raise exception 'validation_failed';
    end if;

    if v_parsed.kind = 'from_fact' then
      if v_parsed.tail_uuid is distinct from new.generated_from_execution_fact_id then
        raise exception 'validation_failed';
      end if;
    elsif v_parsed.kind = 'queued' then
      if new.generated_from_execution_fact_id is null then
        raise exception 'validation_failed';
      end if;

      select *
      into v_oil
      from public.contract_oil_changes coc
      where coc.id = v_parsed.tail_uuid
        and coc.tenant_id = new.tenant_id
        and coc.contract_line_id = new.contract_line_id;

      if not found
        or v_oil.calendar_materialization_status not in ('queued', 'materialized') then
        raise exception 'validation_failed';
      end if;

      select *
      into v_fact
      from public.calendar_refill_execution_facts f
      where f.tenant_id = new.tenant_id
        and f.id = new.generated_from_execution_fact_id;

      if not found then
        raise exception 'validation_failed';
      end if;

      select *
      into v_predecessor
      from public.calendar_events ce
      where ce.id = v_fact.calendar_event_id
        and ce.tenant_id = new.tenant_id;

      if not found
        or v_oil.calendar_queued_after_event_id is distinct from v_predecessor.id then
        raise exception 'validation_failed';
      end if;
    elsif v_parsed.kind in ('replacement', 'oil_change') then
      v_metadata_oil_id := nullif(new.source_metadata ->> 'contract_oil_change_id', '')::uuid;
      if v_parsed.tail_uuid is distinct from v_metadata_oil_id
        and coalesce(new.source_metadata ->> 'action_kind', '')
          <> 'refill_with_consumable_change' then
        raise exception 'validation_failed';
      end if;
    elsif v_parsed.kind = 'reactivation' then
      v_replaced_event_id := nullif(new.source_metadata ->> 'replaces_event_id', '')::uuid;
      if v_parsed.tail_uuid is distinct from v_replaced_event_id then
        raise exception 'validation_failed';
      end if;
    end if;
  end if;

  if new.generated_from_execution_fact_id is not null then
    select *
    into v_fact
    from public.calendar_refill_execution_facts f
    where f.tenant_id = new.tenant_id
      and f.id = new.generated_from_execution_fact_id;

    if not found then
      raise exception 'validation_failed';
    end if;

    if new.type <> 'refill_due'::public.calendar_event_type then
      raise exception 'validation_failed';
    end if;

    if v_fact.tenant_id is distinct from new.tenant_id
      or v_fact.contract_id is distinct from new.contract_id
      or v_fact.contract_line_id is distinct from new.contract_line_id then
      raise exception 'validation_failed';
    end if;

    select *
    into v_predecessor
    from public.calendar_events ce
    where ce.id = v_fact.calendar_event_id
      and ce.tenant_id = new.tenant_id;

    if not found
      or v_predecessor.status <> 'done'::public.calendar_event_status
      or v_predecessor.type <> 'refill_due'::public.calendar_event_type then
      raise exception 'validation_failed';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_calendar_events_execution_fact_linkage on public.calendar_events;
create trigger trg_calendar_events_execution_fact_linkage
  before insert or update on public.calendar_events
  for each row
  execute function public.enforce_calendar_event_execution_fact_linkage();

-- ---------------------------------------------------------------------------
-- Section N: Batch generation + trusted tenant sync
-- ---------------------------------------------------------------------------
create or replace function public.sync_tenant_calendar_events_internal_trusted(
  p_tenant_id uuid,
  p_horizon_days int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_horizon int;
  v_contract_id uuid;
  v_synced int := 0;
  v_skipped_setup int := 0;
  v_results jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if not public.calendar_timezone_ready(p_tenant_id) then
    return jsonb_build_object(
      'tenant_id', p_tenant_id,
      'skipped', true,
      'reason', 'calendar_setup_required'
    );
  end if;

  v_horizon := coalesce(p_horizon_days, public.calendar_default_horizon_days());
  if v_horizon < 1 or v_horizon > public.calendar_max_horizon_days() then
    raise exception 'validation_failed';
  end if;

  perform public.reconcile_deferred_calendar_lifecycle_ops(p_tenant_id, null);

  for v_contract_id in
    select c.id
    from public.contracts c
    where c.tenant_id = p_tenant_id
      and c.status in ('active'::public.contract_status, 'suspended'::public.contract_status)
      and c.closed_at is null
      and c.returned_at is null
  loop
    v_result := public.sync_contract_calendar_events_entry_internal(v_contract_id, v_horizon);
    v_results := v_results || v_result;
    if coalesce(v_result ->> 'skipped', 'false') = 'true'
      and v_result ->> 'reason' = 'calendar_setup_required' then
      v_skipped_setup := v_skipped_setup + 1;
    else
      v_synced := v_synced + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'horizon_days', v_horizon,
    'contracts_synced', v_synced,
    'contracts_skipped_setup', v_skipped_setup,
    'results', v_results
  );
end;
$$;

create or replace function public.sync_tenant_contract_calendar_events(
  p_horizon_days int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_horizon int;
  v_contract_id uuid;
  v_synced int := 0;
  v_skipped_setup boolean := false;
  v_results jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;
  if not public.user_has_permission('calendar.edit') then
    raise exception 'permission_denied';
  end if;

  if not public.calendar_timezone_ready(v_tenant_id) then
    return jsonb_build_object(
      'tenant_id', v_tenant_id,
      'skipped', true,
      'reason', 'calendar_setup_required'
    );
  end if;

  v_horizon := coalesce(p_horizon_days, public.calendar_default_horizon_days());
  if v_horizon < 1 or v_horizon > public.calendar_max_horizon_days() then
    raise exception 'validation_failed';
  end if;

  for v_contract_id in
    select c.id
    from public.contracts c
    where c.tenant_id = v_tenant_id
      and c.status in ('active'::public.contract_status, 'suspended'::public.contract_status)
      and c.closed_at is null
      and c.returned_at is null
  loop
    v_result := public.sync_contract_calendar_events_entry_internal(v_contract_id, v_horizon);
    v_results := v_results || v_result;
    if coalesce(v_result ->> 'skipped', 'false') = 'true'
      and v_result ->> 'reason' = 'calendar_setup_required' then
      v_skipped_setup := true;
    else
      v_synced := v_synced + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'tenant_id', v_tenant_id,
    'horizon_days', v_horizon,
    'contracts_synced', v_synced,
    'skipped', v_skipped_setup,
    'reason', case when v_skipped_setup then 'calendar_setup_required' else null end,
    'results', v_results
  );
end;
$$;

create or replace function public.run_scheduled_calendar_generation(
  p_horizon_days int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_horizon int;
  v_run_id uuid;
  v_tenant record;
  v_tenants_total int := 0;
  v_tenants_completed int := 0;
  v_tenants_failed int := 0;
  v_tenants_skipped_setup int := 0;
  v_contracts_synced int;
  v_result jsonb;
  v_error_summary text;
begin
  if not pg_try_advisory_xact_lock(hashtext('calendar_generation_batch')) then
    return jsonb_build_object('status', 'skipped_duplicate');
  end if;

  v_horizon := coalesce(p_horizon_days, public.calendar_default_horizon_days());
  if v_horizon < 1 or v_horizon > public.calendar_max_horizon_days() then
    raise exception 'validation_failed';
  end if;

  insert into public.calendar_generation_runs (
    horizon_days,
    status
  )
  values (
    v_horizon,
    'running'
  )
  returning id into v_run_id;

  for v_tenant in
    select t.id
    from public.tenants t
    order by t.id
  loop
    v_tenants_total := v_tenants_total + 1;
    v_contracts_synced := 0;

    begin
      if not public.calendar_timezone_ready(v_tenant.id) then
        insert into public.calendar_generation_run_tenants (
          run_id,
          tenant_id,
          status,
          contracts_synced
        )
        values (
          v_run_id,
          v_tenant.id,
          'skipped_calendar_setup_required',
          0
        );
        v_tenants_skipped_setup := v_tenants_skipped_setup + 1;
        continue;
      end if;

      v_result := public.sync_tenant_calendar_events_internal_trusted(v_tenant.id, v_horizon);
      v_contracts_synced := coalesce((v_result ->> 'contracts_synced')::int, 0);

      insert into public.calendar_generation_run_tenants (
        run_id,
        tenant_id,
        status,
        contracts_synced
      )
      values (
        v_run_id,
        v_tenant.id,
        'completed',
        v_contracts_synced
      );
      v_tenants_completed := v_tenants_completed + 1;

    exception
      when others then
        insert into public.calendar_generation_run_tenants (
          run_id,
          tenant_id,
          status,
          contracts_synced,
          error_code
        )
        values (
          v_run_id,
          v_tenant.id,
          'failed',
          0,
          public.sanitize_sql_error_code(sqlstate)
        );
        v_tenants_failed := v_tenants_failed + 1;
    end;
  end loop;

  v_error_summary := case
    when v_tenants_failed > 0 then format('tenants_failed=%s', v_tenants_failed)
    else null
  end;

  update public.calendar_generation_runs r
  set
    completed_at = clock_timestamp(),
    status = case
      when v_tenants_failed > 0 and v_tenants_completed > 0 then 'partial'
      when v_tenants_failed > 0 then 'failed'
      else 'completed'
    end,
    tenants_total = v_tenants_total,
    tenants_completed = v_tenants_completed,
    tenants_failed = v_tenants_failed,
    tenants_skipped_setup = v_tenants_skipped_setup,
    error_summary = v_error_summary
  where r.id = v_run_id;

  return jsonb_build_object(
    'run_id', v_run_id,
    'status', (
      select gr.status
      from public.calendar_generation_runs gr
      where gr.id = v_run_id
    ),
    'tenants_total', v_tenants_total,
    'tenants_completed', v_tenants_completed,
    'tenants_failed', v_tenants_failed,
    'tenants_skipped_setup', v_tenants_skipped_setup
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Section O: Lifecycle handoff + drop legacy planners
-- ---------------------------------------------------------------------------
create or replace function public.handle_contract_status_calendar_handoff()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'suspended'::public.contract_status then
    perform public.suspend_contract_generated_events(new.id);
  elsif old.status = 'suspended'::public.contract_status
    and new.status = 'active'::public.contract_status then
    if not public.calendar_timezone_ready(new.tenant_id) then
      perform public.enqueue_calendar_deferred_lifecycle(
        new.tenant_id,
        new.id,
        'reactivate'
      );
    else
      perform public.reconcile_deferred_reactivation(
        new.id,
        public.try_tenant_local_today(new.tenant_id)
      );
      perform public.sync_contract_calendar_events_core_internal(
        new.id,
        public.calendar_default_horizon_days()
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_contracts_status_calendar_handoff on public.contracts;
create trigger trg_contracts_status_calendar_handoff
  after update of status on public.contracts
  for each row
  when (old.status is distinct from new.status)
  execute function public.handle_contract_status_calendar_handoff();

drop function if exists public.purge_suspended_contract_billing_refill_events(uuid);
drop function if exists public.sync_contract_refill_events_internal(public.contracts, date);

-- ---------------------------------------------------------------------------
-- Section P: ACL + consumable-change lifecycle patch
-- ---------------------------------------------------------------------------
do $$
declare
  v_sql text;
begin
  select pg_get_functiondef(
    'public.schedule_contract_consumable_change(jsonb, uuid)'::regprocedure
  ) into v_sql;
  perform public.m12_assert_single_anchor(
    v_sql,
    E'  perform public.sync_contract_calendar_events_internal(v_contract.id, public.calendar_default_horizon_days());\n',
    'schedule_contract_consumable_change'
  );
  v_sql := replace(
    v_sql,
    E'  perform public.sync_contract_calendar_events_internal(v_contract.id, public.calendar_default_horizon_days());\n',
    E'  perform public.apply_consumable_change_to_calendar((\n    select coc.id\n    from public.contract_oil_changes coc\n    where coc.tenant_id = v_tenant_id\n      and coc.contract_line_id = v_line.id\n    order by coc.effective_from desc, coc.created_at desc, coc.id desc\n    limit 1\n  ));\n'
  );
  execute v_sql;
end $$;

revoke all on function public.merge_calendar_event_metadata_safe(jsonb, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.sanitize_sql_error_code(text)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_timezone_ready(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.try_tenant_local_today(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.calendar_event_is_regen_safe(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.compute_first_cadence_date_on_or_after(date, int, int, date)
  from public, anon, authenticated, service_role;
revoke all on function public.build_contract_calendar_source_key(
  uuid, text, uuid, date, date, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.calendar_event_source_requires_execution_fact(text)
  from public, anon, authenticated, service_role;
revoke all on function public.parse_calendar_refill_source_key(text)
  from public, anon, authenticated, service_role;
revoke all on function public.upsert_contract_calendar_event_recorded(
  uuid, uuid, uuid, uuid, uuid, public.calendar_event_type, date, text, jsonb, text, text, int[]
) from public, anon, authenticated, service_role;
revoke all on function public.create_contract_refill_calendar_event(
  uuid, uuid, uuid, uuid, uuid, date, text, jsonb, text, text, int[], uuid
) from public, anon, authenticated, service_role;
revoke all on function public.enqueue_calendar_deferred_lifecycle(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.suspend_contract_generated_events_at_date(uuid, date)
  from public, anon, authenticated, service_role;
revoke all on function public.suspend_contract_generated_events(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.reconcile_deferred_reactivation(uuid, date)
  from public, anon, authenticated, service_role;
revoke all on function public.reconcile_deferred_calendar_lifecycle_ops(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.reinstate_suspended_calendar_events(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.apply_consumable_change_to_calendar(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.sync_contract_refill_chain_internal(public.contracts, date)
  from public, anon, authenticated, service_role;
revoke all on function public.sync_contract_trial_and_end_events_internal(public.contracts, date, date)
  from public, anon, authenticated, service_role;
revoke all on function public.sync_contract_calendar_events_core_internal(uuid, int)
  from public, anon, authenticated, service_role;
revoke all on function public.sync_contract_calendar_events_entry_internal(uuid, int)
  from public, anon, authenticated, service_role;
revoke all on function public.enforce_calendar_event_execution_fact_linkage()
  from public, anon, authenticated, service_role;
revoke all on function public.sync_tenant_calendar_events_internal_trusted(uuid, int)
  from public, anon, authenticated, service_role;
revoke all on function public.run_scheduled_calendar_generation(int)
  from public, anon, authenticated, service_role;

revoke all on function public.sync_contract_billing_events_internal(
  public.contracts, public.first_rental_invoice_policy, date, date
) from public, anon, authenticated, service_role;

grant execute on function public.run_scheduled_calendar_generation(int) to postgres;
grant execute on function public.sync_tenant_contract_calendar_events(int) to authenticated;
