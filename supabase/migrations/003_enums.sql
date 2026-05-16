-- Phase 1A: business enums for Phase 1B tables (25 types; user_account_type is in 002).

create type employee_job_type as enum (
  'office',
  'warehouse_ops',
  'field_sales',
  'field_refill',
  'hybrid_field',
  'other'
);

create type commission_basis as enum (
  'percent_of_sale',
  'percent_of_contract_value',
  'fixed_per_new_contract',
  'fixed_per_refill'
);

create type warehouse_type as enum ('main', 'branch', 'van');

create type account_type as enum (
  'asset', 'liability', 'equity', 'income', 'expense'
);

create type product_type as enum ('sale_only', 'asset_rental', 'consumable_rental');

create type unit_of_measure as enum (
  'piece', 'liter', 'ml', 'gram', 'kg',
  'box', 'bottle', 'carton', 'meter', 'pack'
);

create type unit_status as enum (
  'available_new', 'available_used', 'rented', 'trial',
  'maintenance', 'sold', 'damaged', 'lost', 'retired'
);

create type maintenance_status as enum (
  'reported', 'in_progress', 'completed', 'unrepairable', 'cancelled'
);

create type movement_type as enum (
  'purchase', 'sale', 'rental_out', 'rental_return',
  'refill', 'transfer_out', 'transfer_in',
  'adjustment_in', 'adjustment_out',
  'sale_return', 'purchase_return',
  'maintenance_in', 'maintenance_out'
);

create type customer_type as enum ('individual', 'company');

create type contract_type as enum ('trial', 'rental');

create type contract_status as enum (
  'draft', 'active', 'suspended',
  'completed', 'terminated_early', 'expired'
);

create type contract_line_type as enum ('asset', 'consumable');

create type visit_type as enum (
  'refill', 'new_contract', 'sales_pitch',
  'maintenance_pickup', 'maintenance_dropoff',
  'collection', 'asset_return', 'inspection'
);

create type visit_status as enum (
  'scheduled', 'in_progress', 'completed',
  'missed', 'cancelled', 'rescheduled'
);

create type invoice_type as enum (
  'sales', 'purchase',
  'sales_return', 'purchase_return',
  'rental_monthly',
  'opening_balance_customer', 'opening_balance_supplier'
);

create type invoice_status as enum (
  'draft', 'confirmed', 'partially_paid', 'paid', 'cancelled'
);

create type voucher_type as enum ('receipt', 'payment');

create type payment_method as enum (
  'cash', 'knet', 'bank_transfer', 'cheque', 'other'
);

create type journal_source as enum (
  'manual', 'sales_invoice', 'purchase_invoice',
  'receipt_voucher', 'payment_voucher',
  'rental_invoice', 'contract_creation', 'contract_closure',
  'opening_balance', 'inventory_adjustment', 'salary_payment'
);

create type quotation_status as enum (
  'draft', 'sent', 'accepted', 'rejected', 'expired', 'converted'
);

create type calendar_event_type as enum (
  'refill_due', 'contract_start', 'contract_end',
  'trial_ending', 'follow_up', 'maintenance_due',
  'payment_due', 'custom'
);

create type calendar_event_status as enum (
  'pending', 'done', 'missed', 'cancelled', 'rescheduled'
);

create type notification_channel as enum ('email', 'whatsapp', 'in_app', 'sms');

create type notification_status as enum ('pending', 'sent', 'failed', 'read');
