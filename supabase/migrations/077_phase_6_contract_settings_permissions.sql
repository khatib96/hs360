-- Phase 6 M1: contract settings, permissions catalog, and schema hardening foundation.
-- Contract types: trial (عقد تجريبي) and rental (عقد إيجار) only.
-- No contract RPCs, billing engine, or depreciation posting in this migration.

-- ---------------------------------------------------------------------------
-- Section A: enums
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'rental_asset_cost_basis') then
    create type public.rental_asset_cost_basis as enum (
      'unit_purchase_cost',
      'product_avg_cost',
      'product_sale_price'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'rental_consumable_cost_basis') then
    create type public.rental_consumable_cost_basis as enum (
      'product_sale_price',
      'product_avg_cost',
      'product_last_purchase_cost'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'first_rental_invoice_policy') then
    create type public.first_rental_invoice_policy as enum (
      'on_activation',
      'first_billing_day',
      'manual'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'contract_line_cost_basis') then
    create type public.contract_line_cost_basis as enum (
      'unit_purchase_cost',
      'product_avg_cost',
      'product_sale_price',
      'product_last_purchase_cost'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section B: tenant_settings contract columns
-- ---------------------------------------------------------------------------
alter table public.tenant_settings
  add column if not exists rental_asset_cost_basis public.rental_asset_cost_basis
    not null default 'unit_purchase_cost',
  add column if not exists rental_consumable_cost_basis public.rental_consumable_cost_basis
    not null default 'product_sale_price',
  add column if not exists default_contract_term_months int not null default 12,
  add column if not exists first_rental_invoice_policy public.first_rental_invoice_policy
    not null default 'first_billing_day',
  add column if not exists record_trial_usage_facts boolean not null default true,
  add column if not exists track_rental_depreciation boolean not null default false,
  add column if not exists allow_multi_asset_contracts boolean not null default true,
  add column if not exists allow_multi_consumable_contracts boolean not null default true;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'chk_tenant_settings_default_contract_term_months'
  ) then
    alter table public.tenant_settings
      add constraint chk_tenant_settings_default_contract_term_months
      check (default_contract_term_months between 1 and 120);
  end if;
end $$;

comment on column public.tenant_settings.rental_asset_cost_basis is
  'Default internal cost basis for rental asset lines on new rental contracts. '
  'Typical default: selected unit purchase cost when available.';

comment on column public.tenant_settings.rental_consumable_cost_basis is
  'Default internal cost basis for rental consumable lines on new rental contracts. '
  'Typical default: product sale price.';

comment on column public.tenant_settings.default_contract_term_months is
  'Default duration in months for new rental contracts (عقد إيجار). '
  'This is a term default, not a separate contract type.';

comment on column public.tenant_settings.first_rental_invoice_policy is
  'When the first rental-contract customer invoice may be generated: on activation, '
  'on the first billing day, or manual only.';

comment on column public.tenant_settings.record_trial_usage_facts is
  'When true, trial contracts (عقد تجريبي) may record internal usage/consumable facts '
  'for reporting. This does not create a third contract type.';

comment on column public.tenant_settings.track_rental_depreciation is
  'Reserved only. When true in a future phase, rental contracts may track depreciation '
  'metadata. Phase 6 does not post depreciation journal entries.';

comment on column public.tenant_settings.allow_multi_asset_contracts is
  'When true, a rental or trial contract may include more than one serialized asset line.';

comment on column public.tenant_settings.allow_multi_consumable_contracts is
  'When true, a rental or trial contract may include more than one consumable line.';

-- ---------------------------------------------------------------------------
-- Section C prerequisite: contracts composite unique for tenant-safe FKs
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.contracts'::regclass
      and conname = 'ux_contracts_tenant_id_id'
  ) then
    alter table public.contracts
      add constraint ux_contracts_tenant_id_id unique (tenant_id, id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Section D: contracts lifecycle and pricing snapshot columns
-- ---------------------------------------------------------------------------
alter table public.contracts
  add column if not exists converted_from_contract_id uuid,
  add column if not exists converted_to_contract_id uuid,
  add column if not exists renewed_from_contract_id uuid,
  add column if not exists renewed_to_contract_id uuid,
  add column if not exists extension_reason text,
  add column if not exists returned_at timestamptz,
  add column if not exists returned_by uuid references auth.users (id),
  add column if not exists return_condition text,
  add column if not exists return_reason text,
  add column if not exists snapshot_asset_cost_basis public.rental_asset_cost_basis,
  add column if not exists snapshot_consumable_cost_basis public.rental_consumable_cost_basis,
  add column if not exists snapshot_asset_lifespan_months int;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'fk_contracts_converted_from'
  ) then
    alter table public.contracts
      add constraint fk_contracts_converted_from
      foreign key (tenant_id, converted_from_contract_id)
      references public.contracts (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'fk_contracts_converted_to'
  ) then
    alter table public.contracts
      add constraint fk_contracts_converted_to
      foreign key (tenant_id, converted_to_contract_id)
      references public.contracts (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'fk_contracts_renewed_from'
  ) then
    alter table public.contracts
      add constraint fk_contracts_renewed_from
      foreign key (tenant_id, renewed_from_contract_id)
      references public.contracts (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'fk_contracts_renewed_to'
  ) then
    alter table public.contracts
      add constraint fk_contracts_renewed_to
      foreign key (tenant_id, renewed_to_contract_id)
      references public.contracts (tenant_id, id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_contracts_no_self_conversion_from'
  ) then
    alter table public.contracts
      add constraint chk_contracts_no_self_conversion_from
      check (converted_from_contract_id is null or converted_from_contract_id <> id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_contracts_no_self_conversion_to'
  ) then
    alter table public.contracts
      add constraint chk_contracts_no_self_conversion_to
      check (converted_to_contract_id is null or converted_to_contract_id <> id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_contracts_no_self_renewal_from'
  ) then
    alter table public.contracts
      add constraint chk_contracts_no_self_renewal_from
      check (renewed_from_contract_id is null or renewed_from_contract_id <> id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_contracts_no_self_renewal_to'
  ) then
    alter table public.contracts
      add constraint chk_contracts_no_self_renewal_to
      check (renewed_to_contract_id is null or renewed_to_contract_id <> id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_contracts_snapshot_asset_lifespan_months'
  ) then
    alter table public.contracts
      add constraint chk_contracts_snapshot_asset_lifespan_months
      check (
        snapshot_asset_lifespan_months is null
        or (
          snapshot_asset_lifespan_months > 0
          and snapshot_asset_lifespan_months <= 600
        )
      );
  end if;
end $$;

comment on column public.contracts.converted_from_contract_id is
  'Prior trial or rental contract this contract was converted from (same tenant).';

comment on column public.contracts.converted_to_contract_id is
  'Successor rental contract when a trial contract was converted (same tenant).';

comment on column public.contracts.renewed_from_contract_id is
  'Prior rental contract this contract renews from (same tenant).';

comment on column public.contracts.renewed_to_contract_id is
  'Successor rental contract created by renewal (same tenant).';

comment on column public.contracts.extension_reason is
  'Reason recorded when a trial contract end date is extended.';

comment on column public.contracts.returned_at is
  'When the contract return workflow completed (trial return or rental closure).';

comment on column public.contracts.returned_by is
  'Authenticated user who recorded the contract return.';

comment on column public.contracts.return_condition is
  'Contract-level return summary only (not per-device truth). Per-unit return state '
  '(good/damaged/lost) is owned at contract_line/product_unit level in later milestones.';

comment on column public.contracts.return_reason is
  'Free-text reason for contract return or early closure.';

comment on column public.contracts.snapshot_asset_cost_basis is
  'Immutable signing snapshot of rental asset cost basis used for profit calculation.';

comment on column public.contracts.snapshot_consumable_cost_basis is
  'Immutable signing snapshot of rental consumable cost basis used for profit calculation.';

comment on column public.contracts.snapshot_asset_lifespan_months is
  'Immutable signing snapshot of asset lifespan months used for monthly basis math. '
  'Pricing/profit basis only; not accounting depreciation.';

-- ---------------------------------------------------------------------------
-- Section E: contract_lines pricing snapshot metadata
-- ---------------------------------------------------------------------------
alter table public.contract_lines
  add column if not exists snapshot_cost_basis public.contract_line_cost_basis;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'chk_contract_lines_snapshot_cost_basis_line_type'
  ) then
    alter table public.contract_lines
      add constraint chk_contract_lines_snapshot_cost_basis_line_type
      check (
        snapshot_cost_basis is null
        or (
          line_type = 'asset'
          and snapshot_cost_basis in (
            'unit_purchase_cost',
            'product_avg_cost',
            'product_sale_price'
          )
        )
        or (
          line_type = 'consumable'
          and snapshot_cost_basis in (
            'product_sale_price',
            'product_avg_cost',
            'product_last_purchase_cost'
          )
        )
      );
  end if;
end $$;

comment on column public.contract_lines.snapshot_cost_basis is
  'Immutable signing snapshot of which cost basis was used for this line. '
  'Asset lines allow asset bases; consumable lines allow consumable bases.';

-- ---------------------------------------------------------------------------
-- Section F: rental invoice billing period duplicate prevention
-- ---------------------------------------------------------------------------
alter table public.invoices
  add column if not exists billing_period_start date,
  add column if not exists billing_period_end date;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'chk_invoices_billing_period_pair'
  ) then
    alter table public.invoices
      add constraint chk_invoices_billing_period_pair
      check (
        (billing_period_start is null and billing_period_end is null)
        or (billing_period_start is not null and billing_period_end is not null)
      );
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'chk_invoices_billing_period_order'
  ) then
    alter table public.invoices
      add constraint chk_invoices_billing_period_order
      check (
        billing_period_start is null
        or billing_period_end is null
        or billing_period_start <= billing_period_end
      );
  end if;
end $$;

create unique index if not exists ux_invoices_rental_contract_period
  on public.invoices (tenant_id, contract_id, billing_period_start)
  where type = 'rental_monthly'
    and contract_id is not null
    and billing_period_start is not null
    and status <> 'cancelled';

comment on column public.invoices.billing_period_start is
  'Inclusive start of the rental-contract billing period for rental_monthly invoices. '
  'Used with billing_period_end for duplicate prevention per contract and period.';

comment on column public.invoices.billing_period_end is
  'Inclusive end of the rental-contract billing period for rental_monthly invoices.';

-- ---------------------------------------------------------------------------
-- Section G: permissions catalog (7 new contract permissions)
-- ---------------------------------------------------------------------------
insert into public.permissions (
  id, module, action, scope, field_name, label_ar, label_en, is_sensitive, category, sort_order
)
values
  (
    'contracts.close', 'contracts', 'close', 'action', null,
    'إغلاق عقد', 'Close contracts', false, 'sales', 140
  ),
  (
    'contracts.approve_override', 'contracts', 'approve', 'action', null,
    'الموافقة على تجاوز الحد الأدنى', 'Approve min-profit overrides', true, 'sales', 141
  ),
  (
    'contracts.convert_trial', 'contracts', 'convert_trial', 'action', null,
    'تحويل عقد تجريبي إلى إيجار', 'Convert trial contract to rental', false, 'sales', 142
  ),
  (
    'contracts.extend_trial', 'contracts', 'extend_trial', 'action', null,
    'تمديد عقد تجريبي', 'Extend trial contract', false, 'sales', 143
  ),
  (
    'contracts.return_trial', 'contracts', 'return_trial', 'action', null,
    'إرجاع عقد تجريبي', 'Return trial contract', false, 'sales', 144
  ),
  (
    'contracts.print', 'contracts', 'print', 'action', null,
    'طباعة عقد', 'Print contracts', false, 'sales', 145
  ),
  (
    'contracts.field.snapshot_total_cost', 'contracts', 'view', 'field',
    'snapshot_total_monthly_cost',
    'عرض إجمالي التكلفة الشهرية في العقد', 'View total monthly cost snapshot',
    true, 'sales', 146
  )
on conflict (id) do nothing;
