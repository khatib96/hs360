-- Phase 5 M3: document template validator negative tests (VAL-*).
-- Run via scripts/test/run_sql_suites.ps1 Phase B.

\set ON_ERROR_STOP on

create or replace function pg_temp.m3_expect_invalid_template(
  p_label text,
  p_document_type text,
  p_body jsonb,
  p_paper_kind text,
  p_schema_version int default 1
)
returns void
language plpgsql
as $$
begin
  begin
    perform public.validate_document_template_body(
      p_document_type, p_body, p_paper_kind, p_schema_version
    );
    raise exception '% failed: validator accepted invalid body', p_label;
  exception
    when others then
      if sqlerrm not like '%invalid_document_template%'
        and sqlerrm not like '%unsupported_document_type%' then
        raise exception '% failed: unexpected error: %', p_label, sqlerrm;
      end if;
  end;
end;
$$;

create or replace function pg_temp.m3_sales_invoice_body()
returns jsonb
language sql
immutable
as $$
  select public.m3_default_template_body('sales_invoice_a4');
$$;

-- VAL-ROOT: unknown root key
select pg_temp.m3_expect_invalid_template(
  'VAL-ROOT',
  'sales_invoice',
  pg_temp.m3_sales_invoice_body() || '{"extra_root": true}'::jsonb,
  'a4'
);

-- VAL-SCHEMA-VER: schema_version must be 1
select pg_temp.m3_expect_invalid_template(
  'VAL-SCHEMA-VER',
  'sales_invoice',
  jsonb_set(pg_temp.m3_sales_invoice_body(), '{schema_version}', '2'::jsonb),
  'a4'
);

-- VAL-SCHEMA-MISMATCH: p_schema_version != body schema_version
select pg_temp.m3_expect_invalid_template(
  'VAL-SCHEMA-MISMATCH',
  'sales_invoice',
  pg_temp.m3_sales_invoice_body(),
  'a4',
  2
);

-- VAL-SETTINGS-OBJ: settings must be object
select pg_temp.m3_expect_invalid_template(
  'VAL-SETTINGS-OBJ',
  'sales_invoice',
  jsonb_set(pg_temp.m3_sales_invoice_body(), '{settings}', '[]'::jsonb),
  'a4'
);

-- VAL-BLOCKS-LEN: blocks length out of range (empty)
select pg_temp.m3_expect_invalid_template(
  'VAL-BLOCKS-LEN',
  'sales_invoice',
  jsonb_set(pg_temp.m3_sales_invoice_body(), '{blocks}', '[]'::jsonb),
  'a4'
);

-- VAL-SETTINGS-KEY: unknown settings key on A4
select pg_temp.m3_expect_invalid_template(
  'VAL-SETTINGS-KEY',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{settings,thermal_content_width_mm}',
    '72'::jsonb
  ),
  'a4'
);

-- VAL-MARGIN: margin out of range
select pg_temp.m3_expect_invalid_template(
  'VAL-MARGIN',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{settings,page_margin_mm,left}',
    '99'::jsonb
  ),
  'a4'
);

-- VAL-FONT: base_font_size_pt out of range
select pg_temp.m3_expect_invalid_template(
  'VAL-FONT',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{settings,base_font_size_pt}',
    '3'::jsonb
  ),
  'a4'
);

-- VAL-FONT-TYPE: numeric settings cannot be JSON strings
select pg_temp.m3_expect_invalid_template(
  'VAL-FONT-TYPE',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{settings,base_font_size_pt}',
    '"10"'::jsonb
  ),
  'a4'
);

-- VAL-LINE-HEIGHT: line_height out of range
select pg_temp.m3_expect_invalid_template(
  'VAL-LINE-HEIGHT',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{settings,line_height}',
    '3.0'::jsonb
  ),
  'a4'
);

-- VAL-DIGIT: digit_style must be western
select pg_temp.m3_expect_invalid_template(
  'VAL-DIGIT',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{settings,digit_style}',
    '"arabic"'::jsonb
  ),
  'a4'
);

-- VAL-THERMAL-GEO: thermal geometry exceeds 80mm
select pg_temp.m3_expect_invalid_template(
  'VAL-THERMAL-GEO',
  'receipt_voucher',
  jsonb_set(
    public.m3_default_template_body('receipt_voucher_80mm'),
    '{settings,thermal_content_width_mm}',
    '73'::jsonb
  ),
  'thermal_80mm'
);

-- VAL-BLOCK-TYPE: block type not allowed for document/paper
select pg_temp.m3_expect_invalid_template(
  'VAL-BLOCK-TYPE',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks,0,type}',
    '"html_embed"'::jsonb
  ),
  'a4'
);

-- VAL-BLOCK-ID: invalid block id regex
select pg_temp.m3_expect_invalid_template(
  'VAL-BLOCK-ID',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks,0,id}',
    '"bad id!"'::jsonb
  ),
  'a4'
);

-- VAL-DUP-ID: duplicate block id
select pg_temp.m3_expect_invalid_template(
  'VAL-DUP-ID',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks,1,id}',
    '"hdr"'::jsonb
  ),
  'a4'
);

-- VAL-DUP-SINGLETON: duplicate tenant_header
select pg_temp.m3_expect_invalid_template(
  'VAL-DUP-SINGLETON',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks}',
    (pg_temp.m3_sales_invoice_body() -> 'blocks') || jsonb_build_array(
      jsonb_build_object('type', 'tenant_header', 'id', 'hdr2')
    )
  ),
  'a4'
);

-- VAL-REQUIRED-BLOCK: missing required footer
select pg_temp.m3_expect_invalid_template(
  'VAL-REQUIRED-BLOCK',
  'sales_invoice',
  (
    select jsonb_set(
      pg_temp.m3_sales_invoice_body(),
      '{blocks}',
      jsonb_agg(elem)
    )
    from jsonb_array_elements(pg_temp.m3_sales_invoice_body() -> 'blocks') elem
    where elem ->> 'type' <> 'footer'
  ),
  'a4'
);

-- VAL-COLUMN-WIDTH: column widths must sum to 100
select pg_temp.m3_expect_invalid_template(
  'VAL-COLUMN-WIDTH',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks}',
    (
      select jsonb_agg(
        case
          when elem ->> 'type' = 'line_table' then
            jsonb_set(
              elem,
              '{columns}',
              jsonb_build_array(
                jsonb_build_object(
                  'field', 'line.description', 'label_key', 'col.description',
                  'label_ar', 'x', 'label_en', 'x', 'width_pct', 40, 'align', 'start'
                ),
                jsonb_build_object(
                  'field', 'line.qty', 'label_key', 'col.qty',
                  'label_ar', 'x', 'label_en', 'x', 'width_pct', 40, 'align', 'end'
                )
              )
            )
          else elem
        end
      )
      from jsonb_array_elements(pg_temp.m3_sales_invoice_body() -> 'blocks') elem
    )
  ),
  'a4'
);

-- VAL-COLUMN-LABEL: all labels are required strings
select pg_temp.m3_expect_invalid_template(
  'VAL-COLUMN-LABEL',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks}',
    (
      select jsonb_agg(
        case
          when elem ->> 'type' = 'line_table' then
            jsonb_set(elem, '{columns,0,label_ar}', 'null'::jsonb)
          else elem
        end
      )
      from jsonb_array_elements(pg_temp.m3_sales_invoice_body() -> 'blocks') elem
    )
  ),
  'a4'
);

-- VAL-FIELD-ALLOW: field not in allowlist
select pg_temp.m3_expect_invalid_template(
  'VAL-FIELD-ALLOW',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks}',
    (
      select jsonb_agg(
        case
          when elem ->> 'type' = 'document_meta' then
            jsonb_set(
              elem,
              '{fields}',
              jsonb_build_array('document.number', 'document.notes')
            )
          else elem
        end
      )
      from jsonb_array_elements(pg_temp.m3_sales_invoice_body() -> 'blocks') elem
    )
  ),
  'a4'
);

-- VAL-SPACER: spacer height_mm out of range
select pg_temp.m3_expect_invalid_template(
  'VAL-SPACER',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks}',
    (pg_temp.m3_sales_invoice_body() -> 'blocks') || jsonb_build_array(
      jsonb_build_object('type', 'spacer', 'id', 'sp1', 'height_mm', 999)
    )
  ),
  'a4'
);

-- VAL-FOOTER: footer source must be tenant_footer
select pg_temp.m3_expect_invalid_template(
  'VAL-FOOTER',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks}',
    (
      select jsonb_agg(
        case
          when elem ->> 'type' = 'footer' then
            jsonb_set(elem, '{source}', '"template_footer"'::jsonb)
          else elem
        end
      )
      from jsonb_array_elements(pg_temp.m3_sales_invoice_body() -> 'blocks') elem
    )
  ),
  'a4'
);

-- VAL-QR: invalid qr_code payload_field
select pg_temp.m3_expect_invalid_template(
  'VAL-QR',
  'asset_tag_label',
  jsonb_set(
    public.m3_default_template_body('asset_tag_label'),
    '{blocks}',
    (
      select jsonb_agg(
        case
          when elem ->> 'type' = 'qr_code' then
            jsonb_set(elem, '{payload_field}', '"unit.barcode"'::jsonb)
          else elem
        end
      )
      from jsonb_array_elements(public.m3_default_template_body('asset_tag_label') -> 'blocks') elem
    )
  ),
  'label_sheet'
);

-- VAL-COLUMN-KEY: unknown column key
select pg_temp.m3_expect_invalid_template(
  'VAL-COLUMN-KEY',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks}',
    (
      select jsonb_agg(
        case
          when elem ->> 'type' = 'line_table' then
            jsonb_set(
              elem,
              '{columns,0}',
              (elem -> 'columns' -> 0) || '{"extra": true}'::jsonb
            )
          else elem
        end
      )
      from jsonb_array_elements(pg_temp.m3_sales_invoice_body() -> 'blocks') elem
    )
  ),
  'a4'
);

-- VAL-ALIGN: invalid column align
select pg_temp.m3_expect_invalid_template(
  'VAL-ALIGN',
  'sales_invoice',
  jsonb_set(
    pg_temp.m3_sales_invoice_body(),
    '{blocks}',
    (
      select jsonb_agg(
        case
          when elem ->> 'type' = 'line_table' then
            jsonb_set(elem, '{columns,0,align}', '"middle"'::jsonb)
          else elem
        end
      )
      from jsonb_array_elements(pg_temp.m3_sales_invoice_body() -> 'blocks') elem
    )
  ),
  'a4'
);

select 'phase_5_document_templates_validation.sql: all cases passed' as result;
