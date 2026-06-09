-- Phase 5 M3: document templates, tenant document settings, and print RPCs.

-- ---------------------------------------------------------------------------
-- Constants (provisional statement row limit — tune after client perf gate)
-- ---------------------------------------------------------------------------
create or replace function public.m3_statement_row_limit()
returns integer
language sql
immutable
set search_path = public
as $$
  select 1000;
$$;

revoke all on function public.m3_statement_row_limit() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table public.document_templates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  template_key text not null,
  document_type text not null,
  name_ar text not null,
  name_en text not null,
  language_mode text not null default 'bilingual',
  paper_kind text not null,
  schema_version int not null default 1,
  body_json jsonb not null,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  unique (tenant_id, template_key),
  constraint chk_document_templates_type check (
    document_type in (
      'sales_invoice', 'purchase_invoice', 'receipt_voucher',
      'payment_voucher', 'customer_statement', 'asset_tag_label'
    )
  ),
  constraint chk_document_templates_language check (
    language_mode in ('ar', 'en', 'bilingual')
  ),
  constraint chk_document_templates_paper check (
    paper_kind in ('a4', 'thermal_80mm', 'label_sheet')
  ),
  constraint chk_document_templates_schema_version check (schema_version = 1),
  constraint chk_document_templates_body_size check (
    octet_length(body_json::text) <= 32768
  ),
  constraint chk_document_templates_default_active check (not is_default or is_active),
  constraint chk_document_templates_body_schema_version check (
    (body_json ->> 'schema_version')::int = schema_version
  )
);

create index idx_document_templates_tenant on public.document_templates (tenant_id);
create index idx_document_templates_tenant_type on public.document_templates (tenant_id, document_type, is_active);

create unique index ux_document_templates_default
  on public.document_templates (tenant_id, document_type, paper_kind)
  where is_default = true and is_active = true;

create table public.tenant_document_settings (
  tenant_id uuid primary key references public.tenants (id) on delete cascade,
  logo_url text,
  primary_color text,
  secondary_color text,
  default_language text not null default 'bilingual',
  invoice_paper_kind text not null default 'a4',
  voucher_paper_kind text not null default 'a4',
  asset_label_paper_kind text not null default 'label_sheet',
  header_json jsonb not null default '{}'::jsonb,
  footer_json jsonb not null default '{}'::jsonb,
  optional_columns_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  constraint chk_tds_default_language check (
    default_language in ('ar', 'en', 'bilingual')
  ),
  constraint chk_tds_invoice_paper check (invoice_paper_kind = 'a4'),
  constraint chk_tds_voucher_paper check (
    voucher_paper_kind in ('a4', 'thermal_80mm')
  ),
  constraint chk_tds_asset_paper check (asset_label_paper_kind = 'label_sheet'),
  constraint chk_tds_primary_color check (
    primary_color is null or primary_color ~ '^#[0-9A-Fa-f]{6}$'
  ),
  constraint chk_tds_secondary_color check (
    secondary_color is null or secondary_color ~ '^#[0-9A-Fa-f]{6}$'
  ),
  constraint chk_tds_header_object check (jsonb_typeof(header_json) = 'object'),
  constraint chk_tds_footer_object check (jsonb_typeof(footer_json) = 'object'),
  constraint chk_tds_optional_object check (jsonb_typeof(optional_columns_json) = 'object'),
  constraint chk_tds_header_size check (octet_length(header_json::text) <= 4096),
  constraint chk_tds_footer_size check (octet_length(footer_json::text) <= 4096),
  constraint chk_tds_optional_columns_size check (
    octet_length(optional_columns_json::text) <= 4096
  )
);

-- ---------------------------------------------------------------------------
-- Seed settings helpers
-- ---------------------------------------------------------------------------
create or replace function public.m3_a4_settings()
returns jsonb
language sql
immutable
set search_path = public
as $$
  select jsonb_build_object(
    'page_margin_mm', jsonb_build_object('top', 12, 'right', 12, 'bottom', 12, 'left', 12),
    'base_font_size_pt', 10,
    'line_height', 1.35,
    'show_logo', true,
    'logo_max_height_mm', 18,
    'table_header_repeat', true,
    'digit_style', 'western'
  );
$$;

create or replace function public.m3_thermal_settings()
returns jsonb
language sql
immutable
set search_path = public
as $$
  select jsonb_build_object(
    'page_margin_mm', jsonb_build_object('top', 4, 'right', 4, 'bottom', 4, 'left', 4),
    'base_font_size_pt', 9,
    'line_height', 1.35,
    'show_logo', true,
    'logo_max_height_mm', 12,
    'digit_style', 'western',
    'thermal_content_width_mm', 72
  );
$$;

create or replace function public.m3_label_settings()
returns jsonb
language sql
immutable
set search_path = public
as $$
  select jsonb_build_object(
    'page_margin_mm', jsonb_build_object('top', 2, 'right', 2, 'bottom', 2, 'left', 2),
    'base_font_size_pt', 6,
    'line_height', 1.35,
    'show_logo', true,
    'logo_max_height_mm', 5,
    'digit_style', 'western',
    'label_width_mm', 50,
    'label_height_mm', 30,
    'qr_size_mm', 14,
    'label_layout', 'horizontal'
  );
$$;

revoke all on function public.m3_a4_settings() from public, anon, authenticated;
revoke all on function public.m3_thermal_settings() from public, anon, authenticated;
revoke all on function public.m3_label_settings() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Template body validator (seed + RPC defense)
-- ---------------------------------------------------------------------------
create or replace function public.m3_allowed_block_types(
  p_document_type text,
  p_paper_kind text
)
returns text[]
language sql
immutable
set search_path = public
as $$
  select case
    when p_document_type in ('sales_invoice', 'purchase_invoice') and p_paper_kind = 'a4' then
      array[
        'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals',
        'notes', 'footer', 'spacer', 'divider'
      ]
    when p_document_type = 'receipt_voucher' and p_paper_kind = 'a4' then
      array[
        'tenant_header', 'document_meta', 'party_details', 'payment_details',
        'notes', 'footer', 'spacer', 'divider'
      ]
    when p_document_type = 'receipt_voucher' and p_paper_kind = 'thermal_80mm' then
      array[
        'tenant_header', 'document_meta', 'payment_details',
        'notes', 'footer', 'spacer', 'divider'
      ]
    when p_document_type = 'customer_statement' and p_paper_kind = 'a4' then
      array[
        'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals',
        'notes', 'footer', 'spacer', 'divider'
      ]
    when p_document_type = 'asset_tag_label' and p_paper_kind = 'label_sheet' then
      array['tenant_header', 'asset_identity', 'qr_code', 'spacer', 'divider']
    else array[]::text[]
  end;
$$;

create or replace function public.m3_block_field_allowlist(
  p_document_type text,
  p_paper_kind text,
  p_block_type text
)
returns text[]
language sql
immutable
set search_path = public
as $$
  select case
    when p_block_type = 'document_meta' and p_document_type in ('sales_invoice', 'purchase_invoice') then
      array['document.number', 'document.date', 'document.due_date']
    when p_block_type = 'document_meta' and p_document_type = 'receipt_voucher' then
      array['document.number', 'document.date']
    when p_block_type = 'document_meta' and p_document_type = 'customer_statement' then
      array['document.from_date', 'document.to_date', 'document.generated_at']
    when p_block_type = 'party_details'
      and p_document_type in ('sales_invoice', 'purchase_invoice', 'customer_statement') then
      array['party.name_ar', 'party.name_en', 'party.code']
    when p_block_type = 'party_details'
      and p_document_type = 'receipt_voucher' and p_paper_kind = 'a4' then
      array['party.name_ar', 'party.name_en']
    when p_block_type = 'line_table' and p_document_type in ('sales_invoice', 'purchase_invoice') then
      array['line.description', 'line.qty', 'line.unit_price', 'line.total']
    when p_block_type = 'line_table' and p_document_type = 'customer_statement' then
      array['line.date', 'line.description', 'line.debit', 'line.credit', 'line.balance']
    when p_block_type = 'totals' and p_document_type in ('sales_invoice', 'purchase_invoice') then
      array['totals.subtotal', 'totals.discount', 'totals.tax', 'totals.total']
    when p_block_type = 'totals' and p_document_type = 'customer_statement' then
      array[
        'summary.opening_balance', 'summary.total_debit',
        'summary.total_credit', 'summary.closing_balance'
      ]
    when p_block_type = 'payment_details'
      and p_document_type = 'receipt_voucher' and p_paper_kind = 'a4' then
      array['payment.amount', 'payment.method', 'payment.reference', 'payment.collected_by']
    when p_block_type = 'payment_details'
      and p_document_type = 'receipt_voucher' and p_paper_kind = 'thermal_80mm' then
      array['payment.amount', 'payment.method', 'payment.reference']
    when p_block_type = 'notes' then
      array['document.notes']
    when p_block_type = 'asset_identity' and p_document_type = 'asset_tag_label' then
      array['tenant.company_name_ar', 'product.name_ar', 'product.name_en', 'unit.serial']
    else null::text[]
  end;
$$;

create or replace function public.m3_required_party_role(
  p_document_type text,
  p_paper_kind text
)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_document_type = 'sales_invoice' then 'customer'
    when p_document_type = 'purchase_invoice' then 'supplier'
    when p_document_type = 'receipt_voucher' and p_paper_kind = 'a4' then 'customer'
    when p_document_type = 'customer_statement' then 'customer'
    else null
  end;
$$;

create or replace function public.m3_validate_template_settings(
  p_settings jsonb,
  p_paper_kind text
)
returns void
language plpgsql
immutable
set search_path = public
as $$
declare
  v_key text;
  v_allowed text[];
  v_margin jsonb;
  v_margin_key text;
  v_margin_val numeric;
  v_left numeric;
  v_right numeric;
  v_top numeric;
  v_bottom numeric;
  v_thermal_width numeric;
  v_label_width numeric;
  v_label_height numeric;
  v_qr_size numeric;
  v_logo_h numeric;
  v_show_logo boolean;
  v_label_text_gap_mm constant numeric := 1;
  v_usable_width numeric;
  v_usable_height numeric;
begin
  if jsonb_typeof(p_settings) <> 'object' then
    raise exception 'invalid_document_template: settings must be object';
  end if;

  v_allowed := case p_paper_kind
    when 'a4' then array[
      'page_margin_mm', 'base_font_size_pt', 'line_height', 'show_logo',
      'logo_max_height_mm', 'table_header_repeat', 'digit_style'
    ]
    when 'thermal_80mm' then array[
      'page_margin_mm', 'base_font_size_pt', 'line_height', 'show_logo',
      'logo_max_height_mm', 'digit_style', 'thermal_content_width_mm'
    ]
    when 'label_sheet' then array[
      'page_margin_mm', 'base_font_size_pt', 'line_height', 'show_logo',
      'logo_max_height_mm', 'digit_style', 'label_width_mm', 'label_height_mm',
      'qr_size_mm', 'label_layout'
    ]
    else array[]::text[]
  end;

  for v_key in select jsonb_object_keys(p_settings) loop
    if not v_key = any (v_allowed) then
      raise exception 'invalid_document_template: unknown settings key %', v_key;
    end if;
  end loop;

  if not (p_settings ?& array[
    'page_margin_mm', 'base_font_size_pt', 'line_height', 'show_logo',
    'logo_max_height_mm', 'digit_style'
  ]) then
    raise exception 'invalid_document_template: missing required settings keys';
  end if;

  if p_paper_kind = 'a4' and not p_settings ? 'table_header_repeat' then
    raise exception 'invalid_document_template: missing table_header_repeat';
  end if;

  if p_paper_kind = 'thermal_80mm' and not p_settings ? 'thermal_content_width_mm' then
    raise exception 'invalid_document_template: missing thermal_content_width_mm';
  end if;

  if p_paper_kind = 'label_sheet'
    and not (p_settings ?& array['label_width_mm', 'label_height_mm', 'qr_size_mm', 'label_layout']) then
    raise exception 'invalid_document_template: missing label settings keys';
  end if;

  v_margin := p_settings -> 'page_margin_mm';
  if jsonb_typeof(v_margin) <> 'object' then
    raise exception 'invalid_document_template: page_margin_mm must be object';
  end if;

  for v_margin_key in select jsonb_object_keys(v_margin) loop
    if v_margin_key not in ('top', 'right', 'bottom', 'left') then
      raise exception 'invalid_document_template: unknown margin key %', v_margin_key;
    end if;
  end loop;

  foreach v_margin_key in array array['top', 'right', 'bottom', 'left'] loop
    if not (v_margin ? v_margin_key) then
      raise exception 'invalid_document_template: missing margin %', v_margin_key;
    end if;
    if jsonb_typeof(v_margin -> v_margin_key) <> 'number' then
      raise exception 'invalid_document_template: margin must be numeric';
    end if;
    v_margin_val := (v_margin ->> v_margin_key)::numeric;
    if v_margin_val < 0 or v_margin_val > 40 then
      raise exception 'invalid_document_template: margin out of range';
    end if;
  end loop;

  if jsonb_typeof(p_settings -> 'base_font_size_pt') <> 'number'
    or (p_settings ->> 'base_font_size_pt')::numeric < 6
    or (p_settings ->> 'base_font_size_pt')::numeric > 24 then
    raise exception 'invalid_document_template: base_font_size_pt out of range';
  end if;

  if jsonb_typeof(p_settings -> 'line_height') <> 'number'
    or (p_settings ->> 'line_height')::numeric < 1.0
    or (p_settings ->> 'line_height')::numeric > 2.5 then
    raise exception 'invalid_document_template: line_height out of range';
  end if;

  if jsonb_typeof(p_settings -> 'show_logo') <> 'boolean' then
    raise exception 'invalid_document_template: show_logo must be boolean';
  end if;

  v_show_logo := (p_settings ->> 'show_logo')::boolean;

  if jsonb_typeof(p_settings -> 'logo_max_height_mm') <> 'number'
    or (p_settings ->> 'logo_max_height_mm')::numeric < 0
    or (p_settings ->> 'logo_max_height_mm')::numeric > 40 then
    raise exception 'invalid_document_template: logo_max_height_mm out of range';
  end if;

  if jsonb_typeof(p_settings -> 'digit_style') <> 'string'
    or p_settings ->> 'digit_style' <> 'western' then
    raise exception 'invalid_document_template: digit_style must be western';
  end if;

  if p_paper_kind = 'a4' then
    if jsonb_typeof(p_settings -> 'table_header_repeat') <> 'boolean' then
      raise exception 'invalid_document_template: table_header_repeat must be boolean';
    end if;
  end if;

  if p_paper_kind = 'thermal_80mm' then
    if jsonb_typeof(p_settings -> 'thermal_content_width_mm') <> 'number' then
      raise exception 'invalid_document_template: thermal_content_width_mm must be numeric';
    end if;
    v_thermal_width := (p_settings ->> 'thermal_content_width_mm')::numeric;
    if v_thermal_width < 40 or v_thermal_width > 72 then
      raise exception 'invalid_document_template: thermal_content_width_mm out of range';
    end if;
    v_left := (v_margin ->> 'left')::numeric;
    v_right := (v_margin ->> 'right')::numeric;
    if v_left + v_thermal_width + v_right > 80 then
      raise exception 'invalid_document_template: thermal geometry exceeds 80mm';
    end if;
  end if;

  if p_paper_kind = 'label_sheet' then
    if jsonb_typeof(p_settings -> 'label_width_mm') <> 'number'
      or jsonb_typeof(p_settings -> 'label_height_mm') <> 'number'
      or jsonb_typeof(p_settings -> 'qr_size_mm') <> 'number' then
      raise exception 'invalid_document_template: label dimensions must be numeric';
    end if;
    v_label_width := (p_settings ->> 'label_width_mm')::numeric;
    v_label_height := (p_settings ->> 'label_height_mm')::numeric;
    v_qr_size := (p_settings ->> 'qr_size_mm')::numeric;
    v_logo_h := (p_settings ->> 'logo_max_height_mm')::numeric;

    if v_label_width < 20 or v_label_width > 100 then
      raise exception 'invalid_document_template: label_width_mm out of range';
    end if;
    if v_label_height < 10 or v_label_height > 80 then
      raise exception 'invalid_document_template: label_height_mm out of range';
    end if;
    if v_qr_size < 8 or v_qr_size > 40 then
      raise exception 'invalid_document_template: qr_size_mm out of range';
    end if;
    if jsonb_typeof(p_settings -> 'label_layout') <> 'string'
      or p_settings ->> 'label_layout' <> 'horizontal' then
      raise exception 'invalid_document_template: label_layout must be horizontal';
    end if;

    v_left := (v_margin ->> 'left')::numeric;
    v_right := (v_margin ->> 'right')::numeric;
    v_top := (v_margin ->> 'top')::numeric;
    v_bottom := (v_margin ->> 'bottom')::numeric;

    if v_left + v_qr_size + v_right > v_label_width then
      raise exception 'invalid_document_template: label horizontal geometry invalid';
    end if;
    if v_top + v_qr_size + v_bottom > v_label_height then
      raise exception 'invalid_document_template: label vertical geometry invalid';
    end if;
    if v_show_logo and v_top + v_logo_h + v_bottom > v_label_height then
      raise exception 'invalid_document_template: label logo geometry invalid';
    end if;

    v_usable_width := v_label_width - v_left - v_right - v_qr_size - v_label_text_gap_mm;
    v_usable_height := v_label_height - v_top - v_bottom;
    if v_usable_width < 18 then
      raise exception 'invalid_document_template: label usable width too small';
    end if;
    if v_usable_height < 10 then
      raise exception 'invalid_document_template: label usable height too small';
    end if;
  end if;
end;
$$;

revoke all on function public.m3_allowed_block_types(text, text) from public, anon, authenticated;
revoke all on function public.m3_block_field_allowlist(text, text, text) from public, anon, authenticated;
revoke all on function public.m3_required_party_role(text, text) from public, anon, authenticated;
revoke all on function public.m3_validate_template_settings(jsonb, text) from public, anon, authenticated;

create or replace function public.validate_document_template_body(
  p_document_type text,
  p_body jsonb,
  p_paper_kind text,
  p_schema_version int
)
returns void
language plpgsql
immutable
set search_path = public
as $$
declare
  v_key text;
  v_block jsonb;
  v_type text;
  v_types text[] := '{}'::text[];
  v_ids text[] := '{}'::text[];
  v_required text[];
  v_allowed_types text[];
  v_allowed_keys text[];
  v_allowlist text[];
  v_singletons text[] := array[
    'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals',
    'payment_details', 'notes', 'footer', 'asset_identity', 'qr_code'
  ];
  v_col jsonb;
  v_col_key text;
  v_col_fields text[] := '{}'::text[];
  v_field text;
  v_fields jsonb;
  v_seen_fields text[] := '{}'::text[];
  v_field_count int;
  v_width_sum int := 0;
  v_party_role text;
begin
  if p_document_type = 'payment_voucher' then
    raise exception 'unsupported_document_type';
  end if;

  if p_body is null or jsonb_typeof(p_body) <> 'object' then
    raise exception 'invalid_document_template: root must be object';
  end if;

  for v_key in select jsonb_object_keys(p_body) loop
    if v_key not in ('schema_version', 'settings', 'blocks') then
      raise exception 'invalid_document_template: unknown root key %', v_key;
    end if;
  end loop;

  if (p_body ->> 'schema_version')::int is distinct from 1 then
    raise exception 'invalid_document_template: schema_version must be 1';
  end if;

  if (p_body ->> 'schema_version')::int is distinct from p_schema_version then
    raise exception 'invalid_document_template: schema_version mismatch';
  end if;

  if not (p_body ? 'settings') or jsonb_typeof(p_body -> 'settings') <> 'object' then
    raise exception 'invalid_document_template: settings must be object';
  end if;

  if not (p_body ? 'blocks') or jsonb_typeof(p_body -> 'blocks') <> 'array' then
    raise exception 'invalid_document_template: blocks must be array';
  end if;

  if jsonb_array_length(p_body -> 'blocks') < 1
    or jsonb_array_length(p_body -> 'blocks') > 40 then
    raise exception 'invalid_document_template: blocks length out of range';
  end if;

  perform public.m3_validate_template_settings(p_body -> 'settings', p_paper_kind);

  v_allowed_types := public.m3_allowed_block_types(p_document_type, p_paper_kind);
  if v_allowed_types = array[]::text[] then
    raise exception 'unsupported_document_type';
  end if;

  for v_block in select value from jsonb_array_elements(p_body -> 'blocks') loop
    v_type := v_block ->> 'type';
    if v_type is null then
      raise exception 'invalid_document_template: block missing type';
    end if;

    if not v_type = any (v_allowed_types) then
      raise exception 'invalid_document_template: block type % not allowed', v_type;
    end if;

    v_types := array_append(v_types, v_type);

    v_allowed_keys := case v_type
      when 'spacer' then array['type', 'id', 'height_mm']
      when 'divider' then array['type', 'id']
      when 'tenant_header' then array['type', 'id']
      when 'document_meta' then array['type', 'id', 'fields']
      when 'party_details' then array['type', 'id', 'party_role', 'fields']
      when 'line_table' then array['type', 'id', 'columns', 'fields']
      when 'totals' then array['type', 'id', 'fields']
      when 'payment_details' then array['type', 'id', 'fields']
      when 'notes' then array['type', 'id', 'fields']
      when 'footer' then array['type', 'id', 'source']
      when 'asset_identity' then array['type', 'id', 'fields']
      when 'qr_code' then array['type', 'id', 'payload_field', 'caption_field']
      else array[]::text[]
    end;

    for v_key in select jsonb_object_keys(v_block) loop
      if not v_key = any (v_allowed_keys) then
        raise exception 'invalid_document_template: unknown key % in block %', v_key, v_type;
      end if;
    end loop;

    if v_block ->> 'id' is null or v_block ->> 'id' !~ '^[A-Za-z0-9_-]{1,64}$' then
      raise exception 'invalid_document_template: invalid block id';
    end if;

    if v_block ->> 'id' = any (v_ids) then
      raise exception 'invalid_document_template: duplicate block id';
    end if;
    v_ids := array_append(v_ids, v_block ->> 'id');

    if v_type = 'spacer' then
      if not (v_block ? 'height_mm') then
        raise exception 'invalid_document_template: spacer missing height_mm';
      end if;
      if (v_block ->> 'height_mm')::numeric < 1 or (v_block ->> 'height_mm')::numeric > 200 then
        raise exception 'invalid_document_template: spacer height_mm out of range';
      end if;
    end if;

    if v_type = 'party_details' then
      v_party_role := public.m3_required_party_role(p_document_type, p_paper_kind);
      if v_party_role is null or v_block ->> 'party_role' is distinct from v_party_role then
        raise exception 'invalid_document_template: invalid party_role';
      end if;
    end if;

    if v_type = 'footer' then
      if v_block ->> 'source' is distinct from 'tenant_footer' then
        raise exception 'invalid_document_template: footer source must be tenant_footer';
      end if;
    end if;

    if v_type = 'qr_code' then
      if v_block ->> 'payload_field' is distinct from 'unit.serial' then
        raise exception 'invalid_document_template: invalid qr_code payload_field';
      end if;
      if v_block ? 'caption_field'
        and v_block ->> 'caption_field' is not null
        and v_block ->> 'caption_field' is distinct from 'unit.serial' then
        raise exception 'invalid_document_template: invalid qr_code caption_field';
      end if;
    end if;

    if v_type = 'line_table' then
      if jsonb_typeof(v_block -> 'columns') <> 'array' then
        raise exception 'invalid_document_template: line_table missing columns';
      end if;
      if jsonb_array_length(v_block -> 'columns') < 1
        or jsonb_array_length(v_block -> 'columns') > 20 then
        raise exception 'invalid_document_template: columns length out of range';
      end if;

      v_width_sum := 0;
      v_col_fields := '{}'::text[];

      for v_col in select value from jsonb_array_elements(v_block -> 'columns') loop
        if jsonb_typeof(v_col) <> 'object' then
          raise exception 'invalid_document_template: column must be object';
        end if;
        for v_col_key in select jsonb_object_keys(v_col) loop
          if v_col_key not in ('field', 'label_key', 'label_ar', 'label_en', 'width_pct', 'align') then
            raise exception 'invalid_document_template: unknown column key %', v_col_key;
          end if;
        end loop;

        if not (v_col ?& array[
          'field', 'label_key', 'label_ar', 'label_en', 'width_pct', 'align'
        ]) then
          raise exception 'invalid_document_template: column missing required key';
        end if;

        if jsonb_typeof(v_col -> 'field') <> 'string'
          or nullif(v_col ->> 'field', '') is null then
          raise exception 'invalid_document_template: column missing field';
        end if;

        if v_col ->> 'field' = any (v_col_fields) then
          raise exception 'invalid_document_template: duplicate column field';
        end if;
        v_col_fields := array_append(v_col_fields, v_col ->> 'field');

        if jsonb_typeof(v_col -> 'width_pct') <> 'number'
          or (v_col ->> 'width_pct')::numeric <> trunc((v_col ->> 'width_pct')::numeric)
          or (v_col ->> 'width_pct')::numeric < 1
          or (v_col ->> 'width_pct')::numeric > 100 then
          raise exception 'invalid_document_template: width_pct out of range';
        end if;
        v_width_sum := v_width_sum + (v_col ->> 'width_pct')::int;

        if jsonb_typeof(v_col -> 'align') <> 'string'
          or v_col ->> 'align' not in ('start', 'center', 'end') then
          raise exception 'invalid_document_template: invalid column align';
        end if;

        if jsonb_typeof(v_col -> 'label_key') <> 'string'
          or nullif(v_col ->> 'label_key', '') is null
          or jsonb_typeof(v_col -> 'label_ar') <> 'string'
          or jsonb_typeof(v_col -> 'label_en') <> 'string'
          or length(v_col ->> 'label_ar') > 128
          or length(v_col ->> 'label_en') > 128 then
          raise exception 'invalid_document_template: invalid column labels';
        end if;
      end loop;

      if v_width_sum <> 100 then
        raise exception 'invalid_document_template: column widths must sum to 100';
      end if;

      if v_block ? 'fields' then
        if jsonb_typeof(v_block -> 'fields') <> 'array' then
          raise exception 'invalid_document_template: line_table fields must be array';
        end if;
        if jsonb_array_length(v_block -> 'fields') <> cardinality(v_col_fields) then
          raise exception 'invalid_document_template: line_table fields must match columns';
        end if;
        for v_field in select value::text from jsonb_array_elements_text(v_block -> 'fields') loop
          if not v_field = any (v_col_fields) then
            raise exception 'invalid_document_template: line_table field not in columns';
          end if;
        end loop;
      end if;
    end if;

    v_allowlist := public.m3_block_field_allowlist(p_document_type, p_paper_kind, v_type);

    if v_type in ('document_meta', 'party_details', 'totals', 'payment_details', 'asset_identity') then
      if not (v_block ? 'fields') or jsonb_typeof(v_block -> 'fields') <> 'array' then
        raise exception 'invalid_document_template: block % missing fields', v_type;
      end if;
      v_field_count := jsonb_array_length(v_block -> 'fields');
      if v_field_count < 1 or v_field_count > 32 then
        raise exception 'invalid_document_template: fields length out of range';
      end if;
      v_fields := v_block -> 'fields';
      v_seen_fields := '{}'::text[];
      for v_field in select value::text from jsonb_array_elements_text(v_fields) loop
        if v_field = any (v_seen_fields) then
          raise exception 'invalid_document_template: duplicate field %', v_field;
        end if;
        v_seen_fields := array_append(v_seen_fields, v_field);
        if not v_field = any (v_allowlist) then
          raise exception 'invalid_document_template: field % not allowed in %', v_field, v_type;
        end if;
      end loop;
    elsif v_type = 'notes' and v_block ? 'fields' then
      if jsonb_typeof(v_block -> 'fields') <> 'array' then
        raise exception 'invalid_document_template: notes fields must be array';
      end if;
      v_field_count := jsonb_array_length(v_block -> 'fields');
      if v_field_count < 1 or v_field_count > 32 then
        raise exception 'invalid_document_template: fields length out of range';
      end if;
      for v_field in select value::text from jsonb_array_elements_text(v_block -> 'fields') loop
        if v_field <> 'document.notes' then
          raise exception 'invalid_document_template: notes field must be document.notes';
        end if;
      end loop;
    end if;
  end loop;

  foreach v_type in array v_singletons loop
    if (select count(*) from unnest(v_types) t where t = v_type) > 1 then
      raise exception 'invalid_document_template: duplicate singleton block %', v_type;
    end if;
  end loop;

  v_required := case
    when p_document_type = 'sales_invoice' then array[
      'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals', 'footer'
    ]
    when p_document_type = 'purchase_invoice' then array[
      'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals', 'footer'
    ]
    when p_document_type = 'receipt_voucher' and p_paper_kind = 'thermal_80mm' then array[
      'tenant_header', 'document_meta', 'payment_details', 'footer'
    ]
    when p_document_type = 'receipt_voucher' then array[
      'tenant_header', 'document_meta', 'party_details', 'payment_details', 'footer'
    ]
    when p_document_type = 'customer_statement' then array[
      'tenant_header', 'document_meta', 'party_details', 'line_table', 'totals', 'footer'
    ]
    when p_document_type = 'asset_tag_label' then array[
      'tenant_header', 'asset_identity', 'qr_code'
    ]
    else array[]::text[]
  end;

  foreach v_type in array v_required loop
    if not v_type = any (v_types) then
      raise exception 'invalid_document_template: missing required block %', v_type;
    end if;
  end loop;
end;
$$;

drop function if exists public.validate_document_template_body(text, jsonb, text);

create or replace function public.trg_validate_document_template_body()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform public.validate_document_template_body(
    new.document_type, new.body_json, new.paper_kind, new.schema_version
  );
  if (new.body_json ->> 'schema_version')::int is distinct from new.schema_version then
    raise exception 'invalid_document_template: body schema_version mismatch';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_document_template_body on public.document_templates;
create trigger trg_validate_document_template_body
  before insert or update of body_json, document_type, paper_kind, schema_version
  on public.document_templates
  for each row execute function public.trg_validate_document_template_body();

-- ---------------------------------------------------------------------------
-- Default template bodies
-- ---------------------------------------------------------------------------
create or replace function public.m3_default_template_body(p_template_key text)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_invoice_columns jsonb := jsonb_build_array(
    jsonb_build_object(
      'field', 'line.description', 'label_key', 'col.description',
      'label_ar', 'الوصف', 'label_en', 'Description', 'width_pct', 40, 'align', 'start'
    ),
    jsonb_build_object(
      'field', 'line.qty', 'label_key', 'col.qty',
      'label_ar', 'الكمية', 'label_en', 'Qty', 'width_pct', 15, 'align', 'end'
    ),
    jsonb_build_object(
      'field', 'line.unit_price', 'label_key', 'col.unit_price',
      'label_ar', 'السعر', 'label_en', 'Price', 'width_pct', 20, 'align', 'end'
    ),
    jsonb_build_object(
      'field', 'line.total', 'label_key', 'col.total',
      'label_ar', 'الإجمالي', 'label_en', 'Total', 'width_pct', 25, 'align', 'end'
    )
  );
  v_statement_columns jsonb := jsonb_build_array(
    jsonb_build_object(
      'field', 'line.date', 'label_key', 'col.date',
      'label_ar', 'التاريخ', 'label_en', 'Date', 'width_pct', 15, 'align', 'start'
    ),
    jsonb_build_object(
      'field', 'line.description', 'label_key', 'col.description',
      'label_ar', 'الوصف', 'label_en', 'Description', 'width_pct', 35, 'align', 'start'
    ),
    jsonb_build_object(
      'field', 'line.debit', 'label_key', 'col.debit',
      'label_ar', 'مدين', 'label_en', 'Debit', 'width_pct', 15, 'align', 'end'
    ),
    jsonb_build_object(
      'field', 'line.credit', 'label_key', 'col.credit',
      'label_ar', 'دائن', 'label_en', 'Credit', 'width_pct', 15, 'align', 'end'
    ),
    jsonb_build_object(
      'field', 'line.balance', 'label_key', 'col.balance',
      'label_ar', 'الرصيد', 'label_en', 'Balance', 'width_pct', 20, 'align', 'end'
    )
  );
  v_blocks jsonb;
  v_paper_kind text;
begin
  v_blocks := case p_template_key
    when 'sales_invoice_a4' then jsonb_build_array(
      jsonb_build_object('type', 'tenant_header', 'id', 'hdr'),
      jsonb_build_object('type', 'document_meta', 'id', 'meta', 'fields', jsonb_build_array(
        'document.number', 'document.date', 'document.due_date'
      )),
      jsonb_build_object('type', 'party_details', 'id', 'party', 'party_role', 'customer', 'fields', jsonb_build_array(
        'party.name_ar', 'party.name_en', 'party.code'
      )),
      jsonb_build_object('type', 'line_table', 'id', 'lines', 'columns', v_invoice_columns, 'fields', jsonb_build_array(
        'line.description', 'line.qty', 'line.unit_price', 'line.total'
      )),
      jsonb_build_object('type', 'totals', 'id', 'totals', 'fields', jsonb_build_array(
        'totals.subtotal', 'totals.discount', 'totals.tax', 'totals.total'
      )),
      jsonb_build_object('type', 'footer', 'id', 'ftr', 'source', 'tenant_footer')
    )
    when 'purchase_invoice_a4' then jsonb_build_array(
      jsonb_build_object('type', 'tenant_header', 'id', 'hdr'),
      jsonb_build_object('type', 'document_meta', 'id', 'meta', 'fields', jsonb_build_array(
        'document.number', 'document.date', 'document.due_date'
      )),
      jsonb_build_object('type', 'party_details', 'id', 'party', 'party_role', 'supplier', 'fields', jsonb_build_array(
        'party.name_ar', 'party.name_en', 'party.code'
      )),
      jsonb_build_object('type', 'line_table', 'id', 'lines', 'columns', v_invoice_columns, 'fields', jsonb_build_array(
        'line.description', 'line.qty', 'line.unit_price', 'line.total'
      )),
      jsonb_build_object('type', 'totals', 'id', 'totals', 'fields', jsonb_build_array(
        'totals.subtotal', 'totals.discount', 'totals.tax', 'totals.total'
      )),
      jsonb_build_object('type', 'footer', 'id', 'ftr', 'source', 'tenant_footer')
    )
    when 'receipt_voucher_a4' then jsonb_build_array(
      jsonb_build_object('type', 'tenant_header', 'id', 'hdr'),
      jsonb_build_object('type', 'document_meta', 'id', 'meta', 'fields', jsonb_build_array(
        'document.number', 'document.date'
      )),
      jsonb_build_object('type', 'party_details', 'id', 'party', 'party_role', 'customer', 'fields', jsonb_build_array(
        'party.name_ar', 'party.name_en'
      )),
      jsonb_build_object('type', 'payment_details', 'id', 'pay', 'fields', jsonb_build_array(
        'payment.amount', 'payment.method', 'payment.reference', 'payment.collected_by'
      )),
      jsonb_build_object('type', 'footer', 'id', 'ftr', 'source', 'tenant_footer')
    )
    when 'receipt_voucher_80mm' then jsonb_build_array(
      jsonb_build_object('type', 'tenant_header', 'id', 'hdr'),
      jsonb_build_object('type', 'document_meta', 'id', 'meta', 'fields', jsonb_build_array(
        'document.number', 'document.date'
      )),
      jsonb_build_object('type', 'payment_details', 'id', 'pay', 'fields', jsonb_build_array(
        'payment.amount', 'payment.method', 'payment.reference'
      )),
      jsonb_build_object('type', 'footer', 'id', 'ftr', 'source', 'tenant_footer')
    )
    when 'customer_statement_a4' then jsonb_build_array(
      jsonb_build_object('type', 'tenant_header', 'id', 'hdr'),
      jsonb_build_object('type', 'document_meta', 'id', 'meta', 'fields', jsonb_build_array(
        'document.from_date', 'document.to_date', 'document.generated_at'
      )),
      jsonb_build_object('type', 'party_details', 'id', 'party', 'party_role', 'customer', 'fields', jsonb_build_array(
        'party.name_ar', 'party.name_en', 'party.code'
      )),
      jsonb_build_object('type', 'line_table', 'id', 'lines', 'columns', v_statement_columns, 'fields', jsonb_build_array(
        'line.date', 'line.description', 'line.debit', 'line.credit', 'line.balance'
      )),
      jsonb_build_object('type', 'totals', 'id', 'totals', 'fields', jsonb_build_array(
        'summary.opening_balance', 'summary.total_debit', 'summary.total_credit', 'summary.closing_balance'
      )),
      jsonb_build_object('type', 'footer', 'id', 'ftr', 'source', 'tenant_footer')
    )
    when 'asset_tag_label' then jsonb_build_array(
      jsonb_build_object('type', 'tenant_header', 'id', 'hdr'),
      jsonb_build_object('type', 'asset_identity', 'id', 'idn', 'fields', jsonb_build_array(
        'tenant.company_name_ar', 'product.name_ar', 'product.name_en', 'unit.serial'
      )),
      jsonb_build_object('type', 'qr_code', 'id', 'qr', 'payload_field', 'unit.serial', 'caption_field', 'unit.serial')
    )
    else null
  end;

  if v_blocks is null then
    raise exception 'unknown template key %', p_template_key;
  end if;

  v_paper_kind := case
    when p_template_key = 'receipt_voucher_80mm' then 'thermal_80mm'
    when p_template_key = 'asset_tag_label' then 'label_sheet'
    else 'a4'
  end;

  return jsonb_build_object(
    'schema_version', 1,
    'settings', case v_paper_kind
      when 'thermal_80mm' then public.m3_thermal_settings()
      when 'label_sheet' then public.m3_label_settings()
      else public.m3_a4_settings()
    end,
    'blocks', v_blocks
  );
end;
$$;

revoke all on function public.m3_default_template_body(text)
  from public, anon, authenticated;
revoke all on function public.validate_document_template_body(text, jsonb, text, int)
  from public, anon, authenticated;
revoke all on function public.trg_validate_document_template_body()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Bootstrap tenant document settings + templates
-- ---------------------------------------------------------------------------
create or replace function public.initialize_tenant_document_templates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tenant_document_settings (tenant_id)
  values (new.id)
  on conflict (tenant_id) do nothing;

  insert into public.document_templates (
    tenant_id, template_key, document_type, name_ar, name_en,
    language_mode, paper_kind, schema_version, body_json, is_default, is_active
  )
  values
    (new.id, 'sales_invoice_a4', 'sales_invoice', 'فاتورة مبيعات A4', 'Sales Invoice A4', 'bilingual', 'a4', 1, public.m3_default_template_body('sales_invoice_a4'), true, true),
    (new.id, 'purchase_invoice_a4', 'purchase_invoice', 'فاتورة مشتريات A4', 'Purchase Invoice A4', 'bilingual', 'a4', 1, public.m3_default_template_body('purchase_invoice_a4'), true, true),
    (new.id, 'receipt_voucher_a4', 'receipt_voucher', 'سند قبض A4', 'Receipt Voucher A4', 'bilingual', 'a4', 1, public.m3_default_template_body('receipt_voucher_a4'), true, true),
    (new.id, 'receipt_voucher_80mm', 'receipt_voucher', 'سند قبض 80mm', 'Receipt Voucher 80mm', 'bilingual', 'thermal_80mm', 1, public.m3_default_template_body('receipt_voucher_80mm'), true, true),
    (new.id, 'customer_statement_a4', 'customer_statement', 'كشف حساب A4', 'Customer Statement A4', 'bilingual', 'a4', 1, public.m3_default_template_body('customer_statement_a4'), true, true),
    (new.id, 'asset_tag_label', 'asset_tag_label', 'ملصق أصل', 'Asset Tag Label', 'bilingual', 'label_sheet', 1, public.m3_default_template_body('asset_tag_label'), true, true)
  on conflict (tenant_id, template_key) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_initialize_tenant_document_templates on public.tenants;
create trigger trg_initialize_tenant_document_templates
  after insert on public.tenants
  for each row execute function public.initialize_tenant_document_templates();

-- Backfill existing tenants
insert into public.tenant_document_settings (tenant_id)
select t.id from public.tenants t
on conflict (tenant_id) do nothing;

insert into public.document_templates (
  tenant_id, template_key, document_type, name_ar, name_en,
  language_mode, paper_kind, schema_version, body_json, is_default, is_active
)
select
  t.id,
  v.template_key,
  v.document_type,
  v.name_ar,
  v.name_en,
  'bilingual',
  v.paper_kind,
  1,
  public.m3_default_template_body(v.template_key),
  true,
  true
from public.tenants t
cross join (
  values
    ('sales_invoice_a4', 'sales_invoice', 'فاتورة مبيعات A4', 'Sales Invoice A4', 'a4'),
    ('purchase_invoice_a4', 'purchase_invoice', 'فاتورة مشتريات A4', 'Purchase Invoice A4', 'a4'),
    ('receipt_voucher_a4', 'receipt_voucher', 'سند قبض A4', 'Receipt Voucher A4', 'a4'),
    ('receipt_voucher_80mm', 'receipt_voucher', 'سند قبض 80mm', 'Receipt Voucher 80mm', 'thermal_80mm'),
    ('customer_statement_a4', 'customer_statement', 'كشف حساب A4', 'Customer Statement A4', 'a4'),
    ('asset_tag_label', 'asset_tag_label', 'ملصق أصل', 'Asset Tag Label', 'label_sheet')
) as v(template_key, document_type, name_ar, name_en, paper_kind)
on conflict (tenant_id, template_key) do nothing;

revoke all on function public.initialize_tenant_document_templates()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Audit fix for tenant_document_settings
-- ---------------------------------------------------------------------------
create or replace function public.audit_log_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_entity_id uuid;
  v_action text;
  v_before jsonb;
  v_after jsonb;
  v_row jsonb;
begin
  v_action := lower(tg_op);

  v_before := case
    when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old)
    else null
  end;

  v_after := case
    when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new)
    else null
  end;

  v_row := coalesce(v_after, v_before);
  v_tenant_id := (v_row ->> 'tenant_id')::uuid;

  v_entity_id := case
    when tg_table_name in ('tenant_settings', 'tenant_document_settings')
      then v_tenant_id
    else (v_row ->> 'id')::uuid
  end;

  insert into public.audit_log (
    tenant_id,
    actor_id,
    actor_account_type,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  values (
    v_tenant_id,
    auth.uid(),
    public.current_account_type()::text,
    v_action,
    tg_table_name,
    v_entity_id,
    v_before,
    v_after
  );

  return coalesce(new, old);
end;
$$;

revoke all on function public.audit_log_row()
  from public, anon, authenticated;

drop trigger if exists trg_audit_tenant_document_settings_insert on public.tenant_document_settings;
create trigger trg_audit_tenant_document_settings_insert
  after insert on public.tenant_document_settings
  for each row execute function public.audit_log_row();

drop trigger if exists trg_audit_tenant_document_settings_update on public.tenant_document_settings;
create trigger trg_audit_tenant_document_settings_update
  after update on public.tenant_document_settings
  for each row execute function public.audit_log_row();

drop trigger if exists trg_touch_tenant_document_settings on public.tenant_document_settings;
create trigger trg_touch_tenant_document_settings
  before update on public.tenant_document_settings
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Permission helpers
-- ---------------------------------------------------------------------------
create or replace function public.assert_document_preview_permission(p_document_type text)
returns void
language plpgsql
stable
set search_path = public
as $$
begin
  if public.is_manager() then
    return;
  end if;

  case p_document_type
    when 'sales_invoice' then
      if not (
        public.user_has_permission('invoices.view_sales')
        or public.user_has_permission('invoices.view')
      ) then
        raise exception 'permission_denied';
      end if;
    when 'purchase_invoice' then
      if not (
        public.user_has_permission('invoices.view_purchase')
        or public.user_has_permission('invoices.view')
      ) then
        raise exception 'permission_denied';
      end if;
    when 'receipt_voucher' then
      if not public.user_has_permission('vouchers.view') then
        raise exception 'permission_denied';
      end if;
    when 'customer_statement' then
      if not public.user_has_permission('customers.view_ledger') then
        raise exception 'permission_denied';
      end if;
    when 'asset_tag_label' then
      if not public.user_has_permission('product_units.view') then
        raise exception 'permission_denied';
      end if;
    else
      raise exception 'unsupported_document_type';
  end case;
end;
$$;

create or replace function public.assert_template_settings_read()
returns void
language plpgsql
stable
set search_path = public
as $$
begin
  if public.is_manager() then
    return;
  end if;
  if not (
    public.user_has_permission('settings.templates.view')
    or public.user_has_permission('settings.templates.edit')
  ) then
    raise exception 'permission_denied';
  end if;
end;
$$;

create or replace function public.assert_template_settings_edit()
returns void
language plpgsql
stable
set search_path = public
as $$
begin
  if public.is_manager() then
    return;
  end if;
  if not public.user_has_permission('settings.templates.edit') then
    raise exception 'permission_denied';
  end if;
end;
$$;

create or replace function public.validate_logo_url(p_url text)
returns void
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_url is null or btrim(p_url) = '' then
    return;
  end if;
  if left(lower(btrim(p_url)), 8) <> 'https://' then
    raise exception 'validation_failed';
  end if;
  if length(p_url) > 2048 then
    raise exception 'validation_failed';
  end if;
end;
$$;

create or replace function public.validate_tenant_document_settings_json(
  p_header jsonb,
  p_footer jsonb,
  p_optional_columns jsonb
)
returns void
language plpgsql
immutable
set search_path = public
as $$
declare
  v_key text;
  v_doc_type text;
  v_field text;
  v_value jsonb;
  v_allowed_doc_types text[] := array['sales_invoice', 'purchase_invoice', 'customer_statement'];
  v_allowed_fields text[];
  v_mandatory_fields text[];
begin
  if jsonb_typeof(p_header) <> 'object' then
    raise exception 'validation_failed';
  end if;
  if jsonb_typeof(p_footer) <> 'object' then
    raise exception 'validation_failed';
  end if;
  if jsonb_typeof(p_optional_columns) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_header) loop
    if v_key not in ('text_ar', 'text_en') then
      raise exception 'validation_failed';
    end if;
    if jsonb_typeof(p_header -> v_key) <> 'string' then
      raise exception 'validation_failed';
    end if;
    if length(p_header ->> v_key) > 1000 then
      raise exception 'validation_failed';
    end if;
    if (p_header ->> v_key) ~ '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]' then
      raise exception 'validation_failed';
    end if;
  end loop;

  for v_key in select jsonb_object_keys(p_footer) loop
    if v_key not in ('text_ar', 'text_en') then
      raise exception 'validation_failed';
    end if;
    if jsonb_typeof(p_footer -> v_key) <> 'string' then
      raise exception 'validation_failed';
    end if;
    if length(p_footer ->> v_key) > 1000 then
      raise exception 'validation_failed';
    end if;
    if (p_footer ->> v_key) ~ '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]' then
      raise exception 'validation_failed';
    end if;
  end loop;

  for v_doc_type in select jsonb_object_keys(p_optional_columns) loop
    if not v_doc_type = any (v_allowed_doc_types) then
      raise exception 'validation_failed';
    end if;
    if jsonb_typeof(p_optional_columns -> v_doc_type) <> 'object' then
      raise exception 'validation_failed';
    end if;

    v_allowed_fields := case v_doc_type
      when 'sales_invoice' then array['line.qty', 'line.unit_price']
      when 'purchase_invoice' then array['line.qty', 'line.unit_price']
      when 'customer_statement' then array['line.debit', 'line.credit']
      else array[]::text[]
    end;

    v_mandatory_fields := case v_doc_type
      when 'sales_invoice' then array['line.description', 'line.total']
      when 'purchase_invoice' then array['line.description', 'line.total']
      when 'customer_statement' then array['line.date', 'line.description', 'line.balance']
      else array[]::text[]
    end;

    if (select count(*) from jsonb_object_keys(p_optional_columns -> v_doc_type)) > 4 then
      raise exception 'validation_failed';
    end if;

    for v_field in select jsonb_object_keys(p_optional_columns -> v_doc_type) loop
      if not v_field = any (v_allowed_fields) then
        raise exception 'validation_failed';
      end if;
      v_value := p_optional_columns -> v_doc_type -> v_field;
      if jsonb_typeof(v_value) <> 'boolean' then
        raise exception 'validation_failed';
      end if;
      if v_field = any (v_mandatory_fields) and (v_value)::boolean = false then
        raise exception 'validation_failed';
      end if;
    end loop;
  end loop;
end;
$$;

create or replace function public.validate_tenant_document_settings_patch(p_patch jsonb)
returns void
language plpgsql
immutable
set search_path = public
as $$
declare
  v_key text;
  v_allowed text[] := array[
    'logo_url', 'primary_color', 'secondary_color', 'default_language',
    'invoice_paper_kind', 'voucher_paper_kind', 'asset_label_paper_kind',
    'header_json', 'footer_json', 'optional_columns_json'
  ];
begin
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise exception 'validation_failed';
  end if;

  for v_key in select jsonb_object_keys(p_patch) loop
    if not v_key = any (v_allowed) then
      raise exception 'validation_failed';
    end if;
  end loop;

  if p_patch ? 'logo_url' then
    if jsonb_typeof(p_patch -> 'logo_url') not in ('string', 'null') then
      raise exception 'validation_failed';
    end if;
    perform public.validate_logo_url(p_patch ->> 'logo_url');
  end if;

  if p_patch ? 'primary_color' then
    if jsonb_typeof(p_patch -> 'primary_color') not in ('string', 'null')
      or (
        p_patch ->> 'primary_color' is not null
        and (p_patch ->> 'primary_color') !~ '^#[0-9A-Fa-f]{6}$'
      ) then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_patch ? 'secondary_color' then
    if jsonb_typeof(p_patch -> 'secondary_color') not in ('string', 'null')
      or (
        p_patch ->> 'secondary_color' is not null
        and (p_patch ->> 'secondary_color') !~ '^#[0-9A-Fa-f]{6}$'
      ) then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_patch ? 'default_language' then
    if jsonb_typeof(p_patch -> 'default_language') <> 'string'
      or (p_patch ->> 'default_language') not in ('ar', 'en', 'bilingual') then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_patch ? 'invoice_paper_kind' then
    if jsonb_typeof(p_patch -> 'invoice_paper_kind') <> 'string'
      or (p_patch ->> 'invoice_paper_kind') <> 'a4' then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_patch ? 'voucher_paper_kind' then
    if jsonb_typeof(p_patch -> 'voucher_paper_kind') <> 'string'
      or (p_patch ->> 'voucher_paper_kind') not in ('a4', 'thermal_80mm') then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_patch ? 'asset_label_paper_kind' then
    if jsonb_typeof(p_patch -> 'asset_label_paper_kind') <> 'string'
      or (p_patch ->> 'asset_label_paper_kind') <> 'label_sheet' then
      raise exception 'validation_failed';
    end if;
  end if;

  if p_patch ? 'header_json'
    and octet_length((p_patch -> 'header_json')::text) > 4096 then
    raise exception 'validation_failed';
  end if;

  if p_patch ? 'footer_json'
    and octet_length((p_patch -> 'footer_json')::text) > 4096 then
    raise exception 'validation_failed';
  end if;

  if p_patch ? 'optional_columns_json'
    and octet_length((p_patch -> 'optional_columns_json')::text) > 4096 then
    raise exception 'validation_failed';
  end if;

  if p_patch ? 'header_json' or p_patch ? 'footer_json' or p_patch ? 'optional_columns_json' then
    perform public.validate_tenant_document_settings_json(
      coalesce(p_patch -> 'header_json', '{}'::jsonb),
      coalesce(p_patch -> 'footer_json', '{}'::jsonb),
      coalesce(p_patch -> 'optional_columns_json', '{}'::jsonb)
    );
  end if;
end;
$$;

revoke all on function public.validate_tenant_document_settings_json(jsonb, jsonb, jsonb)
  from public, anon, authenticated;
revoke all on function public.assert_document_preview_permission(text)
  from public, anon, authenticated;
revoke all on function public.assert_template_settings_read()
  from public, anon, authenticated;
revoke all on function public.assert_template_settings_edit()
  from public, anon, authenticated;
revoke all on function public.validate_logo_url(text)
  from public, anon, authenticated;
revoke all on function public.validate_tenant_document_settings_patch(jsonb)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPC: get_effective_document_template
-- ---------------------------------------------------------------------------
create or replace function public.get_effective_document_template(
  p_document_type text,
  p_paper_kind text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_paper text;
  v_template public.document_templates%rowtype;
  v_settings public.tenant_document_settings%rowtype;
  v_company_ar text;
  v_company_en text;
  v_logo text;
  v_currency jsonb;
  v_default_currency_id uuid;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if p_document_type = 'payment_voucher' then
    raise exception 'unsupported_document_type';
  end if;

  perform public.assert_document_preview_permission(p_document_type);

  select * into v_settings
  from public.tenant_document_settings
  where tenant_id = v_tenant_id;

  v_paper := coalesce(
    p_paper_kind,
    case
      when p_document_type in ('sales_invoice', 'purchase_invoice')
        then coalesce(v_settings.invoice_paper_kind, 'a4')
      when p_document_type = 'receipt_voucher'
        then coalesce(v_settings.voucher_paper_kind, 'a4')
      when p_document_type = 'asset_tag_label'
        then coalesce(v_settings.asset_label_paper_kind, 'label_sheet')
      else 'a4'
    end
  );

  select * into v_template
  from public.document_templates dt
  where dt.tenant_id = v_tenant_id
    and dt.document_type = p_document_type
    and dt.paper_kind = v_paper
    and dt.is_default = true
    and dt.is_active = true
  limit 1;

  if v_template.id is null then
    raise exception 'no_default_document_template';
  end if;

  perform public.validate_document_template_body(
    v_template.document_type,
    v_template.body_json,
    v_template.paper_kind,
    v_template.schema_version
  );

  select
    coalesce(ts.company_name_ar, t.name, ''),
    coalesce(ts.company_name_en, t.name, '')
  into v_company_ar, v_company_en
  from public.tenants t
  left join public.tenant_settings ts on ts.tenant_id = t.id
  where t.id = v_tenant_id;

  v_logo := nullif(btrim(coalesce(v_settings.logo_url, '')), '');
  if v_logo is null then
    select nullif(btrim(coalesce(ts.logo_url, '')), '') into v_logo
    from public.tenant_settings ts
    where ts.tenant_id = v_tenant_id;
  end if;
  if v_logo is null then
    select nullif(btrim(coalesce(t.logo_url, '')), '') into v_logo
    from public.tenants t
    where t.id = v_tenant_id;
  end if;

  select t.default_currency_id
  into v_default_currency_id
  from public.tenants t
  where t.id = v_tenant_id;

  if v_default_currency_id is null then
    v_currency := null;
  else
    select jsonb_build_object(
      'code', c.iso_code,
      'symbol', c.major_symbol_en,
      'symbol_position', c.symbol_position,
      'decimal_places', c.decimal_places
    )
    into v_currency
    from public.currencies c
    where c.id = v_default_currency_id;
  end if;

  return jsonb_build_object(
    'template', jsonb_build_object(
      'id', v_template.id,
      'template_key', v_template.template_key,
      'document_type', v_template.document_type,
      'language_mode', v_template.language_mode,
      'paper_kind', v_template.paper_kind,
      'schema_version', v_template.schema_version,
      'body_json', v_template.body_json,
      'name_ar', v_template.name_ar,
      'name_en', v_template.name_en
    ),
    'settings', coalesce(to_jsonb(v_settings), '{}'::jsonb),
    'currency', v_currency,
    'resolved_logo_url', v_logo,
    'company_names', jsonb_build_object(
      'ar', v_company_ar,
      'en', v_company_en
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: get_tenant_document_settings
-- ---------------------------------------------------------------------------
create or replace function public.get_tenant_document_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_row public.tenant_document_settings%rowtype;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_template_settings_read();

  select * into v_row
  from public.tenant_document_settings
  where tenant_id = v_tenant_id;

  return coalesce(to_jsonb(v_row), '{}'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: upsert_tenant_document_settings
-- ---------------------------------------------------------------------------
create or replace function public.upsert_tenant_document_settings(p_patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_row public.tenant_document_settings%rowtype;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  perform public.assert_template_settings_edit();
  perform public.validate_tenant_document_settings_patch(p_patch);

  insert into public.tenant_document_settings (tenant_id)
  values (v_tenant_id)
  on conflict (tenant_id) do nothing;

  update public.tenant_document_settings tds
  set
    logo_url = case when p_patch ? 'logo_url' then nullif(btrim(p_patch ->> 'logo_url'), '') else tds.logo_url end,
    primary_color = case when p_patch ? 'primary_color' then p_patch ->> 'primary_color' else tds.primary_color end,
    secondary_color = case when p_patch ? 'secondary_color' then p_patch ->> 'secondary_color' else tds.secondary_color end,
    default_language = case when p_patch ? 'default_language' then p_patch ->> 'default_language' else tds.default_language end,
    invoice_paper_kind = case when p_patch ? 'invoice_paper_kind' then p_patch ->> 'invoice_paper_kind' else tds.invoice_paper_kind end,
    voucher_paper_kind = case when p_patch ? 'voucher_paper_kind' then p_patch ->> 'voucher_paper_kind' else tds.voucher_paper_kind end,
    asset_label_paper_kind = case when p_patch ? 'asset_label_paper_kind' then p_patch ->> 'asset_label_paper_kind' else tds.asset_label_paper_kind end,
    header_json = case when p_patch ? 'header_json' then coalesce(p_patch -> 'header_json', '{}'::jsonb) else tds.header_json end,
    footer_json = case when p_patch ? 'footer_json' then coalesce(p_patch -> 'footer_json', '{}'::jsonb) else tds.footer_json end,
    optional_columns_json = case when p_patch ? 'optional_columns_json' then coalesce(p_patch -> 'optional_columns_json', '{}'::jsonb) else tds.optional_columns_json end,
    updated_by = auth.uid()
  where tds.tenant_id = v_tenant_id
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: get_customer_statement_document_payload
-- ---------------------------------------------------------------------------
create or replace function public.get_customer_statement_document_payload(
  p_customer_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_account_id uuid;
  v_opening numeric(15, 3);
  v_period_debit numeric(15, 3);
  v_period_credit numeric(15, 3);
  v_closing numeric(15, 3);
  v_row_count bigint;
  v_customer jsonb;
  v_lines jsonb;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('customers.view_ledger') then
    raise exception 'permission_denied';
  end if;

  if p_from is null or p_to is null then
    raise exception 'statement_date_range_invalid';
  end if;

  if p_to < p_from or (p_to - p_from) > 364 then
    raise exception 'statement_date_range_invalid';
  end if;

  select jsonb_build_object(
    'id', c.id,
    'code', c.code,
    'name_ar', c.name_ar,
    'name_en', c.name_en
  ), c.account_id
  into v_customer, v_account_id
  from public.customers c
  where c.id = p_customer_id
    and c.tenant_id = v_tenant_id;

  if v_customer is null then
    raise exception 'validation_failed';
  end if;

  if v_account_id is null then
    return jsonb_build_object(
      'customer', v_customer,
      'from_date', p_from,
      'to_date', p_to,
      'generated_at', now(),
      'notes', null,
      'summary', jsonb_build_object(
        'opening_balance', '0',
        'total_debit', '0',
        'total_credit', '0',
        'closing_balance', '0'
      ),
      'lines', '[]'::jsonb,
      'row_count', 0
    );
  end if;

  select count(*)
  into v_row_count
  from public.journal_lines jl
  join public.journal_entries je on je.id = jl.journal_entry_id
  where jl.tenant_id = v_tenant_id
    and jl.account_id = v_account_id
    and je.is_posted = true
    and je.date >= p_from
    and je.date <= p_to;

  if v_row_count > public.m3_statement_row_limit() then
    raise exception 'statement_range_too_large';
  end if;

  select coalesce(sum(jl.debit - jl.credit), 0)::numeric(15, 3)
  into v_opening
  from public.journal_lines jl
  join public.journal_entries je on je.id = jl.journal_entry_id
  where jl.tenant_id = v_tenant_id
    and jl.account_id = v_account_id
    and je.is_posted = true
    and je.date < p_from;

  select
    coalesce(sum(jl.debit), 0)::numeric(15, 3),
    coalesce(sum(jl.credit), 0)::numeric(15, 3)
  into v_period_debit, v_period_credit
  from public.journal_lines jl
  join public.journal_entries je on je.id = jl.journal_entry_id
  where jl.tenant_id = v_tenant_id
    and jl.account_id = v_account_id
    and je.is_posted = true
    and je.date >= p_from
    and je.date <= p_to;

  v_closing := v_opening + v_period_debit - v_period_credit;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'entry_date', r.entry_date,
      'entry_number', r.entry_number,
      'source', r.source,
      'description', r.description,
      'debit', r.debit::text,
      'credit', r.credit::text,
      'running_balance', r.running_balance::text
    )
    order by r.entry_date, r.entry_number, r.journal_entry_id, r.journal_line_id
  ), '[]'::jsonb)
  into v_lines
  from (
    select
      je.date as entry_date,
      je.entry_number,
      je.id as journal_entry_id,
      jl.id as journal_line_id,
      je.source,
      jl.description,
      jl.debit::numeric(15, 3) as debit,
      jl.credit::numeric(15, 3) as credit,
      (v_opening + sum(jl.debit - jl.credit) over (
        order by je.date, je.entry_number, je.id, jl.id
        rows between unbounded preceding and current row
      ))::numeric(15, 3) as running_balance
    from public.journal_lines jl
    join public.journal_entries je on je.id = jl.journal_entry_id
    where jl.tenant_id = v_tenant_id
      and jl.account_id = v_account_id
      and je.is_posted = true
      and je.date >= p_from
      and je.date <= p_to
  ) r;

  return jsonb_build_object(
    'customer', v_customer,
    'from_date', p_from,
    'to_date', p_to,
    'generated_at', now(),
    'notes', null,
    'summary', jsonb_build_object(
      'opening_balance', v_opening::text,
      'total_debit', v_period_debit::text,
      'total_credit', v_period_credit::text,
      'closing_balance', v_closing::text
    ),
    'lines', v_lines,
    'row_count', v_row_count
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: get_product_unit_label_payload
-- ---------------------------------------------------------------------------
create or replace function public.get_product_unit_label_payload(p_unit_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_company_ar text;
  v_company_en text;
  v_row record;
begin
  v_tenant_id := public.current_tenant_id();
  if v_tenant_id is null then
    raise exception 'tenant_not_found';
  end if;

  if not public.user_has_permission('product_units.view') then
    raise exception 'permission_denied';
  end if;

  select
    pu.serial_number,
    pu.barcode,
    pu.status::text,
    p.name_ar as product_name_ar,
    p.name_en as product_name_en,
    p.sku as product_sku
  into v_row
  from public.product_units pu
  join public.products p
    on p.id = pu.product_id
   and p.tenant_id = pu.tenant_id
  where pu.id = p_unit_id
    and pu.tenant_id = v_tenant_id;

  if v_row.serial_number is null then
    raise exception 'validation_failed';
  end if;

  select
    coalesce(ts.company_name_ar, t.name, ''),
    coalesce(ts.company_name_en, t.name, '')
  into v_company_ar, v_company_en
  from public.tenants t
  left join public.tenant_settings ts on ts.tenant_id = t.id
  where t.id = v_tenant_id;

  return jsonb_build_object(
    'unit', jsonb_build_object(
      'serial', v_row.serial_number,
      'barcode', v_row.barcode,
      'status', v_row.status
    ),
    'product', jsonb_build_object(
      'name_ar', v_row.product_name_ar,
      'name_en', v_row.product_name_en,
      'sku', v_row.product_sku
    ),
    'tenant', jsonb_build_object(
      'company_name_ar', v_company_ar,
      'company_name_en', v_company_en
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS + REVOKE direct writes
-- ---------------------------------------------------------------------------
alter table public.document_templates enable row level security;
alter table public.tenant_document_settings enable row level security;

revoke all on public.document_templates from public, anon, authenticated;
revoke all on public.tenant_document_settings from public, anon, authenticated;

grant select on public.document_templates to authenticated;
grant select on public.tenant_document_settings to authenticated;

drop policy if exists document_templates_select on public.document_templates;
create policy document_templates_select on public.document_templates
  for select using (
    tenant_id = public.current_tenant_id()
    and (
      public.user_has_permission('settings.templates.view')
      or public.user_has_permission('settings.templates.edit')
    )
  );

drop policy if exists tenant_document_settings_select on public.tenant_document_settings;
create policy tenant_document_settings_select on public.tenant_document_settings
  for select using (
    tenant_id = public.current_tenant_id()
    and (
      public.user_has_permission('settings.templates.view')
      or public.user_has_permission('settings.templates.edit')
    )
  );

-- ---------------------------------------------------------------------------
-- ACL
-- ---------------------------------------------------------------------------
revoke all on function public.get_effective_document_template(text, text)
  from public, anon;
revoke all on function public.get_tenant_document_settings()
  from public, anon;
revoke all on function public.upsert_tenant_document_settings(jsonb)
  from public, anon;
revoke all on function public.get_customer_statement_document_payload(uuid, date, date)
  from public, anon;
revoke all on function public.get_product_unit_label_payload(uuid)
  from public, anon;

grant execute on function public.get_effective_document_template(text, text) to authenticated;
grant execute on function public.get_tenant_document_settings() to authenticated;
grant execute on function public.upsert_tenant_document_settings(jsonb) to authenticated;
grant execute on function public.get_customer_statement_document_payload(uuid, date, date) to authenticated;
grant execute on function public.get_product_unit_label_payload(uuid) to authenticated;
