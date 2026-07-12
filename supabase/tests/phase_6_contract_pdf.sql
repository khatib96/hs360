-- Phase 6 M11: contract PDF template and detail enrichment tests.
-- Run via scripts/test/run_sql_suites.sh Phase M11.

\set ON_ERROR_STOP on

create or replace function pg_temp.m11_expect_invalid_contract_template(p_body jsonb)
returns void
language plpgsql
as $$
begin
  begin
    perform public.validate_document_template_body(
      'contract', p_body, 'a4', 1
    );
    raise exception 'contract template validator accepted forbidden body';
  exception
    when others then
      if sqlerrm not like '%invalid_document_template%' then
        raise exception 'unexpected validator error: %', sqlerrm;
      end if;
  end;
end;
$$;

-- 1) snapshot_unit_primary column exists and is populated
do $body$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'contract_lines'
      and column_name = 'snapshot_unit_primary'
  ) then
    raise exception 'contract_lines.snapshot_unit_primary column missing';
  end if;

  if exists (
    select 1 from public.contract_lines where snapshot_unit_primary is null
  ) then
    raise exception 'contract_lines.snapshot_unit_primary has null values';
  end if;
end;
$body$;

-- 2) contract_a4 default template validates
select public.validate_document_template_body(
  'contract',
  public.m3_default_template_body('contract_a4'),
  'a4',
  1
);

do $body$
begin
  if not (
    (public.m3_default_template_body('contract_a4') -> 'blocks') @> jsonb_build_array(
      jsonb_build_object('type', 'line_table')
    )
  ) then
    raise exception 'contract_a4 template missing line_table block';
  end if;
end;
$body$;

-- Custom template must not be overwritten by backfill
begin;
do $body$
declare
  v_tenant_id uuid;
  v_custom jsonb := public.m3_default_template_body('contract_a4');
  v_after jsonb;
begin
  select id into v_tenant_id from public.tenants limit 1;
  v_custom := jsonb_set(
    v_custom,
    '{blocks}',
    (
      select jsonb_agg(
        case
          when b ->> 'type' = 'document_meta' then
            jsonb_set(b, '{id}', '"meta-m11-test"'::jsonb)
          else b
        end
      )
      from jsonb_array_elements(v_custom -> 'blocks') b
    )
  );

  insert into public.document_templates (
    tenant_id, template_key, document_type, name_ar, name_en,
    language_mode, paper_kind, schema_version, body_json, is_default, is_active
  )
  values (
    v_tenant_id, 'contract_a4', 'contract', 'Custom', 'Custom', 'bilingual', 'a4',
    1, v_custom, true, true
  )
  on conflict (tenant_id, template_key)
  do update set body_json = excluded.body_json;

  insert into public.document_templates (
    tenant_id, template_key, document_type, name_ar, name_en,
    language_mode, paper_kind, schema_version, body_json, is_default, is_active
  )
  select
    v_tenant_id, 'contract_a4', 'contract', 'عقد A4', 'Contract A4', 'bilingual', 'a4',
    1, public.m3_default_template_body('contract_a4'), true, true
  on conflict (tenant_id, template_key) do nothing;

  select body_json into v_after
  from public.document_templates
  where tenant_id = v_tenant_id and template_key = 'contract_a4';

  if not exists (
    select 1
    from jsonb_array_elements(v_after -> 'blocks') b
    where b ->> 'id' = 'meta-m11-test'
  ) then
    raise exception 'custom contract template was overwritten';
  end if;
end;
$body$;
rollback;

-- 3) line_table allowlist rejects forbidden column
select pg_temp.m11_expect_invalid_contract_template(
  jsonb_set(
    public.m3_default_template_body('contract_a4'),
    '{blocks}',
    (
      select jsonb_agg(
        case
          when b ->> 'type' = 'line_table' then
            jsonb_set(
              b,
              '{columns}',
              (b -> 'columns') || jsonb_build_array(
                jsonb_build_object(
                  'field', 'line.group', 'label_key', 'col.group',
                  'label_ar', 'مجموعة', 'label_en', 'Group',
                  'width_pct', 10, 'align', 'start'
                )
              )
            )
          else b
        end
      )
      from jsonb_array_elements(public.m3_default_template_body('contract_a4') -> 'blocks') b
    )
  )
);

-- 4) signature_url is gated by contracts.print
begin;
set local role postgres;
grant execute on function public.mask_contract_read_json(jsonb) to authenticated;

delete from public.user_permissions
where tenant_user_id = '00000000-0000-0000-0000-000000000305'
  and permission_id in ('contracts.view', 'contracts.print');

insert into public.user_permissions (
  tenant_id, tenant_user_id, permission_id, granted_by
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000305',
  'contracts.view',
  '00000000-0000-0000-0000-000000000201'
);

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $body$
declare
  v_masked jsonb;
begin
  v_masked := public.mask_contract_read_json(
    jsonb_build_object(
      'signature_url', 'https://example.com/sig.png',
      'asset_lines', '[]'::jsonb,
      'consumable_lines', '[]'::jsonb
    )
  );

  if v_masked ? 'signature_url' then
    raise exception 'signature_url leaked without contracts.print';
  end if;
end;
$body$;

set local role postgres;
insert into public.user_permissions (
  tenant_id, tenant_user_id, permission_id, granted_by
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000305',
  'contracts.print',
  '00000000-0000-0000-0000-000000000201'
);

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000205';
do $body$
declare
  v_masked jsonb;
begin
  v_masked := public.mask_contract_read_json(
    jsonb_build_object(
      'signature_url', 'https://example.com/sig.png',
      'asset_lines', '[]'::jsonb,
      'consumable_lines', '[]'::jsonb
    )
  );

  if v_masked ->> 'signature_url' is distinct from 'https://example.com/sig.png' then
    raise exception 'signature_url missing with contracts.print';
  end if;
end;
$body$;
rollback;

-- 5) build_contract_detail_json and mask include M11 fields
do $body$
begin
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'build_contract_detail_json'
      and pg_get_functiondef(p.oid) like '%snapshot_unit_primary%'
  ) then
    raise exception 'build_contract_detail_json missing snapshot_unit_primary';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'build_contract_detail_json'
      and pg_get_functiondef(p.oid) like '%contact_person_name%'
  ) then
    raise exception 'build_contract_detail_json missing contact fields';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'mask_contract_read_json'
      and pg_get_functiondef(p.oid) like '%contracts.print%'
  ) then
    raise exception 'mask_contract_read_json missing contracts.print gate';
  end if;

  if not (
    public.m3_allowed_block_types('contract', 'a4') @> array['contract_totals', 'signature']
  ) then
    raise exception 'contract allowed blocks missing contract_totals or signature';
  end if;
end;
$body$;

select 'phase_6_contract_pdf_verification_passed'::text as result;
