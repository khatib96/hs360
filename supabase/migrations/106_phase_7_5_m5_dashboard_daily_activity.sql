-- Phase 7.5 M5: permission-shaped Dashboard v1, exact KPI drill-downs,
-- and selected-business-date Daily Activity.

create index if not exists idx_contracts_tenant_created_at
  on public.contracts (tenant_id, created_at desc, id);

create index if not exists idx_contract_lifecycle_operations_tenant_created
  on public.contract_lifecycle_operations (tenant_id, created_at desc, id);

create index if not exists idx_invoices_tenant_date_created
  on public.invoices (tenant_id, date desc, created_at desc, id);

create index if not exists idx_vouchers_tenant_date_created
  on public.vouchers (tenant_id, date desc, created_at desc, id);

create index if not exists idx_visits_tenant_scheduled_created
  on public.visits (tenant_id, scheduled_date desc, created_at desc, id);

create index if not exists idx_journal_entries_tenant_date_posted
  on public.journal_entries (tenant_id, date desc, is_posted, posted_at desc, id);

-- Internal canonical row source. Summary totals and drill-down pages both read
-- this function so a visible number cannot drift from the records behind it.
create or replace function public.phase_7_5_m5_dashboard_rows(
  p_tenant_id uuid,
  p_user_id uuid,
  p_business_date date,
  p_timezone_name text,
  p_kind text default null
)
returns table (
  kind text,
  entity_id uuid,
  occurred_at timestamptz,
  title_ar text,
  title_en text,
  identifier text,
  status text,
  amount numeric,
  source_route text
)
language sql
stable
security definer
set search_path = public
as $$
  -- Today's visible calendar plan.
  select
    'today_schedule'::text,
    ce.id,
    coalesce(
      ce.scheduled_start_at,
      (ce.scheduled_date::timestamp + coalesce(ce.scheduled_time, time '00:00'))
        at time zone p_timezone_name
    ),
    coalesce(nullif(btrim(ce.title_ar), ''), replace(ce.type::text, '_', ' ')),
    coalesce(nullif(btrim(ce.title_en), ''), initcap(replace(ce.type::text, '_', ' '))),
    replace(ce.type::text, '_', ' '),
    ce.status::text,
    null::numeric,
    '/calendar?date=' || to_char(ce.scheduled_date, 'YYYY-MM-DD')
  from public.calendar_events ce
  where ce.tenant_id = p_tenant_id
    and ce.scheduled_date = p_business_date
    and (p_kind is null or p_kind = 'today_schedule')
    and public.user_has_calendar_event_visibility(p_tenant_id, p_user_id, ce.id)

  union all

  -- Completed schedule drill-down uses the exact same definition as the KPI.
  select
    'today_completed', ce.id,
    coalesce(
      ce.completed_at,
      ce.scheduled_start_at,
      (ce.scheduled_date::timestamp + coalesce(ce.scheduled_time, time '00:00'))
        at time zone p_timezone_name
    ),
    coalesce(nullif(btrim(ce.title_ar), ''), replace(ce.type::text, '_', ' ')),
    coalesce(nullif(btrim(ce.title_en), ''), initcap(replace(ce.type::text, '_', ' '))),
    replace(ce.type::text, '_', ' '), ce.status::text, null::numeric,
    '/calendar?date=' || to_char(ce.scheduled_date, 'YYYY-MM-DD')
  from public.calendar_events ce
  where ce.tenant_id = p_tenant_id
    and ce.scheduled_date = p_business_date
    and ce.status = 'done'::public.calendar_event_status
    and (p_kind is null or p_kind = 'today_completed')
    and public.user_has_calendar_event_visibility(p_tenant_id, p_user_id, ce.id)

  union all

  select
    'today_remaining', ce.id,
    coalesce(
      ce.scheduled_start_at,
      (ce.scheduled_date::timestamp + coalesce(ce.scheduled_time, time '00:00'))
        at time zone p_timezone_name
    ),
    coalesce(nullif(btrim(ce.title_ar), ''), replace(ce.type::text, '_', ' ')),
    coalesce(nullif(btrim(ce.title_en), ''), initcap(replace(ce.type::text, '_', ' '))),
    replace(ce.type::text, '_', ' '), ce.status::text, null::numeric,
    '/calendar?date=' || to_char(ce.scheduled_date, 'YYYY-MM-DD')
  from public.calendar_events ce
  where ce.tenant_id = p_tenant_id
    and ce.scheduled_date = p_business_date
    and ce.status = 'pending'::public.calendar_event_status
    and (p_kind is null or p_kind = 'today_remaining')
    and public.user_has_calendar_event_visibility(p_tenant_id, p_user_id, ce.id)

  union all

  select
    'overdue', ce.id,
    coalesce(
      ce.scheduled_start_at,
      (ce.scheduled_date::timestamp + coalesce(ce.scheduled_time, time '00:00'))
        at time zone p_timezone_name
    ),
    coalesce(nullif(btrim(ce.title_ar), ''), replace(ce.type::text, '_', ' ')),
    coalesce(nullif(btrim(ce.title_en), ''), initcap(replace(ce.type::text, '_', ' '))),
    to_char(ce.scheduled_date, 'YYYY-MM-DD'), ce.status::text, null::numeric,
    '/calendar?date=' || to_char(ce.scheduled_date, 'YYYY-MM-DD')
  from public.calendar_events ce
  where ce.tenant_id = p_tenant_id
    and ce.scheduled_date < p_business_date
    and ce.status = 'pending'::public.calendar_event_status
    and (p_kind is null or p_kind = 'overdue')
    and public.user_has_calendar_event_visibility(p_tenant_id, p_user_id, ce.id)

  union all

  select
    'active_contracts', c.id, coalesce(c.updated_at, c.created_at),
    c.contract_number, c.contract_number, c.contract_number,
    c.type::text || ':' || c.status::text, null::numeric,
    '/contracts/' || c.id::text
  from public.contracts c
  where c.tenant_id = p_tenant_id
    and c.status = 'active'::public.contract_status
    and (p_kind is null or p_kind = 'active_contracts')
    and public.user_has_permission('contracts.view')

  union all

  select
    'active_trials', c.id, coalesce(c.updated_at, c.created_at),
    c.contract_number, c.contract_number, c.contract_number,
    c.status::text, null::numeric, '/contracts/' || c.id::text
  from public.contracts c
  where c.tenant_id = p_tenant_id
    and c.type = 'trial'::public.contract_type
    and c.status = 'active'::public.contract_status
    and (p_kind is null or p_kind = 'active_trials')
    and public.user_has_permission('contracts.view')

  union all

  select
    'active_rentals', c.id, coalesce(c.updated_at, c.created_at),
    c.contract_number, c.contract_number, c.contract_number,
    c.status::text, null::numeric, '/contracts/' || c.id::text
  from public.contracts c
  where c.tenant_id = p_tenant_id
    and c.type = 'rental'::public.contract_type
    and c.status = 'active'::public.contract_status
    and (p_kind is null or p_kind = 'active_rentals')
    and public.user_has_permission('contracts.view')

  union all

  select
    case
      when pu.status = 'rented'::public.unit_status then 'assets_rented'
      when pu.status = 'trial'::public.unit_status then 'assets_trial'
      else 'assets_attention'
    end,
    pu.id,
    coalesce(pu.updated_at, pu.created_at),
    pu.serial_number,
    pu.serial_number,
    pu.serial_number,
    pu.status::text,
    null::numeric,
    '/product-units/' || pu.id::text
  from public.product_units pu
  where pu.tenant_id = p_tenant_id
    and pu.status in (
      'rented'::public.unit_status,
      'trial'::public.unit_status,
      'maintenance'::public.unit_status,
      'damaged'::public.unit_status,
      'lost'::public.unit_status
    )
    and public.user_has_permission('product_units.view')
    and (
      p_kind is null
      or (p_kind = 'assets_rented' and pu.status = 'rented'::public.unit_status)
      or (p_kind = 'assets_trial' and pu.status = 'trial'::public.unit_status)
      or (
        p_kind = 'assets_attention'
        and pu.status in (
          'maintenance'::public.unit_status,
          'damaged'::public.unit_status,
          'lost'::public.unit_status
        )
      )
    )

  union all

  select
    'collections', v.id, v.created_at,
    v.voucher_number, v.voucher_number, v.voucher_number,
    v.status::text, v.amount, '/vouchers/' || v.id::text
  from public.vouchers v
  where v.tenant_id = p_tenant_id
    and v.type = 'receipt'::public.voucher_type
    and v.status = 'confirmed'::public.voucher_status
    and v.date >= date_trunc('month', p_business_date)::date
    and v.date <= p_business_date
    and (p_kind is null or p_kind = 'collections')
    and public.user_has_permission('vouchers.view')

  union all

  select
    'outstanding', i.id, coalesce(i.confirmed_at, i.created_at),
    i.invoice_number, i.invoice_number, i.invoice_number,
    i.status::text,
    greatest(i.total - i.paid_amount, 0),
    '/invoices/' || i.id::text || '?type=' || i.type::text
  from public.invoices i
  where i.tenant_id = p_tenant_id
    and i.type in (
      'sales'::public.invoice_type,
      'rental_monthly'::public.invoice_type,
      'opening_balance_customer'::public.invoice_type
    )
    and i.status in (
      'confirmed'::public.invoice_status,
      'partially_paid'::public.invoice_status
    )
    and i.total > i.paid_amount
    and (p_kind is null or p_kind = 'outstanding')
    and (
      public.user_has_permission('invoices.view')
      or public.user_has_permission('invoices.view_sales')
    );
$$;

revoke all on function public.phase_7_5_m5_dashboard_rows(
  uuid, uuid, date, text, text
) from public, anon, authenticated;

create or replace function public.get_phase_7_5_dashboard(
  p_business_date date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_user_id uuid := auth.uid();
  v_date date;
  v_timezone text;
  v_currency_code text;
  v_today_total integer := 0;
  v_today_completed integer := 0;
  v_today_remaining integer := 0;
  v_overdue integer := 0;
  v_active_contracts integer := 0;
  v_active_trials integer := 0;
  v_active_rentals integer := 0;
  v_assets_rented integer := 0;
  v_assets_trial integer := 0;
  v_assets_attention integer := 0;
  v_collections numeric := 0;
  v_outstanding numeric := 0;
  v_calendar_visible boolean;
  v_contracts_visible boolean;
  v_assets_visible boolean;
  v_collections_visible boolean;
  v_outstanding_visible boolean;
begin
  if v_user_id is null or v_tenant_id is null then
    raise exception using errcode = 'P0001', message = 'auth_required';
  end if;

  select tcs.timezone_name
  into v_timezone
  from public.tenant_calendar_settings tcs
  where tcs.tenant_id = v_tenant_id
    and tcs.timezone_name is not null
    and public.is_valid_iana_timezone(tcs.timezone_name);

  if v_timezone is null then
    raise exception using errcode = 'P0001', message = 'calendar_timezone_unconfigured';
  end if;

  select cur.iso_code
  into v_currency_code
  from public.tenants t
  left join public.currencies cur on cur.id = t.default_currency_id
  where t.id = v_tenant_id;

  v_date := coalesce(p_business_date, public.try_tenant_local_today(v_tenant_id));
  if v_date is null then
    raise exception using errcode = 'P0001', message = 'calendar_timezone_unconfigured';
  end if;

  v_calendar_visible :=
    public.user_has_permission('calendar.view')
    or public.user_has_permission('calendar.view_assigned');
  v_contracts_visible := public.user_has_permission('contracts.view');
  v_assets_visible := public.user_has_permission('product_units.view');
  v_collections_visible := public.user_has_permission('vouchers.view');
  v_outstanding_visible :=
    public.user_has_permission('invoices.view')
    or public.user_has_permission('invoices.view_sales');

  with rows as materialized (
    select *
    from public.phase_7_5_m5_dashboard_rows(
      v_tenant_id, v_user_id, v_date, v_timezone, null
    )
  )
  select
    count(*) filter (where kind = 'today_schedule')::integer,
    count(*) filter (where kind = 'today_completed')::integer,
    count(*) filter (where kind = 'today_remaining')::integer,
    count(*) filter (where kind = 'overdue')::integer,
    count(*) filter (where kind = 'active_contracts')::integer,
    count(*) filter (where kind = 'active_trials')::integer,
    count(*) filter (where kind = 'active_rentals')::integer,
    count(*) filter (where kind = 'assets_rented')::integer,
    count(*) filter (where kind = 'assets_trial')::integer,
    count(*) filter (where kind = 'assets_attention')::integer,
    coalesce(sum(amount) filter (where kind = 'collections'), 0),
    coalesce(sum(amount) filter (where kind = 'outstanding'), 0)
  into
    v_today_total, v_today_completed, v_today_remaining, v_overdue,
    v_active_contracts, v_active_trials, v_active_rentals,
    v_assets_rented, v_assets_trial, v_assets_attention,
    v_collections, v_outstanding
  from rows;

  return jsonb_build_object(
    'business_date', v_date,
    'timezone_name', v_timezone,
    'currency_code', v_currency_code,
    'today_schedule', jsonb_build_object(
      'visible', v_calendar_visible,
      'total', v_today_total,
      'completed', v_today_completed,
      'remaining', v_today_remaining
    ),
    'overdue', jsonb_build_object(
      'visible', v_calendar_visible,
      'count', v_overdue
    ),
    'contracts', jsonb_build_object(
      'visible', v_contracts_visible,
      'active', v_active_contracts,
      'trials', v_active_trials,
      'rentals', v_active_rentals,
      'asset_condition_visible', v_assets_visible,
      'assets_rented', v_assets_rented,
      'assets_trial', v_assets_trial,
      'assets_attention', v_assets_attention
    ),
    'financial', jsonb_build_object(
      'collections_visible', v_collections_visible,
      'collections', v_collections,
      'outstanding_visible', v_outstanding_visible,
      'outstanding', v_outstanding,
      'month_start', date_trunc('month', v_date)::date
    )
  );
end;
$$;

create or replace function public.list_phase_7_5_dashboard_drilldown(
  p_kind text,
  p_business_date date default null,
  p_limit integer default 40,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_user_id uuid := auth.uid();
  v_date date;
  v_timezone text;
  v_currency_code text;
  v_kind text := lower(btrim(coalesce(p_kind, '')));
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 5000);
  v_items jsonb;
  v_total integer;
begin
  if v_user_id is null or v_tenant_id is null then
    raise exception using errcode = 'P0001', message = 'auth_required';
  end if;

  if v_kind <> all(array[
    'today_schedule', 'today_completed', 'today_remaining', 'overdue',
    'active_contracts', 'active_trials', 'active_rentals',
    'assets_rented', 'assets_trial', 'assets_attention',
    'collections', 'outstanding'
  ]) then
    raise exception using errcode = 'P0001', message = 'validation_failed';
  end if;

  select tcs.timezone_name
  into v_timezone
  from public.tenant_calendar_settings tcs
  where tcs.tenant_id = v_tenant_id
    and tcs.timezone_name is not null
    and public.is_valid_iana_timezone(tcs.timezone_name);

  if v_timezone is null then
    raise exception using errcode = 'P0001', message = 'calendar_timezone_unconfigured';
  end if;
  select cur.iso_code
  into v_currency_code
  from public.tenants t
  left join public.currencies cur on cur.id = t.default_currency_id
  where t.id = v_tenant_id;
  v_date := coalesce(p_business_date, public.try_tenant_local_today(v_tenant_id));

  with rows as materialized (
    select *
    from public.phase_7_5_m5_dashboard_rows(
      v_tenant_id, v_user_id, v_date, v_timezone, v_kind
    )
  ),
  counted as (
    select r.*, count(*) over ()::integer as total_count
    from rows r
  ),
  page as (
    select *
    from counted
    order by
      case when v_kind in ('today_schedule', 'overdue') then occurred_at end asc,
      case when v_kind not in ('today_schedule', 'overdue') then occurred_at end desc,
      entity_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_strip_nulls(jsonb_build_object(
          'kind', p.kind,
          'entity_id', p.entity_id,
          'occurred_at', p.occurred_at,
          'local_time', to_char(p.occurred_at at time zone v_timezone, 'HH24:MI'),
          'title_ar', p.title_ar,
          'title_en', p.title_en,
          'identifier', p.identifier,
          'status', p.status,
          'amount', p.amount,
          'source_route', p.source_route
        ))
        order by
          case when v_kind in ('today_schedule', 'overdue') then p.occurred_at end asc,
          case when v_kind not in ('today_schedule', 'overdue') then p.occurred_at end desc,
          p.entity_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_count), (select count(*)::integer from rows))
  into v_items, v_total
  from page p;

  return jsonb_build_object(
    'kind', v_kind,
    'business_date', v_date,
    'timezone_name', v_timezone,
    'currency_code', v_currency_code,
    'items', v_items,
    'total_count', coalesce(v_total, 0),
    'has_more', coalesce(v_total, 0) > v_offset + v_limit
  );
end;
$$;

create or replace function public.list_phase_7_5_daily_activity(
  p_business_date date default null,
  p_limit integer default 40,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_user_id uuid := auth.uid();
  v_employee_id uuid := public.current_employee_id();
  v_date date;
  v_timezone text;
  v_currency_code text;
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 5000);
  v_items jsonb;
  v_total integer;
begin
  if v_user_id is null or v_tenant_id is null then
    raise exception using errcode = 'P0001', message = 'auth_required';
  end if;

  select tcs.timezone_name
  into v_timezone
  from public.tenant_calendar_settings tcs
  where tcs.tenant_id = v_tenant_id
    and tcs.timezone_name is not null
    and public.is_valid_iana_timezone(tcs.timezone_name);

  if v_timezone is null then
    raise exception using errcode = 'P0001', message = 'calendar_timezone_unconfigured';
  end if;
  select cur.iso_code
  into v_currency_code
  from public.tenants t
  left join public.currencies cur on cur.id = t.default_currency_id
  where t.id = v_tenant_id;
  v_date := coalesce(p_business_date, public.try_tenant_local_today(v_tenant_id));

  with candidates as (
    select
      'calendar_event'::text as kind,
      ce.id as entity_id,
      coalesce(
        ce.completed_at,
        ce.scheduled_start_at,
        (ce.scheduled_date::timestamp + coalesce(ce.scheduled_time, time '00:00'))
          at time zone v_timezone
      ) as occurred_at,
      coalesce(nullif(btrim(ce.title_ar), ''), replace(ce.type::text, '_', ' ')) as title_ar,
      coalesce(nullif(btrim(ce.title_en), ''), initcap(replace(ce.type::text, '_', ' '))) as title_en,
      replace(ce.type::text, '_', ' ') as identifier,
      ce.status::text as status,
      null::numeric as amount,
      '/calendar?date=' || to_char(ce.scheduled_date, 'YYYY-MM-DD') as source_route
    from public.calendar_events ce
    where ce.tenant_id = v_tenant_id
      and ce.scheduled_date = v_date
      and public.user_has_calendar_event_visibility(v_tenant_id, v_user_id, ce.id)

    union all

    select
      'visit_outcome', v.id,
      coalesce(
        v.completed_at,
        v.started_at,
        (v.scheduled_date::timestamp + coalesce(v.scheduled_time, time '00:00'))
          at time zone v_timezone
      ),
      v.visit_number, v.visit_number, replace(v.type::text, '_', ' '),
      v.status::text, null::numeric, null::text
    from public.visits v
    where v.tenant_id = v_tenant_id
      and v.scheduled_date = v_date
      and v.status in (
        'completed'::public.visit_status,
        'missed'::public.visit_status,
        'cancelled'::public.visit_status,
        'rescheduled'::public.visit_status
      )
      and (
        public.user_has_permission('visits.view')
        or (
          public.user_has_permission('visits.view_assigned')
          and v.agent_id = v_employee_id
        )
      )

    union all

    select
      'contract_created', c.id, c.created_at,
      c.contract_number, c.contract_number, c.type::text,
      c.status::text, null::numeric, '/contracts/' || c.id::text
    from public.contracts c
    where c.tenant_id = v_tenant_id
      and (c.created_at at time zone v_timezone)::date = v_date
      and public.user_has_permission('contracts.view')

    union all

    select
      'contract_lifecycle', coalesce(o.result_contract_id, o.source_contract_id),
      o.created_at,
      coalesce(c.contract_number, source_c.contract_number),
      coalesce(c.contract_number, source_c.contract_number),
      replace(o.operation_type, '_', ' '),
      coalesce(c.status::text, source_c.status::text),
      null::numeric,
      '/contracts/' || coalesce(o.result_contract_id, o.source_contract_id)::text
    from public.contract_lifecycle_operations o
    left join public.contracts c
      on c.tenant_id = o.tenant_id and c.id = o.result_contract_id
    left join public.contracts source_c
      on source_c.tenant_id = o.tenant_id and source_c.id = o.source_contract_id
    where o.tenant_id = v_tenant_id
      and (o.created_at at time zone v_timezone)::date = v_date
      and public.user_has_permission('contracts.view')

    union all

    select
      'invoice', i.id,
      case
        when (coalesce(i.confirmed_at, i.created_at) at time zone v_timezone)::date = v_date
          then coalesce(i.confirmed_at, i.created_at)
        else v_date::timestamp at time zone v_timezone
      end,
      i.invoice_number, i.invoice_number, i.type::text,
      i.status::text, i.total,
      '/invoices/' || i.id::text || '?type=' || i.type::text
    from public.invoices i
    where i.tenant_id = v_tenant_id
      and i.date = v_date
      and (
        public.user_has_permission('invoices.view')
        or (
          i.type in ('sales', 'rental_monthly', 'opening_balance_customer')
          and public.user_has_permission('invoices.view_sales')
        )
        or (
          i.type in ('purchase', 'opening_balance_supplier')
          and public.user_has_permission('invoices.view_purchase')
        )
        or (
          i.type in ('sales_return', 'purchase_return')
          and public.user_has_permission('invoices.view_returns')
        )
      )

    union all

    select
      'voucher', v.id,
      case
        when (v.created_at at time zone v_timezone)::date = v_date then v.created_at
        else v_date::timestamp at time zone v_timezone
      end,
      v.voucher_number, v.voucher_number, v.type::text,
      v.status::text, v.amount, '/vouchers/' || v.id::text
    from public.vouchers v
    where v.tenant_id = v_tenant_id
      and v.date = v_date
      and public.user_has_permission('vouchers.view')

    union all

    -- Cash/bank users get the posted account movement even when they do not
    -- have permission to open the originating invoice or voucher module.
    select
      'cash_bank_movement', je.id,
      coalesce(je.posted_at, je.created_at),
      coalesce(nullif(btrim(je.description_ar), ''), je.entry_number),
      coalesce(nullif(btrim(je.description_en), ''), je.entry_number),
      replace(je.source::text, '_', ' '),
      'posted',
      sum(abs(jl.debit - jl.credit))::numeric,
      '/cash-bank'
    from public.journal_entries je
    join public.journal_lines jl
      on jl.tenant_id = je.tenant_id
     and jl.journal_entry_id = je.id
    join public.chart_of_accounts coa
      on coa.tenant_id = jl.tenant_id
     and coa.id = jl.account_id
    where je.tenant_id = v_tenant_id
      and je.date = v_date
      and je.is_posted = true
      and coa.type = 'asset'::public.account_type
      and coa.is_active = true
      and coa.related_entity_id is null
      and not exists (
        select 1
        from public.chart_of_accounts child
        where child.tenant_id = coa.tenant_id
          and child.parent_id = coa.id
      )
      and public.user_has_permission('cash_bank.view')
    group by
      je.id, je.posted_at, je.created_at, je.description_ar,
      je.description_en, je.entry_number, je.source

    union all

    select
      'inventory_document', d.id,
      case
        when (d.confirmed_at at time zone v_timezone)::date = v_date then d.confirmed_at
        else v_date::timestamp at time zone v_timezone
      end,
      d.document_number, d.document_number, replace(d.document_type::text, '_', ' '),
      d.status::text,
      null::numeric,
      '/inventory/documents/' || d.id::text
    from public.inventory_documents d
    where d.tenant_id = v_tenant_id
      and d.document_date = v_date
      and public.user_has_permission('inventory_documents.view')
  ),
  counted as (
    select c.*, count(*) over ()::integer as total_count
    from candidates c
  ),
  page as (
    select *
    from counted
    order by occurred_at desc, kind, entity_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_strip_nulls(jsonb_build_object(
          'kind', p.kind,
          'entity_id', p.entity_id,
          'occurred_at', p.occurred_at,
          'local_time', to_char(p.occurred_at at time zone v_timezone, 'HH24:MI'),
          'title_ar', p.title_ar,
          'title_en', p.title_en,
          'identifier', p.identifier,
          'status', p.status,
          'amount', p.amount,
          'source_route', p.source_route
        ))
        order by p.occurred_at desc, p.kind, p.entity_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_count), (select count(*)::integer from candidates))
  into v_items, v_total
  from page p;

  return jsonb_build_object(
    'business_date', v_date,
    'timezone_name', v_timezone,
    'currency_code', v_currency_code,
    'items', v_items,
    'total_count', coalesce(v_total, 0),
    'has_more', coalesce(v_total, 0) > v_offset + v_limit
  );
end;
$$;

revoke all on function public.get_phase_7_5_dashboard(date) from public;
revoke all on function public.list_phase_7_5_dashboard_drilldown(
  text, date, integer, integer
) from public;
revoke all on function public.list_phase_7_5_daily_activity(
  date, integer, integer
) from public;

grant execute on function public.get_phase_7_5_dashboard(date) to authenticated;
grant execute on function public.list_phase_7_5_dashboard_drilldown(
  text, date, integer, integer
) to authenticated;
grant execute on function public.list_phase_7_5_daily_activity(
  date, integer, integer
) to authenticated;

comment on function public.get_phase_7_5_dashboard(date) is
  'Phase 7.5 M5 permission-shaped Dashboard v1 summary for a tenant business date.';
comment on function public.list_phase_7_5_dashboard_drilldown(text, date, integer, integer) is
  'Phase 7.5 M5 exact paginated source rows behind each Dashboard metric.';
comment on function public.list_phase_7_5_daily_activity(date, integer, integer) is
  'Phase 7.5 M5 permission-shaped selected-date operational activity timeline.';
