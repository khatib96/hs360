-- Phase 6 M12: calendar handoff schema — provenance, tenant-safe FKs, write guards.

-- ---------------------------------------------------------------------------
-- Enum extension (must commit before use in 091)
-- ---------------------------------------------------------------------------
alter type public.calendar_event_type add value if not exists 'billing_due';

-- ---------------------------------------------------------------------------
-- Provenance + structured metadata
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'calendar_event_source_kind') then
    create type public.calendar_event_source_kind as enum ('manual', 'contract_generated');
  end if;
end $$;

alter table public.calendar_events
  add column if not exists source_kind public.calendar_event_source_kind not null default 'manual',
  add column if not exists source_key text,
  add column if not exists source_metadata jsonb not null default '{}'::jsonb,
  add column if not exists contract_line_id uuid;

alter table public.calendar_events
  drop constraint if exists chk_calendar_events_source_key_pair;

alter table public.calendar_events
  add constraint chk_calendar_events_source_key_pair check (
    (source_kind = 'manual'::public.calendar_event_source_kind and source_key is null)
    or (
      source_kind = 'contract_generated'::public.calendar_event_source_kind
      and source_key is not null
    )
  );

alter table public.calendar_events
  drop constraint if exists chk_calendar_events_source_metadata_object;

alter table public.calendar_events
  add constraint chk_calendar_events_source_metadata_object check (
    jsonb_typeof(source_metadata) = 'object'
  );

comment on column public.calendar_events.source_kind is
  'M12: manual vs contract-generated schedule provenance.';
comment on column public.calendar_events.source_key is
  'M12: deterministic idempotency key for contract-generated events only.';
comment on column public.calendar_events.source_metadata is
  'M12: whitelisted operational metadata for generated events.';

-- ---------------------------------------------------------------------------
-- Preflight audit — fail fast on orphan contract/line references
-- ---------------------------------------------------------------------------
do $$
declare
  v_orphan_contract int;
  v_orphan_line int;
begin
  select count(*)
  into v_orphan_contract
  from public.calendar_events ce
  where ce.contract_id is not null
    and not exists (
      select 1
      from public.contracts c
      where c.tenant_id = ce.tenant_id
        and c.id = ce.contract_id
    );

  if v_orphan_contract > 0 then
    raise exception 'M12 preflight failed: calendar_events contract orphan rows=%', v_orphan_contract;
  end if;

  select count(*)
  into v_orphan_line
  from public.calendar_events ce
  where ce.contract_line_id is not null
    and not exists (
      select 1
      from public.contract_lines cl
      where cl.tenant_id = ce.tenant_id
        and cl.contract_id = ce.contract_id
        and cl.id = ce.contract_line_id
    );

  if v_orphan_line > 0 then
    raise exception 'M12 preflight failed: calendar_events contract_line orphan rows=%', v_orphan_line;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Tenant-safe composite FK targets (reuse ux_contracts_tenant_id_id from 077)
-- ---------------------------------------------------------------------------
create unique index if not exists ux_contract_lines_tenant_contract_id
  on public.contract_lines (tenant_id, contract_id, id);

alter table public.calendar_events
  drop constraint if exists fk_calendar_events_tenant_contract;

alter table public.calendar_events
  add constraint fk_calendar_events_tenant_contract
  foreign key (tenant_id, contract_id)
  references public.contracts (tenant_id, id);

alter table public.calendar_events
  drop constraint if exists fk_calendar_events_tenant_contract_line;

alter table public.calendar_events
  add constraint fk_calendar_events_tenant_contract_line
  foreign key (tenant_id, contract_id, contract_line_id)
  references public.contract_lines (tenant_id, contract_id, id);

drop index if exists public.ux_calendar_events_contract_source;

create unique index ux_calendar_events_contract_source
  on public.calendar_events (tenant_id, source_key)
  where source_kind = 'contract_generated'::public.calendar_event_source_kind
    and source_key is not null;

create index if not exists idx_calevents_source_kind
  on public.calendar_events (tenant_id, source_kind, contract_id);

create index if not exists idx_calevents_contract_line
  on public.calendar_events (contract_line_id)
  where contract_line_id is not null;

-- ---------------------------------------------------------------------------
-- Provenance + metadata write guards
-- ---------------------------------------------------------------------------
create or replace function public.is_trusted_calendar_generated_writer()
returns boolean
language sql
stable
set search_path = public
as $$
  select current_user in ('postgres', 'supabase_admin');
$$;

revoke all on function public.is_trusted_calendar_generated_writer() from public, anon, authenticated;

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
    'cancellation_reason'
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

create or replace function public.enforce_calendar_event_provenance_guard()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.source_kind = 'contract_generated'::public.calendar_event_source_kind then
      if not public.is_trusted_calendar_generated_writer() then
        raise exception 'permission_denied';
      end if;
      if not public.calendar_event_metadata_is_whitelisted(new.source_metadata) then
        raise exception 'validation_failed';
      end if;
    elsif new.source_key is not null then
      raise exception 'validation_failed';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.source_kind = 'contract_generated'::public.calendar_event_source_kind
      or new.source_kind = 'contract_generated'::public.calendar_event_source_kind then
      if not public.is_trusted_calendar_generated_writer() then
        raise exception 'permission_denied';
      end if;
    end if;

    if old.source_kind = 'contract_generated'::public.calendar_event_source_kind then
      if new.source_kind is distinct from old.source_kind
        or new.source_key is distinct from old.source_key then
        raise exception 'validation_failed';
      end if;
    end if;

    if new.source_kind = 'contract_generated'::public.calendar_event_source_kind
      and not public.calendar_event_metadata_is_whitelisted(new.source_metadata) then
      raise exception 'validation_failed';
    end if;

    if new.source_kind = 'manual'::public.calendar_event_source_kind
      and new.source_key is not null then
      raise exception 'validation_failed';
    end if;

    return new;
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_calendar_events_provenance_guard on public.calendar_events;
create trigger trg_calendar_events_provenance_guard
  before insert or update on public.calendar_events
  for each row execute function public.enforce_calendar_event_provenance_guard();

create or replace function public.enforce_calendar_event_tenant_integrity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contract public.contracts%rowtype;
begin
  if new.contract_id is null then
    return new;
  end if;

  select *
  into v_contract
  from public.contracts c
  where c.tenant_id = new.tenant_id
    and c.id = new.contract_id;

  if not found then
    raise exception 'validation_failed';
  end if;

  if new.customer_id is not null and new.customer_id is distinct from v_contract.customer_id then
    raise exception 'validation_failed';
  end if;

  if new.service_location_id is not null
    and new.service_location_id is distinct from v_contract.service_location_id then
    raise exception 'validation_failed';
  end if;

  if new.contract_line_id is not null then
    if not exists (
      select 1
      from public.contract_lines cl
      where cl.tenant_id = new.tenant_id
        and cl.contract_id = new.contract_id
        and cl.id = new.contract_line_id
    ) then
      raise exception 'validation_failed';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_calendar_events_tenant_integrity on public.calendar_events;
create trigger trg_calendar_events_tenant_integrity
  before insert or update on public.calendar_events
  for each row execute function public.enforce_calendar_event_tenant_integrity();
