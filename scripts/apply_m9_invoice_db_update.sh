#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Applying M9 finance database update..."
PGPASSWORD="${PGPASSWORD:-postgres}" psql \
  -h "${PGHOST:-127.0.0.1}" \
  -p "${PGPORT:-54322}" \
  -U "${PGUSER:-postgres}" \
  -d "${PGDATABASE:-postgres}" \
  -v ON_ERROR_STOP=1 \
  -f supabase/migrations/071_phase_5_cash_sales_direct_returns.sql

PGPASSWORD="${PGPASSWORD:-postgres}" psql \
  -h "${PGHOST:-127.0.0.1}" \
  -p "${PGPORT:-54322}" \
  -U "${PGUSER:-postgres}" \
  -d "${PGDATABASE:-postgres}" \
  -v ON_ERROR_STOP=1 \
  -f supabase/migrations/072_phase_5_cash_sales_conflict_target_fix.sql

PGPASSWORD="${PGPASSWORD:-postgres}" psql \
  -h "${PGHOST:-127.0.0.1}" \
  -p "${PGPORT:-54322}" \
  -U "${PGUSER:-postgres}" \
  -d "${PGDATABASE:-postgres}" \
  -v ON_ERROR_STOP=1 \
  -f supabase/migrations/073_phase_5_invoice_functional_closure.sql

PGPASSWORD="${PGPASSWORD:-postgres}" psql \
  -h "${PGHOST:-127.0.0.1}" \
  -p "${PGPORT:-54322}" \
  -U "${PGUSER:-postgres}" \
  -d "${PGDATABASE:-postgres}" \
  -v ON_ERROR_STOP=1 \
  -f supabase/migrations/074_phase_5_direct_account_receipt_vouchers.sql

PGPASSWORD="${PGPASSWORD:-postgres}" psql \
  -h "${PGHOST:-127.0.0.1}" \
  -p "${PGPORT:-54322}" \
  -U "${PGUSER:-postgres}" \
  -d "${PGDATABASE:-postgres}" \
  -v ON_ERROR_STOP=1 \
  -f supabase/migrations/075_phase_5_voucher_source_account_generalization.sql

echo
echo "Verifying invoice RPCs..."
PGPASSWORD="${PGPASSWORD:-postgres}" psql \
  -h "${PGHOST:-127.0.0.1}" \
  -p "${PGPORT:-54322}" \
  -U "${PGUSER:-postgres}" \
  -d "${PGDATABASE:-postgres}" \
  -v ON_ERROR_STOP=1 \
  -At <<'SQL'
select p.proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'record_cash_sales_invoice',
    'record_direct_sales_return',
    'record_direct_purchase_return',
    'list_sales_invoices',
    'fill_invoice_line_description'
  )
order by p.proname;
SQL

echo
echo "Verifying cash sale stock update target..."
PGPASSWORD="${PGPASSWORD:-postgres}" psql \
  -h "${PGHOST:-127.0.0.1}" \
  -p "${PGPORT:-54322}" \
  -U "${PGUSER:-postgres}" \
  -d "${PGDATABASE:-postgres}" \
  -v ON_ERROR_STOP=1 \
  -At <<'SQL'
do $$
declare
  v_definition text;
begin
  select pg_get_functiondef('public.record_cash_sales_invoice(jsonb, uuid)'::regprocedure)
  into v_definition;

  if v_definition is null
    or position('on conflict (warehouse_id, product_id)' in lower(v_definition)) = 0 then
    raise exception 'record_cash_sales_invoice was not refreshed to the fixed stock conflict target';
  end if;
end;
$$;
select 'cash_sale_stock_update_target_ok';
SQL

echo
echo "Verifying cash invoices list support..."
PGPASSWORD="${PGPASSWORD:-postgres}" psql \
  -h "${PGHOST:-127.0.0.1}" \
  -p "${PGPORT:-54322}" \
  -U "${PGUSER:-postgres}" \
  -d "${PGDATABASE:-postgres}" \
  -v ON_ERROR_STOP=1 \
  -At <<'SQL'
do $$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'public.list_sales_invoices(uuid, text, date, date, text, integer, integer)'::regprocedure
  )
  into v_definition;

  if v_definition is null
    or position('left join public.customers' in lower(v_definition)) = 0 then
    raise exception 'list_sales_invoices was not refreshed for cash invoices without customers';
  end if;
end;
$$;
select 'cash_invoice_list_support_ok';
SQL

echo
echo "Verifying voucher source account support..."
PGPASSWORD="${PGPASSWORD:-postgres}" psql \
  -h "${PGHOST:-127.0.0.1}" \
  -p "${PGPORT:-54322}" \
  -U "${PGUSER:-postgres}" \
  -d "${PGDATABASE:-postgres}" \
  -v ON_ERROR_STOP=1 \
  -At <<'SQL'
do $$
declare
  v_definition text;
begin
  select pg_get_functiondef('public.validate_cash_bank_account(uuid, uuid)'::regprocedure)
  into v_definition;

  if v_definition is null
    or position('v_acct.type <> ''asset''' in lower(v_definition)) > 0 then
    raise exception 'validate_cash_bank_account still rejects non-asset voucher source accounts';
  end if;

  select pg_get_functiondef(
    'public.validate_direct_payment_account(uuid, uuid, uuid)'::regprocedure
  )
  into v_definition;

  if v_definition is null
    or position('code in (''1101'', ''1102'')' in lower(v_definition)) > 0 then
    raise exception 'validate_direct_payment_account still rejects cash/bank counter accounts';
  end if;
end;
$$;
select 'voucher_source_account_generalized_ok';
SQL

echo
echo "Done. Restart the app or try confirming the invoice/voucher again."
