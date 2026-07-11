-- Phase 1B: tenant settings (section 3.1).

create table tenant_settings (
  tenant_id uuid primary key references tenants (id) on delete cascade,
  company_name_ar text not null,
  company_name_en text not null,
  logo_url text,

  fiscal_year_start_month int default 1,
  email_from_address text,
  email_from_name text,
  whatsapp_phone_id text,
  whatsapp_token_ref text,

  min_monthly_profit numeric(15, 3) not null default 5.000,
  default_device_lifespan_months int default 24,
  default_trial_days int default 3,
  min_profit_override_requires_admin boolean default true,

  gps_accuracy_threshold_m int default 200,
  require_signature_on_refill boolean default false,
  require_signature_on_new_contract boolean default true,

  auto_send_receipt_email boolean default true,
  auto_send_receipt_whatsapp boolean default true,
  auto_send_invoice_pdf boolean default true,

  receipt_footer_ar text,
  receipt_footer_en text,

  updated_at timestamptz default now()
);
