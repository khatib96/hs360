#!/usr/bin/env bash
# Deterministic cleanup for Phase 7 M12 Gate E tagged fixtures (P7M12).
# Does not touch P6M13 rows. Gate: all P7M12 counters must be 0.
# Never prints Supabase keys.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

container_name="${1:-supabase_db_hs360}"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<'SQL'
alter table public.journal_lines disable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries disable trigger trg_enforce_posted_journal_entry_immutability;
-- Local Supabase `postgres` is non-superuser; RLS with zero policies blocks DELETE.
alter table public.calendar_reminder_plans disable row level security;
alter table public.calendar_meeting_notices disable row level security;
alter table public.calendar_event_participants disable row level security;
alter table public.calendar_events disable row level security;

do $cleanup$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000101'::uuid;
  v_customer_ids uuid[] := '{}';
  v_location_ids uuid[] := '{}';
  v_product_ids uuid[] := '{}';
  v_unit_ids uuid[] := '{}';
  v_contract_ids uuid[] := '{}';
  v_line_ids uuid[] := '{}';
  v_invoice_ids uuid[] := '{}';
  v_voucher_ids uuid[] := '{}';
  v_journal_ids uuid[] := '{}';
  v_event_ids uuid[] := '{}';
  v_exception_ids uuid[] := '{}';
begin
  -- Supabase local postgres is often non-superuser; disable RLS for cleanup.
  perform set_config('row_security', 'off', true);
  select coalesce(array_agg(cust.id), '{}'::uuid[])
  into v_customer_ids
  from public.customers cust
  where cust.tenant_id = v_tenant
    and (
      cust.name_ar like '%P7M12%'
      or cust.name_en like '%P7M12%'
      or cust.phone_primary like '+965500094%'
    );

  select coalesce(array_agg(csl.id), '{}'::uuid[])
  into v_location_ids
  from public.customer_service_locations csl
  where csl.tenant_id = v_tenant
    and (
      csl.name like '%P7M12%'
      or csl.customer_id = any (v_customer_ids)
    );

  select coalesce(array_agg(p.id), '{}'::uuid[])
  into v_product_ids
  from public.products p
  where p.tenant_id = v_tenant
    and (
      p.sku like 'P7M12-%'
      or p.name_ar like '%P7M12%'
      or p.name_en like '%P7M12%'
    );

  select coalesce(array_agg(pu.id), '{}'::uuid[])
  into v_unit_ids
  from public.product_units pu
  where pu.tenant_id = v_tenant
    and (
      pu.product_id = any (v_product_ids)
      or pu.serial_number like 'P7M12-%'
    );

  select coalesce(array_agg(distinct c.id), '{}'::uuid[])
  into v_contract_ids
  from public.contracts c
  where c.tenant_id = v_tenant
    and (
      c.customer_id = any (v_customer_ids)
      or c.service_location_id = any (v_location_ids)
      or c.id in (
        select cl.contract_id
        from public.contract_lines cl
        where cl.product_id = any (v_product_ids)
           or cl.product_unit_id = any (v_unit_ids)
      )
    );

  select coalesce(array_agg(cl.id), '{}'::uuid[])
  into v_line_ids
  from public.contract_lines cl
  where cl.contract_id = any (v_contract_ids);

  select coalesce(array_agg(i.id), '{}'::uuid[])
  into v_invoice_ids
  from public.invoices i
  where i.tenant_id = v_tenant
    and (
      i.customer_id = any (v_customer_ids)
      or i.contract_id = any (v_contract_ids)
    );

  select coalesce(array_agg(v.id), '{}'::uuid[])
  into v_voucher_ids
  from public.vouchers v
  where v.tenant_id = v_tenant
    and (
      v.customer_id = any (v_customer_ids)
      or v.id in (
        select via.voucher_id
        from public.voucher_invoice_allocations via
        where via.invoice_id = any (v_invoice_ids)
      )
    );

  select coalesce(array_agg(je.id), '{}'::uuid[])
  into v_journal_ids
  from public.journal_entries je
  where je.tenant_id = v_tenant
    and (
      je.source_id = any (v_invoice_ids)
      or je.source_id = any (v_voucher_ids)
      or je.source_id = any (v_contract_ids)
    );

  select coalesce(array_agg(ce.id), '{}'::uuid[])
  into v_event_ids
  from public.calendar_events ce
  where ce.tenant_id = v_tenant
    and (
      ce.contract_id = any (v_contract_ids)
      or ce.customer_id = any (v_customer_ids)
      or ce.title_en like '%P7M12%'
      or ce.title_ar like '%P7M12%'
    );

  select coalesce(array_agg(wde.id), '{}'::uuid[])
  into v_exception_ids
  from public.tenant_working_date_exceptions wde
  where wde.tenant_id = v_tenant
    and (
      wde.title_en like '%P7M12%'
      or wde.title_ar like '%P7M12%'
    );

  -- Participants first: their DELETE trigger recreates reminder plans.
  delete from public.calendar_event_participants ep
  where ep.event_id = any (v_event_ids)
     or ep.event_id in (
       select ce.id from public.calendar_events ce
       where ce.tenant_id = v_tenant
         and (ce.title_en like '%P7M12%' or ce.title_ar like '%P7M12%')
     );

  delete from public.calendar_meeting_notices n
  where n.tenant_id = v_tenant
    and n.calendar_event_id in (
      select ce.id from public.calendar_events ce
      where ce.tenant_id = v_tenant
        and (
          ce.id = any (v_event_ids)
          or ce.title_en like '%P7M12%'
          or ce.title_ar like '%P7M12%'
          or ce.customer_id = any (v_customer_ids)
          or ce.contract_id = any (v_contract_ids)
        )
    );

  delete from public.calendar_schedule_operations so
  where so.tenant_id = v_tenant
    and so.result_event_id in (
      select ce.id from public.calendar_events ce
      where ce.tenant_id = v_tenant
        and (
          ce.id = any (v_event_ids)
          or ce.title_en like '%P7M12%'
          or ce.title_ar like '%P7M12%'
          or ce.customer_id = any (v_customer_ids)
          or ce.contract_id = any (v_contract_ids)
        )
    );

  -- Reminder plans last among dependents (after participant deletes).
  delete from public.calendar_reminder_plans p
  where p.calendar_event_id in (
    select ce.id from public.calendar_events ce
    where ce.tenant_id = v_tenant
      and (
        ce.id = any (v_event_ids)
        or ce.title_en like '%P7M12%'
        or ce.title_ar like '%P7M12%'
        or ce.customer_id = any (v_customer_ids)
        or ce.contract_id = any (v_contract_ids)
      )
  );

  if exists (
    select 1
    from public.calendar_reminder_plans p
    join public.calendar_events ce on ce.id = p.calendar_event_id
    where ce.tenant_id = v_tenant
      and (ce.title_en like '%P7M12%' or ce.title_ar like '%P7M12%')
  ) then
    raise exception 'P7M12 cleanup: reminder plans remain for P7M12-titled events';
  end if;

  delete from public.calendar_events ce
  where ce.tenant_id = v_tenant
    and (
      ce.id = any (v_event_ids)
      or ce.title_en like '%P7M12%'
      or ce.title_ar like '%P7M12%'
      or ce.customer_id = any (v_customer_ids)
      or ce.contract_id = any (v_contract_ids)
    );

  -- Soft-cancel then hard-delete P7M12 working-date exceptions.
  update public.tenant_working_date_exceptions wde
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancelled_by = '00000000-0000-0000-0000-000000000201'::uuid,
    cancel_reason = 'P7M12 Gate E cleanup'
  where wde.id = any (v_exception_ids)
    and wde.status = 'active';

  delete from public.tenant_working_date_exceptions wde
  where wde.id = any (v_exception_ids);

  delete from public.rental_invoice_coverages ric
  where ric.contract_id = any (v_contract_ids);

  delete from public.journal_lines jl
  where jl.journal_entry_id = any (v_journal_ids);

  delete from public.journal_entries je
  where je.id = any (v_journal_ids);

  delete from public.voucher_invoice_allocations via
  where via.invoice_id = any (v_invoice_ids)
     or via.voucher_id = any (v_voucher_ids);

  delete from public.vouchers v
  where v.id = any (v_voucher_ids);

  delete from public.invoice_lines il
  where il.invoice_id = any (v_invoice_ids);

  delete from public.invoices i
  where i.id = any (v_invoice_ids);

  delete from public.contract_lifecycle_operations clo
  where clo.source_contract_id = any (v_contract_ids)
     or clo.result_contract_id = any (v_contract_ids);

  delete from public.contract_lines cl
  where cl.id = any (v_line_ids);

  delete from public.contracts c
  where c.id = any (v_contract_ids);

  delete from public.inventory_balances ib
  where ib.product_id = any (v_product_ids);

  delete from public.product_units pu
  where pu.id = any (v_unit_ids);

  delete from public.products p
  where p.id = any (v_product_ids)
    and not exists (
      select 1 from public.invoice_lines il where il.product_id = p.id
    )
    and not exists (
      select 1 from public.contract_lines cl where cl.product_id = p.id
    );

  delete from public.customer_service_locations csl
  where csl.id = any (v_location_ids);

  delete from public.customers cust
  where cust.id = any (v_customer_ids);
end;
$cleanup$;

alter table public.calendar_events enable row level security;
alter table public.calendar_event_participants enable row level security;
alter table public.calendar_meeting_notices enable row level security;
alter table public.calendar_reminder_plans enable row level security;
alter table public.journal_lines enable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries enable trigger trg_enforce_posted_journal_entry_immutability;
SQL

counts_json="$(docker exec -i "$container_name" psql -U postgres -d postgres -t -A <<'SQL'
select jsonb_build_object(
  'customers', (
    select count(*)::int from public.customers
    where name_ar like '%P7M12%' or name_en like '%P7M12%'
       or phone_primary like '+965500094%'
  ),
  'locations', (
    select count(*)::int from public.customer_service_locations
    where name like '%P7M12%'
  ),
  'products', (
    select count(*)::int from public.products
    where sku like 'P7M12-%' or name_ar like '%P7M12%' or name_en like '%P7M12%'
  ),
  'units', (
    select count(*)::int from public.product_units
    where serial_number like 'P7M12-%'
  ),
  'contracts', (
    select count(*)::int
    from public.contracts c
    join public.customers cu on cu.id = c.customer_id
    where cu.name_ar like '%P7M12%' or cu.name_en like '%P7M12%'
  ),
  'invoices', (
    select count(*)::int
    from public.invoices i
    join public.customers cu on cu.id = i.customer_id
    where cu.name_ar like '%P7M12%' or cu.name_en like '%P7M12%'
  ),
  'vouchers', (
    select count(*)::int
    from public.vouchers v
    join public.customers cu on cu.id = v.customer_id
    where cu.name_ar like '%P7M12%' or cu.name_en like '%P7M12%'
  ),
  'calendar_events', (
    select count(*)::int
    from public.calendar_events ce
    where ce.title_en like '%P7M12%' or ce.title_ar like '%P7M12%'
       or ce.customer_id in (
         select id from public.customers
         where name_ar like '%P7M12%' or name_en like '%P7M12%'
       )
  ),
  'working_date_exceptions', (
    select count(*)::int
    from public.tenant_working_date_exceptions wde
    where wde.title_en like '%P7M12%' or wde.title_ar like '%P7M12%'
  )
)::text;
SQL
)"

printf 'P7M12 cleanup counters: %s\n' "$counts_json"

total="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(sum(d.values()))" "$counts_json")"

if [[ "${total:-1}" != "0" ]]; then
  printf 'P7M12 cleanup failed: fixture rows remain (total=%s)\n' "$total" >&2
  exit 1
fi

printf 'P7M12 cleanup passed: all counters are 0.\n'
