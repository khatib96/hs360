-- Phase 7.5 M4: permission-safe global navigation search and recipient-scoped
-- in-app notification center.

alter table public.notifications
  add column if not exists read_at timestamptz;

update public.notifications
set read_at = coalesce(sent_at, created_at, now())
where status = 'read'::public.notification_status
  and read_at is null;

create index if not exists idx_notifications_recipient_in_app_created
  on public.notifications (tenant_id, recipient_id, created_at desc, id)
  where recipient_type = 'user'
    and channel = 'in_app'::public.notification_channel;

create or replace function public.global_navigation_search(
  p_query text,
  p_limit_per_group integer default 5
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_query text := left(btrim(coalesce(p_query, '')), 80);
  v_query_lower text;
  v_limit integer := least(greatest(coalesce(p_limit_per_group, 5), 1), 10);
  v_items jsonb;
begin
  if auth.uid() is null or v_tenant_id is null then
    raise exception using errcode = 'P0001', message = 'auth_required';
  end if;

  if length(v_query) < 2 then
    return jsonb_build_object('items', '[]'::jsonb);
  end if;

  v_query_lower := lower(v_query);

  with candidates as (
    select
      10 as category_order,
      'customers'::text as category,
      c.id as entity_id,
      c.name_ar as title_ar,
      coalesce(c.name_en, c.name_ar) as title_en,
      c.code as identifier,
      '/customers/' || c.id::text as route
    from public.customers c
    where c.tenant_id = v_tenant_id
      and public.user_has_permission('customers.view')
      and (
        position(v_query_lower in lower(c.code)) > 0
        or position(v_query_lower in lower(c.name_ar)) > 0
        or position(v_query_lower in lower(coalesce(c.name_en, ''))) > 0
      )

    union all

    select
      20,
      'suppliers',
      s.id,
      s.name_ar,
      coalesce(s.name_en, s.name_ar),
      s.code,
      '/suppliers/' || s.id::text
    from public.suppliers s
    where s.tenant_id = v_tenant_id
      and public.user_has_permission('suppliers.view')
      and (
        position(v_query_lower in lower(s.code)) > 0
        or position(v_query_lower in lower(s.name_ar)) > 0
        or position(v_query_lower in lower(coalesce(s.name_en, ''))) > 0
      )

    union all

    select
      30,
      'contracts',
      c.id,
      c.contract_number,
      c.contract_number,
      c.type::text || ' · ' || c.status::text,
      '/contracts/' || c.id::text
    from public.contracts c
    where c.tenant_id = v_tenant_id
      and public.user_has_permission('contracts.view')
      and position(v_query_lower in lower(c.contract_number)) > 0

    union all

    select
      40,
      'invoices',
      i.id,
      i.invoice_number,
      i.invoice_number,
      i.type::text || ' · ' || i.status::text,
      '/invoices/' || i.id::text || '?type=' || i.type::text
    from public.invoices i
    where i.tenant_id = v_tenant_id
      and i.type in (
        'sales'::public.invoice_type,
        'purchase'::public.invoice_type,
        'sales_return'::public.invoice_type,
        'purchase_return'::public.invoice_type
      )
      and (
        public.user_has_permission('invoices.view')
        or (
          i.type = 'sales'::public.invoice_type
          and public.user_has_permission('invoices.view_sales')
        )
        or (
          i.type = 'purchase'::public.invoice_type
          and public.user_has_permission('invoices.view_purchase')
        )
        or (
          i.type in (
            'sales_return'::public.invoice_type,
            'purchase_return'::public.invoice_type
          )
          and public.user_has_permission('invoices.view_returns')
        )
      )
      and position(v_query_lower in lower(i.invoice_number)) > 0

    union all

    select
      50,
      'vouchers',
      v.id,
      v.voucher_number,
      v.voucher_number,
      v.type::text,
      '/vouchers/' || v.id::text
    from public.vouchers v
    where v.tenant_id = v_tenant_id
      and public.user_has_permission('vouchers.view')
      and position(v_query_lower in lower(v.voucher_number)) > 0

    union all

    select
      60,
      'products',
      p.id,
      p.name_ar,
      p.name_en,
      p.sku,
      '/products/' || p.id::text
    from public.products p
    where p.tenant_id = v_tenant_id
      and public.user_has_permission('products.view')
      and (
        position(v_query_lower in lower(p.sku)) > 0
        or position(v_query_lower in lower(p.name_ar)) > 0
        or position(v_query_lower in lower(p.name_en)) > 0
        or position(v_query_lower in lower(coalesce(p.barcode, ''))) > 0
      )

    union all

    select
      70,
      'product_units',
      u.id,
      u.serial_number,
      u.serial_number,
      u.status::text,
      '/product-units/' || u.id::text
    from public.product_units u
    where u.tenant_id = v_tenant_id
      and public.user_has_permission('product_units.view')
      and (
        position(v_query_lower in lower(u.serial_number)) > 0
        or position(v_query_lower in lower(coalesce(u.barcode, ''))) > 0
      )

    union all

    select
      80,
      'inventory_documents',
      d.id,
      d.document_number,
      d.document_number,
      d.document_type::text || ' · ' || d.status::text,
      '/inventory/documents/' || d.id::text
    from public.inventory_documents d
    where d.tenant_id = v_tenant_id
      and public.user_has_permission('inventory_documents.view')
      and position(v_query_lower in lower(d.document_number)) > 0
  ),
  ranked as (
    select
      c.*,
      row_number() over (
        partition by c.category
        order by
          case
            when lower(c.identifier) = v_query_lower then 0
            when lower(c.identifier) like v_query_lower || '%' then 1
            else 2
          end,
          lower(c.identifier),
          c.entity_id
      ) as group_rank
    from candidates c
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'category', r.category,
        'entity_id', r.entity_id,
        'title_ar', r.title_ar,
        'title_en', r.title_en,
        'identifier', r.identifier,
        'route', r.route
      )
      order by r.category_order, r.group_rank
    ),
    '[]'::jsonb
  )
  into v_items
  from ranked r
  where r.group_rank <= v_limit;

  return jsonb_build_object('items', v_items);
end;
$$;

create or replace function public.list_my_in_app_notifications(
  p_limit integer default 30,
  p_before timestamptz default null
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
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 50);
  v_items jsonb;
  v_unread_count integer;
  v_has_more boolean;
begin
  if v_user_id is null or v_tenant_id is null then
    raise exception using errcode = 'P0001', message = 'auth_required';
  end if;

  if not public.user_has_permission('notifications.view') then
    raise exception using errcode = 'P0001', message = 'permission_denied';
  end if;

  with visible_notifications as (
    select
      n.id,
      n.subject,
      n.body_ar,
      n.body_en,
      n.status,
      n.read_at,
      n.created_at,
      n.sent_at,
      case
        when n.related_entity_table = 'calendar_events' then ce.scheduled_date
        when n.related_entity_table = 'calendar_reminder_plans'
          then reminder_event.scheduled_date
        else null
      end as source_date
    from public.notifications n
    left join public.calendar_events ce
      on n.related_entity_table = 'calendar_events'
      and ce.tenant_id = n.tenant_id
      and ce.id = n.related_entity_id
    left join public.calendar_reminder_plans rp
      on n.related_entity_table = 'calendar_reminder_plans'
      and rp.tenant_id = n.tenant_id
      and rp.id = n.related_entity_id
    left join public.calendar_events reminder_event
      on reminder_event.tenant_id = rp.tenant_id
      and reminder_event.id = rp.calendar_event_id
    where n.tenant_id = v_tenant_id
      and n.channel = 'in_app'::public.notification_channel
      and n.recipient_type = 'user'
      and n.recipient_id = v_user_id
      and (
        n.related_entity_table is null
        or (
          n.related_entity_table = 'calendar_events'
          and public.user_has_calendar_event_visibility(
            n.tenant_id,
            v_user_id,
            n.related_entity_id
          )
        )
        or (
          n.related_entity_table = 'calendar_reminder_plans'
          and rp.id is not null
          and public.user_has_calendar_event_visibility(
            rp.tenant_id,
            v_user_id,
            rp.calendar_event_id
          )
        )
      )
  ),
  page as (
    select *
    from visible_notifications v
    where p_before is null or v.created_at < p_before
    order by v.created_at desc, v.id desc
    limit v_limit + 1
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'subject', p.subject,
          'body_ar', p.body_ar,
          'body_en', p.body_en,
          'is_read', p.status = 'read'::public.notification_status,
          'read_at', p.read_at,
          'created_at', p.created_at,
          'source_route',
            case
              when p.source_date is null then null
              else '/calendar?date=' || to_char(p.source_date, 'YYYY-MM-DD')
            end
        )
        order by p.created_at desc, p.id desc
      ) filter (where p.page_rank <= v_limit),
      '[]'::jsonb
    ),
    coalesce(bool_or(p.page_rank > v_limit), false)
  into v_items, v_has_more
  from (
    select page.*, row_number() over (order by page.created_at desc, page.id desc) as page_rank
    from page
  ) p;

  with visible_notifications as (
    select n.status
    from public.notifications n
    left join public.calendar_reminder_plans rp
      on n.related_entity_table = 'calendar_reminder_plans'
      and rp.tenant_id = n.tenant_id
      and rp.id = n.related_entity_id
    where n.tenant_id = v_tenant_id
      and n.channel = 'in_app'::public.notification_channel
      and n.recipient_type = 'user'
      and n.recipient_id = v_user_id
      and (
        n.related_entity_table is null
        or (
          n.related_entity_table = 'calendar_events'
          and public.user_has_calendar_event_visibility(
            n.tenant_id,
            v_user_id,
            n.related_entity_id
          )
        )
        or (
          n.related_entity_table = 'calendar_reminder_plans'
          and rp.id is not null
          and public.user_has_calendar_event_visibility(
            rp.tenant_id,
            v_user_id,
            rp.calendar_event_id
          )
        )
      )
  )
  select count(*)::integer
  into v_unread_count
  from visible_notifications
  where status <> 'read'::public.notification_status;

  return jsonb_build_object(
    'items', v_items,
    'unread_count', v_unread_count,
    'has_more', v_has_more
  );
end;
$$;

create or replace function public.set_my_in_app_notification_read(
  p_notification_id uuid,
  p_read boolean default true
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null or v_tenant_id is null then
    raise exception using errcode = 'P0001', message = 'auth_required';
  end if;

  if not public.user_has_permission('notifications.view') then
    raise exception using errcode = 'P0001', message = 'permission_denied';
  end if;

  update public.notifications n
  set
    status = case
      when coalesce(p_read, true) then 'read'::public.notification_status
      else 'sent'::public.notification_status
    end,
    read_at = case when coalesce(p_read, true) then now() else null end
  where n.id = p_notification_id
    and n.tenant_id = v_tenant_id
    and n.channel = 'in_app'::public.notification_channel
    and n.recipient_type = 'user'
    and n.recipient_id = v_user_id;

  return found;
end;
$$;

revoke all on function public.global_navigation_search(text, integer) from public;
revoke all on function public.list_my_in_app_notifications(integer, timestamptz) from public;
revoke all on function public.set_my_in_app_notification_read(uuid, boolean) from public;

grant execute on function public.global_navigation_search(text, integer) to authenticated;
grant execute on function public.list_my_in_app_notifications(integer, timestamptz) to authenticated;
grant execute on function public.set_my_in_app_notification_read(uuid, boolean) to authenticated;

comment on function public.global_navigation_search(text, integer) is
  'Phase 7.5 M4 capped navigation search. Returns only permission-shaped safe identifiers.';
comment on function public.list_my_in_app_notifications(integer, timestamptz) is
  'Phase 7.5 M4 own-recipient in-app notification list with current source visibility.';
comment on function public.set_my_in_app_notification_read(uuid, boolean) is
  'Phase 7.5 M4 idempotent own-recipient read/unread transition.';
