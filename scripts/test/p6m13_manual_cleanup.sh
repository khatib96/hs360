#!/usr/bin/env bash
# Deterministic cleanup for Phase 6 M13 manual acceptance tags.
# Gate: all P6M13 counters must be 0 after success or failure.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

container_name="${1:-supabase_db_hs360}"

docker exec -i "$container_name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<'SQL'
alter table public.journal_lines disable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries disable trigger trg_enforce_posted_journal_entry_immutability;

do $cleanup$
declare
  v_customer_ids uuid[] := '{}';
  v_location_ids uuid[] := '{}';
  v_product_ids uuid[] := '{}';
  v_unit_ids uuid[] := '{}';
  v_contract_ids uuid[] := '{}';
  v_line_ids uuid[] := '{}';
  v_invoice_ids uuid[] := '{}';
  v_voucher_ids uuid[] := '{}';
  v_journal_ids uuid[] := '{}';
  v_account_ids uuid[] := '{}';
begin
  select coalesce(array_agg(cust.id), '{}'::uuid[])
  into v_customer_ids
  from public.customers cust
  where cust.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and (
      cust.name_ar like '%P6M13%'
      or cust.phone_primary like '+965500093%'
    );

  select coalesce(array_agg(csl.id), '{}'::uuid[])
  into v_location_ids
  from public.customer_service_locations csl
  where csl.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and (
      csl.name like '%P6M13%'
      or csl.customer_id = any (v_customer_ids)
    );

  select coalesce(array_agg(p.id), '{}'::uuid[])
  into v_product_ids
  from public.products p
  where p.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and (
      p.sku like 'P6M13-%'
      or p.name_ar like '%P6M13%'
    );

  select coalesce(array_agg(pu.id), '{}'::uuid[])
  into v_unit_ids
  from public.product_units pu
  where pu.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and (
      pu.product_id = any (v_product_ids)
      or pu.serial_number like 'P6M13-%'
    );

  select coalesce(array_agg(distinct c.id), '{}'::uuid[])
  into v_contract_ids
  from public.contracts c
  where c.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
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
  where i.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and (
      i.customer_id = any (v_customer_ids)
      or i.contract_id = any (v_contract_ids)
    );

  select coalesce(array_agg(v.id), '{}'::uuid[])
  into v_voucher_ids
  from public.vouchers v
  where v.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and (
      v.customer_id = any (v_customer_ids)
      or v.id in (
        select via.voucher_id
        from public.voucher_invoice_allocations via
        where via.invoice_id = any (v_invoice_ids)
      )
    );

  select coalesce(array_agg(distinct je.id), '{}'::uuid[])
  into v_journal_ids
  from public.journal_entries je
  left join public.invoices i on i.journal_entry_id = je.id
  left join public.vouchers v on v.journal_entry_id = je.id
  where je.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and (
      je.source_id = any (v_contract_ids)
      or je.source_id = any (v_invoice_ids)
      or je.source_id = any (v_voucher_ids)
      or i.id = any (v_invoice_ids)
      or v.id = any (v_voucher_ids)
    );

  select coalesce(array_agg(distinct cust.account_id), '{}'::uuid[])
  into v_account_ids
  from public.customers cust
  where cust.id = any (v_customer_ids)
    and cust.account_id is not null;

  delete from public.voucher_invoice_allocations
  where voucher_id = any (v_voucher_ids)
     or invoice_id = any (v_invoice_ids);

  delete from public.rental_invoice_coverages
  where contract_id = any (v_contract_ids)
     or invoice_id = any (v_invoice_ids);

  delete from public.rental_collection_operations
  where invoice_id = any (v_invoice_ids)
     or voucher_id = any (v_voucher_ids);

  delete from public.invoice_lines
  where invoice_id = any (v_invoice_ids);

  update public.invoices
  set journal_entry_id = null
  where id = any (v_invoice_ids);

  update public.vouchers
  set journal_entry_id = null
  where id = any (v_voucher_ids);

  delete from public.journal_lines
  where journal_entry_id = any (v_journal_ids);

  delete from public.journal_entries
  where id = any (v_journal_ids);

  delete from public.vouchers
  where id = any (v_voucher_ids);

  delete from public.invoices
  where id = any (v_invoice_ids);

  delete from public.calendar_reminder_plans
  where calendar_event_id in (
    select ce.id
    from public.calendar_events ce
    where ce.contract_id = any (v_contract_ids)
  );

  delete from public.calendar_event_participants
  where event_id in (
    select ce.id
    from public.calendar_events ce
    where ce.contract_id = any (v_contract_ids)
  );

  delete from public.calendar_refill_execution_facts
  where contract_id = any (v_contract_ids);

  delete from public.calendar_events
  where contract_id = any (v_contract_ids);

  delete from public.contract_oil_changes
  where contract_id = any (v_contract_ids);

  delete from public.contract_lifecycle_operations
  where source_contract_id = any (v_contract_ids)
     or result_contract_id = any (v_contract_ids);

  delete from public.unit_events
  where contract_id = any (v_contract_ids)
     or product_unit_id = any (v_unit_ids);

  delete from public.inventory_movements
  where contract_line_id = any (v_line_ids)
     or product_unit_id = any (v_unit_ids)
     or product_id = any (v_product_ids)
     or reference_id = any (v_contract_ids);

  update public.product_units
  set
    current_contract_id = null,
    current_customer_id = null,
    current_service_location_id = null,
    status = 'available_new',
    updated_at = now()
  where id = any (v_unit_ids);

  perform public.allow_contract_write();

  delete from public.contract_lines
  where contract_id = any (v_contract_ids);

  delete from public.contracts
  where id = any (v_contract_ids);

  delete from public.inventory_balances
  where product_id = any (v_product_ids);

  delete from public.product_units
  where id = any (v_unit_ids);

  delete from public.products
  where id = any (v_product_ids);

  delete from public.customer_service_locations
  where id = any (v_location_ids);

  delete from public.customers
  where id = any (v_customer_ids);

  delete from public.chart_of_accounts
  where id = any (v_account_ids);

  -- collect_rental_payment provisions SYS-RENTAL-MONTHLY; remove when orphaned.
  delete from public.inventory_balances ib
  using public.products p
  where p.id = ib.product_id
    and p.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and p.sku = 'SYS-RENTAL-MONTHLY'
    and not exists (
      select 1 from public.invoice_lines il where il.product_id = p.id
    )
    and not exists (
      select 1 from public.contract_lines cl where cl.product_id = p.id
    );

  delete from public.products p
  where p.tenant_id = '00000000-0000-0000-0000-000000000101'::uuid
    and p.sku = 'SYS-RENTAL-MONTHLY'
    and not exists (
      select 1 from public.invoice_lines il where il.product_id = p.id
    )
    and not exists (
      select 1 from public.contract_lines cl where cl.product_id = p.id
    );
end;
$cleanup$;

alter table public.journal_lines enable trigger trg_enforce_posted_journal_line_immutability;
alter table public.journal_entries enable trigger trg_enforce_posted_journal_entry_immutability;
SQL

counts_json="$(docker exec -i "$container_name" psql -U postgres -d postgres -t -A <<'SQL'
select jsonb_build_object(
  'customers', (
    select count(*)::int from public.customers
    where name_ar like '%P6M13%' or phone_primary like '+965500093%'
  ),
  'locations', (
    select count(*)::int from public.customer_service_locations
    where name like '%P6M13%'
  ),
  'products', (
    select count(*)::int from public.products
    where sku like 'P6M13-%' or name_ar like '%P6M13%'
  ),
  'units', (
    select count(*)::int from public.product_units
    where serial_number like 'P6M13-%'
  ),
  'contracts', (
    select count(*)::int
    from public.contracts c
    join public.customers cu on cu.id = c.customer_id
    where cu.name_ar like '%P6M13%'
  ),
  'invoices', (
    select count(*)::int
    from public.invoices i
    join public.customers cu on cu.id = i.customer_id
    where cu.name_ar like '%P6M13%'
  ),
  'vouchers', (
    select count(*)::int
    from public.vouchers v
    join public.customers cu on cu.id = v.customer_id
    where cu.name_ar like '%P6M13%'
  ),
  'coverages', (
    select count(*)::int
    from public.rental_invoice_coverages ric
    join public.invoices i on i.id = ric.invoice_id
    join public.customers cu on cu.id = i.customer_id
    where cu.name_ar like '%P6M13%'
  ),
  'lifecycle_ops', (
    select count(*)::int
    from public.contract_lifecycle_operations clo
    join public.contracts c on c.id = clo.source_contract_id
    join public.customers cu on cu.id = c.customer_id
    where cu.name_ar like '%P6M13%'
  ),
  'calendar_events', (
    select count(*)::int
    from public.calendar_events ce
    join public.contracts c on c.id = ce.contract_id
    join public.customers cu on cu.id = c.customer_id
    where cu.name_ar like '%P6M13%'
  )
)::text;
SQL
)"

printf 'P6M13 cleanup counters: %s\n' "$counts_json"

total="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(sum(d.values()))" "$counts_json")"

if [[ "${total:-1}" != "0" ]]; then
  printf 'P6M13 cleanup failed: fixture rows remain (total=%s)\n' "$total" >&2
  exit 1
fi

printf 'P6M13 cleanup passed: all counters are 0.\n'
