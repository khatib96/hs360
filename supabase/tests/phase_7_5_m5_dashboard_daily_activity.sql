\set ON_ERROR_STOP on

-- Phase 7.5 M5: Dashboard summary/list reconciliation, business-date activity,
-- permission shaping, assigned scope, tenant isolation, and paging.

do $$
begin
  if has_function_privilege(
    'anon', 'public.get_phase_7_5_dashboard(date)', 'EXECUTE'
  ) then
    raise exception 'm5 fail: anon dashboard execute';
  end if;
  if has_function_privilege(
    'anon',
    'public.list_phase_7_5_dashboard_drilldown(text, date, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'm5 fail: anon drilldown execute';
  end if;
  if has_function_privilege(
    'anon',
    'public.list_phase_7_5_daily_activity(date, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'm5 fail: anon activity execute';
  end if;
end $$;

begin;

update public.tenant_calendar_settings
set timezone_name = 'Asia/Kuwait'
where tenant_id in (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000102'
);

insert into public.user_permissions (
  tenant_id, tenant_user_id, permission_id, granted_by
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000305',
  'calendar.view_assigned',
  '00000000-0000-0000-0000-000000000201'
)
on conflict (tenant_user_id, permission_id) do nothing;

insert into public.calendar_events (
  id, tenant_id, type, status, source_kind, scheduled_date,
  title_ar, title_en, assigned_agent_id, created_by
)
values
  (
    '75500000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000101',
    'follow_up', 'pending', 'manual', '2026-08-05',
    'متابعة M5', 'M5 follow-up',
    '00000000-0000-0000-0000-000000000602',
    '00000000-0000-0000-0000-000000000201'
  ),
  (
    '75500000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000101',
    'custom', 'done', 'manual', '2026-08-05',
    'مكتمل M5', 'M5 completed',
    '00000000-0000-0000-0000-000000000601',
    '00000000-0000-0000-0000-000000000201'
  ),
  (
    '75500000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000101',
    'follow_up', 'pending', 'manual', '2026-08-03',
    'متأخر M5', 'M5 overdue',
    '00000000-0000-0000-0000-000000000601',
    '00000000-0000-0000-0000-000000000201'
  ),
  (
    '75500000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000102',
    'custom', 'pending', 'manual', '2026-08-05',
    'شركة أخرى', 'Other tenant', null,
    '00000000-0000-0000-0000-000000000204'
  );

insert into public.customers (
  id, tenant_id, code, customer_type, name_ar, name_en,
  phone_primary, created_by
)
values (
  '75500000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000101',
  'M5-CUSTOMER', 'company', 'عميل M5', 'M5 Customer',
  '50000000', '00000000-0000-0000-0000-000000000201'
);

select public.allow_finance_write();

insert into public.invoices (
  id, tenant_id, invoice_number, type, status, customer_id, date,
  subtotal, total, paid_amount, created_at, created_by, confirmed_at, confirmed_by
)
values (
  '75500000-0000-0000-0000-000000000301',
  '00000000-0000-0000-0000-000000000101',
  'M5-SI-001', 'sales', 'partially_paid',
  '75500000-0000-0000-0000-000000000201', '2026-08-05',
  100, 100, 25, '2026-08-05 08:30:00+00',
  '00000000-0000-0000-0000-000000000201', '2026-08-05 08:30:00+00',
  '00000000-0000-0000-0000-000000000201'
);

insert into public.vouchers (
  id, tenant_id, voucher_number, type, status, date, amount,
  payment_method, customer_id, account_id, cash_account_id,
  created_at, created_by, confirmed_at, confirmed_by
)
values (
  '75500000-0000-0000-0000-000000000302',
  '00000000-0000-0000-0000-000000000101',
  'M5-RV-001', 'receipt', 'confirmed', '2026-08-05', 25,
  'cash', '75500000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000503',
  '00000000-0000-0000-0000-000000000501',
  '2026-08-05 09:00:00+00',
  '00000000-0000-0000-0000-000000000201',
  '2026-08-05 09:00:00+00',
  '00000000-0000-0000-0000-000000000201'
);

insert into public.journal_entries (
  id, tenant_id, entry_number, date, source, description_ar, description_en,
  is_posted, posted_at, created_at, created_by
)
values (
  '75500000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000101',
  'M5-JE-001', '2026-08-05', 'manual', 'حركة صندوق M5', 'M5 cash movement',
  false, null, '2026-08-05 09:15:00+00',
  '00000000-0000-0000-0000-000000000201'
);

insert into public.journal_lines (
  id, tenant_id, journal_entry_id, account_id, debit, credit,
  description, line_order
)
values
  (
    '75500000-0000-0000-0000-000000000411',
    '00000000-0000-0000-0000-000000000101',
    '75500000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000501',
    10, 0, 'M5 cash', 1
  ),
  (
    '75500000-0000-0000-0000-000000000412',
    '00000000-0000-0000-0000-000000000101',
    '75500000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000506',
    0, 10, 'M5 revenue', 2
  );

update public.journal_entries
set is_posted = true,
    posted_at = '2026-08-05 09:15:00+00',
    posted_by = '00000000-0000-0000-0000-000000000201'
where id = '75500000-0000-0000-0000-000000000401';

do $$
declare
  v_dashboard jsonb;
  v_list jsonb;
  v_activity jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000201',
    true
  );

  v_dashboard := public.get_phase_7_5_dashboard('2026-08-05');
  if (v_dashboard #>> '{today_schedule,total}')::integer <> 2
     or (v_dashboard #>> '{today_schedule,completed}')::integer <> 1
     or (v_dashboard #>> '{today_schedule,remaining}')::integer <> 1
     or (v_dashboard #>> '{overdue,count}')::integer <> 1 then
    raise exception 'm5 fail: dashboard calendar totals %', v_dashboard;
  end if;
  if (v_dashboard #>> '{financial,collections}')::numeric <> 25
     or (v_dashboard #>> '{financial,outstanding}')::numeric <> 75
     or v_dashboard ->> 'currency_code' <> 'KWD' then
    raise exception 'm5 fail: dashboard finance totals %', v_dashboard;
  end if;

  v_list := public.list_phase_7_5_dashboard_drilldown(
    'today_schedule', '2026-08-05', 40, 0
  );
  if (v_list ->> 'total_count')::integer <>
       (v_dashboard #>> '{today_schedule,total}')::integer
     or jsonb_array_length(v_list -> 'items') <> 2 then
    raise exception 'm5 fail: total/drilldown reconciliation % %',
      v_dashboard, v_list;
  end if;

  v_list := public.list_phase_7_5_dashboard_drilldown(
    'outstanding', '2026-08-05', 1, 0
  );
  if v_list #>> '{items,0,identifier}' <> 'M5-SI-001'
     or (v_list #>> '{items,0,amount}')::numeric <> 75 then
    raise exception 'm5 fail: outstanding source row %', v_list;
  end if;

  v_activity := public.list_phase_7_5_daily_activity(
    '2026-08-05', 40, 0
  );
  if not exists (
    select 1 from jsonb_array_elements(v_activity -> 'items') item
    where item ->> 'kind' = 'invoice'
      and item ->> 'identifier' = 'sales'
  ) or not exists (
    select 1 from jsonb_array_elements(v_activity -> 'items') item
    where item ->> 'kind' = 'voucher'
      and item ->> 'identifier' = 'receipt'
      and item ->> 'local_time' = '12:00'
  ) or not exists (
    select 1 from jsonb_array_elements(v_activity -> 'items') item
    where item ->> 'kind' = 'cash_bank_movement'
      and item ->> 'title_en' = 'M5 cash movement'
      and item ->> 'local_time' = '12:15'
  ) then
    raise exception 'm5 fail: daily finance projections %', v_activity;
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_activity -> 'items') item
    where item ->> 'title_en' = 'Other tenant'
  ) then
    raise exception 'm5 fail: tenant leak %', v_activity;
  end if;
end $$;

insert into public.user_permissions (
  tenant_id, tenant_user_id, permission_id, granted_by
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000302',
  'cash_bank.view',
  '00000000-0000-0000-0000-000000000201'
)
on conflict (tenant_user_id, permission_id) do nothing;

do $$
declare
  v_activity jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000202',
    true
  );
  v_activity := public.list_phase_7_5_daily_activity('2026-08-05', 40, 0);
  if not exists (
    select 1 from jsonb_array_elements(v_activity -> 'items') item
    where item ->> 'kind' = 'cash_bank_movement'
      and item ->> 'title_en' = 'M5 cash movement'
      and item ->> 'source_route' = '/cash-bank'
  ) or exists (
    select 1 from jsonb_array_elements(v_activity -> 'items') item
    where item ->> 'kind' <> 'cash_bank_movement'
  ) then
    raise exception 'm5 fail: cash-bank-only activity scope %', v_activity;
  end if;
end $$;

delete from public.user_permissions
where tenant_user_id = '00000000-0000-0000-0000-000000000302'
  and permission_id = 'cash_bank.view';

do $$
declare
  v_dashboard jsonb;
  v_activity jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000202',
    true
  );
  v_dashboard := public.get_phase_7_5_dashboard('2026-08-05');
  if (v_dashboard #>> '{today_schedule,visible}')::boolean
     or (v_dashboard #>> '{contracts,visible}')::boolean
     or (v_dashboard #>> '{financial,collections_visible}')::boolean
     or (v_dashboard #>> '{financial,outstanding_visible}')::boolean then
    raise exception 'm5 fail: zero-permission visibility %', v_dashboard;
  end if;
  v_activity := public.list_phase_7_5_daily_activity('2026-08-05', 40, 0);
  if jsonb_array_length(v_activity -> 'items') <> 0 then
    raise exception 'm5 fail: zero-permission activity leak %', v_activity;
  end if;
end $$;

do $$
declare
  v_dashboard jsonb;
  v_activity jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000205',
    true
  );
  v_dashboard := public.get_phase_7_5_dashboard('2026-08-05');
  if (v_dashboard #>> '{today_schedule,total}')::integer <> 1
     or v_dashboard #>> '{today_schedule,remaining}' <> '1' then
    raise exception 'm5 fail: assigned-only dashboard scope %', v_dashboard;
  end if;
  v_activity := public.list_phase_7_5_daily_activity('2026-08-05', 40, 0);
  if jsonb_array_length(v_activity -> 'items') <> 1
     or v_activity #>> '{items,0,title_en}' <> 'M5 follow-up' then
    raise exception 'm5 fail: assigned-only activity scope %', v_activity;
  end if;
end $$;

rollback;

select 'phase_7_5_m5_dashboard_daily_activity: ok' as result;
