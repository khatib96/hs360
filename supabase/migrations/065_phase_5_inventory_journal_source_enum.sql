-- Phase 5 M4.5: journal_source values for inventory financial documents.
-- Must be separate from RPC migration: new enum values cannot be used in the
-- same transaction where they are added (see 053/063).

alter type journal_source add value if not exists 'opening_stock';
alter type journal_source add value if not exists 'inventory_stock_in';
alter type journal_source add value if not exists 'inventory_stock_out';
alter type journal_source add value if not exists 'stock_count';
alter type journal_source add value if not exists 'inventory_document_reversal';
