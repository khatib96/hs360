-- Phase 5 M1 (AD-4): journal_source reversal values only.
-- Must be in a separate migration file: new enum values cannot be used in the
-- same transaction where they are added.

alter type journal_source add value if not exists 'sales_invoice_reversal';
alter type journal_source add value if not exists 'purchase_invoice_reversal';
alter type journal_source add value if not exists 'receipt_voucher_reversal';
alter type journal_source add value if not exists 'payment_voucher_reversal';
