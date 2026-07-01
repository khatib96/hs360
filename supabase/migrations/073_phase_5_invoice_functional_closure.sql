-- M9 invoice functional closure:
-- 1) Cash sales without a customer must still appear in list_sales_invoices.
-- 2) Invoice lines should display a product name/code instead of raw UUIDs.

create or replace function public.fill_invoice_line_description()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.product_id is not null
     and nullif(btrim(coalesce(new.description, '')), '') is null then
    select coalesce(
      nullif(btrim(p.name_ar), ''),
      nullif(btrim(p.name_en), ''),
      nullif(btrim(p.sku), ''),
      new.product_id::text
    )
    into new.description
    from public.products p
    where p.id = new.product_id
      and p.tenant_id = new.tenant_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_fill_invoice_line_description on public.invoice_lines;
create trigger trg_fill_invoice_line_description
  before insert or update of product_id, description on public.invoice_lines
  for each row execute function public.fill_invoice_line_description();

update public.invoice_lines il
set description = coalesce(
  nullif(btrim(p.name_ar), ''),
  nullif(btrim(p.name_en), ''),
  nullif(btrim(p.sku), ''),
  il.product_id::text
)
from public.products p
where p.id = il.product_id
  and p.tenant_id = il.tenant_id
  and nullif(btrim(coalesce(il.description, '')), '') is null;

create or replace function public.list_sales_invoices(
  p_customer_id uuid default null,
  p_status text default null,
  p_date_from date default null,
  p_date_to date default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  invoice_number text,
  customer_id uuid,
  customer_name_ar text,
  customer_name_en text,
  status public.invoice_status,
  date date,
  due_date date,
  subtotal numeric(15, 3),
  discount_amount numeric(15, 3),
  tax_amount numeric(15, 3),
  total numeric(15, 3),
  paid_amount numeric(15, 3),
  outstanding numeric(15, 3),
  currency_code text,
  currency_symbol text,
  currency_decimal_places integer,
  cancelled_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_search text;
  v_cash_name_ar constant text := 'عميل نقدي';
  v_cash_name_en constant text := 'Cash customer';
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_sales_invoice_view();

  v_search := nullif(lower(btrim(coalesce(p_search, ''))), '');

  return query
  select
    i.id,
    i.invoice_number,
    i.customer_id,
    coalesce(c.name_ar, v_cash_name_ar) as customer_name_ar,
    coalesce(c.name_en, v_cash_name_en) as customer_name_en,
    i.status,
    i.date,
    i.due_date,
    i.subtotal,
    i.discount_amount,
    i.tax_amount,
    i.total,
    i.paid_amount,
    (i.total - i.paid_amount) as outstanding,
    cur.iso_code as currency_code,
    coalesce(cur.major_symbol_ar, cur.major_symbol_en) as currency_symbol,
    coalesce(cur.decimal_places, 3) as currency_decimal_places,
    i.cancelled_at
  from public.invoices i
  left join public.customers c
    on c.id = i.customer_id
    and c.tenant_id = i.tenant_id
  join public.tenants t on t.id = i.tenant_id
  left join public.currencies cur on cur.id = t.default_currency_id
  where i.tenant_id = v_tenant_id
    and i.type = 'sales'
    and (p_customer_id is null or i.customer_id = p_customer_id)
    and (p_status is null or i.status::text = p_status)
    and (p_date_from is null or i.date >= p_date_from)
    and (p_date_to is null or i.date <= p_date_to)
    and (
      v_search is null
      or lower(coalesce(i.invoice_number, '')) like '%' || v_search || '%'
      or lower(coalesce(c.name_ar, v_cash_name_ar)) like '%' || v_search || '%'
      or lower(coalesce(c.name_en, v_cash_name_en)) like '%' || v_search || '%'
    )
  order by i.date desc nulls last, i.invoice_number desc nulls last, i.id desc
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.list_sales_invoices(
  uuid, text, date, date, text, integer, integer
) to authenticated;

revoke all on function public.fill_invoice_line_description()
  from public, anon, authenticated;

notify pgrst, 'reload schema';
