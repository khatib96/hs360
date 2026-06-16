-- Phase 5 M7.5: journal_source values for returns and refund vouchers.
-- Must be separate from RPC migration: new enum values cannot be used in the
-- same transaction where they are added (see 053_phase_5_journal_source_enum.sql).

alter type journal_source add value if not exists 'sales_return';
alter type journal_source add value if not exists 'purchase_return';
alter type journal_source add value if not exists 'sales_return_reversal';
alter type journal_source add value if not exists 'purchase_return_reversal';
alter type journal_source add value if not exists 'customer_refund_voucher';
alter type journal_source add value if not exists 'supplier_refund_receipt';
