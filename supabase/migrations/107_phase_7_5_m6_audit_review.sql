-- Phase 7.5 M6: permission-shaped, redacted basic Audit Log review.
-- Raw before/after payloads remain server-side. API roles retain only the
-- narrow metadata columns needed by legacy integrity tests; Flutter reads the
-- audit surface exclusively through list_phase_7_5_audit_log().

create index if not exists idx_audit_tenant_at_id
  on public.audit_log (tenant_id, at desc, id desc);

create index if not exists idx_audit_tenant_entity_at
  on public.audit_log (tenant_id, entity_type, at desc, id desc);

create or replace function public.phase_7_5_m6_audit_module(
  p_entity_type text
)
returns text
language sql
immutable
set search_path = public
as $$
  select case lower(coalesce(p_entity_type, ''))
    when 'customers' then 'parties'
    when 'customer_service_locations' then 'parties'
    when 'suppliers' then 'parties'
    when 'contracts' then 'contracts'
    when 'contract_lines' then 'contracts'
    when 'contract_oil_changes' then 'contracts'
    when 'contract_lifecycle_operations' then 'contracts'
    when 'invoices' then 'finance'
    when 'invoice_lines' then 'finance'
    when 'vouchers' then 'finance'
    when 'voucher_invoice_allocations' then 'finance'
    when 'journal_entries' then 'finance'
    when 'journal_lines' then 'finance'
    when 'chart_of_accounts' then 'finance'
    when 'products' then 'inventory'
    when 'product_groups' then 'inventory'
    when 'product_units' then 'inventory'
    when 'warehouses' then 'inventory'
    when 'inventory_documents' then 'inventory'
    when 'inventory_document_lines' then 'inventory'
    when 'inventory_movements' then 'inventory'
    when 'calendar_events' then 'calendar'
    when 'tenant_working_date_exceptions' then 'calendar'
    when 'tenant_calendar_settings' then 'settings'
    when 'tenant_working_days' then 'settings'
    when 'tenant_document_settings' then 'settings'
    when 'document_templates' then 'settings'
    when 'tax_rates' then 'settings'
    when 'tenant_settings' then 'settings'
    when 'tenant_users' then 'security'
    when 'user_permissions' then 'security'
    when 'employees' then 'security'
    when 'visits' then 'field_ops'
    else 'system'
  end;
$$;

create or replace function public.phase_7_5_m6_can_view_audit_source(
  p_entity_type text,
  p_entity_id uuid,
  p_payload jsonb
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_type text := lower(coalesce(p_entity_type, ''));
  v_invoice_type text := lower(coalesce(p_payload ->> 'type', ''));
  v_employee_id uuid := public.current_employee_id();
begin
  return case
    when v_type in ('customers', 'customer_service_locations') then
      public.user_has_permission('customers.view')
    when v_type = 'suppliers' then
      public.user_has_permission('suppliers.view')
    when v_type in ('contracts', 'contract_lines', 'contract_oil_changes',
                    'contract_lifecycle_operations') then
      public.user_has_permission('contracts.view')
    when v_type in ('invoices', 'invoice_lines') then
      public.user_has_permission('invoices.view')
      or (
        v_invoice_type in ('sales', 'rental_monthly', 'opening_balance_customer')
        and public.user_has_permission('invoices.view_sales')
      )
      or (
        v_invoice_type in ('purchase', 'opening_balance_supplier')
        and public.user_has_permission('invoices.view_purchase')
      )
      or (
        v_invoice_type in ('sales_return', 'purchase_return')
        and public.user_has_permission('invoices.view_returns')
      )
      or (
        v_invoice_type = '' and (
          public.user_has_permission('invoices.view_sales')
          or public.user_has_permission('invoices.view_purchase')
          or public.user_has_permission('invoices.view_returns')
        )
      )
    when v_type in ('vouchers', 'voucher_invoice_allocations') then
      public.user_has_permission('vouchers.view')
    when v_type in ('journal_entries', 'journal_lines') then
      public.user_has_permission('journal.view')
    when v_type = 'chart_of_accounts' then
      public.user_has_permission('chart_of_accounts.view')
    when v_type in ('products', 'product_groups') then
      public.user_has_permission('products.view')
    when v_type = 'product_units' then
      public.user_has_permission('product_units.view')
    when v_type = 'warehouses' then
      public.user_has_permission('warehouses.view')
    when v_type in ('inventory_documents', 'inventory_document_lines') then
      public.user_has_permission('inventory_documents.view')
    when v_type = 'inventory_movements' then
      public.user_has_permission('inventory_movements.view')
    when v_type = 'calendar_events' then
      public.user_has_permission('calendar.view')
      or (
        public.user_has_permission('calendar.view_assigned')
        and p_entity_id is not null
        and public.user_has_calendar_event_visibility(
          public.current_tenant_id(), auth.uid(), p_entity_id
        )
      )
    when v_type in ('tenant_working_date_exceptions', 'tenant_calendar_settings',
                    'tenant_working_days') then
      public.user_has_permission('settings.calendar.view')
    when v_type in ('tenant_document_settings', 'document_templates') then
      public.user_has_permission('settings.templates.view')
    when v_type = 'tax_rates' then
      public.user_has_permission('settings.tax.view')
    when v_type = 'tenant_settings' then
      public.user_has_permission('settings.company.view')
    when v_type in ('tenant_users', 'user_permissions', 'employees') then
      public.user_has_permission('settings.users.view')
    when v_type = 'visits' then
      public.user_has_permission('visits.view')
      or (
        public.user_has_permission('visits.view_assigned')
        and exists (
          select 1
          from public.visits v
          where v.tenant_id = public.current_tenant_id()
            and v.id = p_entity_id
            and v.agent_id = v_employee_id
        )
      )
    else false
  end;
end;
$$;

create or replace function public.phase_7_5_m6_safe_audit_snapshot(
  p_payload jsonb,
  p_can_view_source boolean
)
returns jsonb
language sql
immutable
set search_path = public
as $$
  select case
    when not coalesce(p_can_view_source, false) or p_payload is null then null
    else coalesce((
      select jsonb_object_agg(e.key, e.value order by e.key)
      from jsonb_each(p_payload) e
      where e.key = any(array[
        'account_type', 'code', 'contract_number', 'date', 'day_mode',
        'document_date', 'document_number', 'entry_number', 'invoice_number',
        'is_active', 'name_ar', 'name_en', 'preferred_locale',
        'scheduled_date', 'sku', 'status', 'timezone_name', 'title_ar',
        'title_en', 'type', 'visit_number', 'voucher_number'
      ])
    ), '{}'::jsonb)
  end;
$$;

create or replace function public.phase_7_5_m6_safe_changed_fields(
  p_before jsonb,
  p_after jsonb,
  p_can_view_source boolean
)
returns jsonb
language sql
immutable
set search_path = public
as $$
  select case
    when not coalesce(p_can_view_source, false) then '[]'::jsonb
    else coalesce((
      select jsonb_agg(k.key order by k.key)
      from (
        select key from jsonb_object_keys(coalesce(p_before, '{}'::jsonb)) key
        union
        select key from jsonb_object_keys(coalesce(p_after, '{}'::jsonb)) key
      ) k
      where k.key = any(array[
        'account_type', 'code', 'contract_number', 'date', 'day_mode',
        'document_date', 'document_number', 'entry_number', 'invoice_number',
        'is_active', 'name_ar', 'name_en', 'preferred_locale',
        'scheduled_date', 'sku', 'status', 'timezone_name', 'title_ar',
        'title_en', 'type', 'visit_number', 'voucher_number'
      ])
        and coalesce(p_before, '{}'::jsonb) -> k.key
          is distinct from coalesce(p_after, '{}'::jsonb) -> k.key
    ), '[]'::jsonb)
  end;
$$;

create or replace function public.phase_7_5_m6_audit_source_route(
  p_entity_type text,
  p_entity_id uuid,
  p_payload jsonb,
  p_can_view_source boolean
)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_type text := lower(coalesce(p_entity_type, ''));
  v_parent_id text;
  v_date text;
begin
  if not coalesce(p_can_view_source, false) then return null; end if;

  if v_type = 'customers' and p_entity_id is not null then
    return '/customers/' || p_entity_id::text;
  elsif v_type = 'customer_service_locations' then
    v_parent_id := coalesce(p_payload ->> 'customer_id', '');
    return case when v_parent_id <> '' then '/customers/' || v_parent_id else null end;
  elsif v_type = 'suppliers' and p_entity_id is not null then
    return '/suppliers/' || p_entity_id::text;
  elsif v_type = 'products' and p_entity_id is not null then
    return '/products/' || p_entity_id::text;
  elsif v_type = 'product_units' and p_entity_id is not null then
    return '/product-units/' || p_entity_id::text;
  elsif v_type = 'product_groups' then
    return '/products';
  elsif v_type = 'warehouses' then
    return '/warehouses';
  elsif v_type = 'contracts' and p_entity_id is not null then
    return '/contracts/' || p_entity_id::text;
  elsif v_type in ('invoices', 'invoice_lines') then
    v_parent_id := case when v_type = 'invoices' then p_entity_id::text
                        else p_payload ->> 'invoice_id' end;
    return case when coalesce(v_parent_id, '') <> ''
      then '/invoices/' || v_parent_id ||
        case when coalesce(p_payload ->> 'type', '') <> ''
          then '?type=' || (p_payload ->> 'type') else '' end
      else null end;
  elsif v_type = 'vouchers' and p_entity_id is not null then
    return '/vouchers/' || p_entity_id::text;
  elsif v_type = 'journal_entries' and p_entity_id is not null then
    return '/journal/' || p_entity_id::text;
  elsif v_type = 'inventory_documents' and p_entity_id is not null then
    return '/inventory/documents/' || p_entity_id::text;
  elsif v_type = 'inventory_movements' then
    return '/inventory/movements';
  elsif v_type = 'calendar_events' then
    v_date := coalesce(p_payload ->> 'scheduled_date', '');
    return case when v_date ~ '^\d{4}-\d{2}-\d{2}$'
      then '/calendar?date=' || v_date else '/calendar' end;
  elsif v_type in ('tenant_working_date_exceptions', 'tenant_calendar_settings',
                   'tenant_working_days') then
    return '/settings/calendar';
  elsif v_type in ('tenant_document_settings', 'document_templates') then
    return '/settings/templates';
  elsif v_type = 'tax_rates' then
    return '/settings/tax';
  elsif v_type = 'chart_of_accounts' then
    return '/accounts';
  end if;
  return null;
end;
$$;

create or replace function public.list_phase_7_5_audit_log(
  p_module text default null,
  p_action text default null,
  p_actor_id uuid default null,
  p_date_from date default null,
  p_date_to date default null,
  p_search text default null,
  p_limit integer default 50,
  p_before_at timestamptz default null,
  p_before_id bigint default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_timezone text;
  v_module text := lower(nullif(btrim(coalesce(p_module, '')), ''));
  v_action text := lower(nullif(btrim(coalesce(p_action, '')), ''));
  v_search text := left(lower(nullif(btrim(coalesce(p_search, '')), '')), 80);
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_from_at timestamptz;
  v_to_at timestamptz;
  v_items jsonb;
  v_limited_count integer := 0;
  v_last_at timestamptz;
  v_last_id bigint;
begin
  if auth.uid() is null or v_tenant_id is null then
    raise exception using errcode = 'P0001', message = 'auth_required';
  end if;
  if not public.user_has_permission('audit_log.view') then
    raise exception using errcode = 'P0001', message = 'permission_denied';
  end if;
  if v_module is not null and v_module <> all(array[
    'parties', 'contracts', 'finance', 'inventory', 'calendar', 'settings',
    'security', 'field_ops', 'system'
  ]) then
    raise exception using errcode = 'P0001', message = 'validation_failed';
  end if;
  if v_action is not null and (length(v_action) > 64 or v_action !~ '^[a-z0-9_ -]+$') then
    raise exception using errcode = 'P0001', message = 'validation_failed';
  end if;
  if p_date_from is not null and p_date_to is not null and p_date_from > p_date_to then
    raise exception using errcode = 'P0001', message = 'validation_failed';
  end if;
  if (p_before_at is null) <> (p_before_id is null) then
    raise exception using errcode = 'P0001', message = 'validation_failed';
  end if;

  select coalesce(
    (
      select tcs.timezone_name
      from public.tenant_calendar_settings tcs
      where tcs.tenant_id = v_tenant_id
        and public.is_valid_iana_timezone(tcs.timezone_name)
    ),
    (
      select t.timezone
      from public.tenants t
      where t.id = v_tenant_id
        and public.is_valid_iana_timezone(t.timezone)
    ),
    'UTC'
  ) into v_timezone;

  v_from_at := case when p_date_from is null then null
    else p_date_from::timestamp at time zone v_timezone end;
  v_to_at := case when p_date_to is null then null
    else (p_date_to + 1)::timestamp at time zone v_timezone end;

  with candidates as materialized (
    select
      a.*,
      public.phase_7_5_m6_audit_module(a.entity_type) as module,
      coalesce(
        nullif(btrim(tu.display_name), ''),
        nullif(btrim(e.name_en), ''),
        nullif(btrim(e.name_ar), ''),
        case when a.actor_id is null then 'System' else 'User' end
      ) as actor_name,
      coalesce(a.after_json, a.before_json, '{}'::jsonb) as payload
    from public.audit_log a
    left join public.tenant_users tu
      on tu.tenant_id = a.tenant_id and tu.user_id = a.actor_id
    left join public.employees e
      on e.tenant_id = a.tenant_id and e.user_id = a.actor_id
    where a.tenant_id = v_tenant_id
      and (v_from_at is null or a.at >= v_from_at)
      and (v_to_at is null or a.at < v_to_at)
      and (p_before_at is null or (a.at, a.id) < (p_before_at, p_before_id))
      and (v_action is null or lower(a.action) = v_action)
      and (p_actor_id is null or a.actor_id = p_actor_id)
  ),
  shaped as materialized (
    select
      c.*,
      public.phase_7_5_m6_can_view_audit_source(
        c.entity_type, c.entity_id, c.payload
      ) as can_view_source
    from candidates c
    where (v_module is null or c.module = v_module)
  ),
  filtered as materialized (
    select s.*
    from shaped s
    where (
        v_search is null
        or lower(s.entity_type) like '%' || v_search || '%'
        or lower(s.action) like '%' || v_search || '%'
        or lower(s.actor_name) like '%' || v_search || '%'
        or (
          s.can_view_source
          and lower(coalesce(s.reason, '')) like '%' || v_search || '%'
        )
      )
  ),
  limited as (
    select f.*, count(*) over ()::integer as limited_count
    from filtered f
    order by f.at desc, f.id desc
    limit v_limit + 1
  ),
  page as (
    select *
    from limited
    order by at desc, id desc
    limit v_limit
  )
  select
    coalesce(jsonb_agg(
      jsonb_strip_nulls(jsonb_build_object(
        'id', p.id,
        'at', p.at,
        'local_time', to_char(p.at at time zone v_timezone, 'YYYY-MM-DD HH24:MI'),
        'actor_id', p.actor_id,
        'actor_name', p.actor_name,
        'actor_account_type', p.actor_account_type,
        'action', lower(p.action),
        'module', p.module,
        'entity_type', p.entity_type,
        'entity_id', p.entity_id,
        'reason', case when p.can_view_source then
          left(nullif(btrim(coalesce(p.reason, '')), ''), 1000)
        else null end,
        'source_visible', p.can_view_source,
        'before_summary', public.phase_7_5_m6_safe_audit_snapshot(
          p.before_json, p.can_view_source
        ),
        'after_summary', public.phase_7_5_m6_safe_audit_snapshot(
          p.after_json, p.can_view_source
        ),
        'changed_fields', public.phase_7_5_m6_safe_changed_fields(
          p.before_json, p.after_json, p.can_view_source
        ),
        'source_route', public.phase_7_5_m6_audit_source_route(
          p.entity_type, p.entity_id, p.payload, p.can_view_source
        )
      )) order by p.at desc, p.id desc
    ), '[]'::jsonb),
    coalesce(max(p.limited_count), 0)
  into v_items, v_limited_count
  from page p;

  if jsonb_array_length(v_items) > 0 then
    v_last_at := (v_items -> -1 ->> 'at')::timestamptz;
    v_last_id := (v_items -> -1 ->> 'id')::bigint;
  end if;

  return jsonb_build_object(
    'timezone_name', v_timezone,
    'items', v_items,
    'has_more', v_limited_count > v_limit,
    'next_before_at', v_last_at,
    'next_before_id', v_last_id
  );
end;
$$;

-- Keep legacy audit-count integrity tests working while removing direct access
-- to protected snapshots and request metadata.
revoke all on table public.audit_log from anon, authenticated;
grant select (
  id, tenant_id, at, actor_id, actor_account_type,
  action, entity_type, entity_id
) on table public.audit_log to authenticated;

revoke all on function public.phase_7_5_m6_audit_module(text)
  from public, anon, authenticated;
revoke all on function public.phase_7_5_m6_can_view_audit_source(text, uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.phase_7_5_m6_safe_audit_snapshot(jsonb, boolean)
  from public, anon, authenticated;
revoke all on function public.phase_7_5_m6_safe_changed_fields(jsonb, jsonb, boolean)
  from public, anon, authenticated;
revoke all on function public.phase_7_5_m6_audit_source_route(text, uuid, jsonb, boolean)
  from public, anon, authenticated;
revoke all on function public.list_phase_7_5_audit_log(
  text, text, uuid, date, date, text, integer, timestamptz, bigint
) from public, anon;

grant execute on function public.list_phase_7_5_audit_log(
  text, text, uuid, date, date, text, integer, timestamptz, bigint
) to authenticated;

comment on function public.list_phase_7_5_audit_log(
  text, text, uuid, date, date, text, integer, timestamptz, bigint
) is
  'Phase 7.5 M6: authenticated, tenant-scoped, redacted basic Audit Log review.';
