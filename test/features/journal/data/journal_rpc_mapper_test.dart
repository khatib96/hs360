import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/journal_source.dart';
import 'package:hs360/features/journal/data/journal_rpc_mapper.dart';

void main() {
  group('mapJournalEntryListRow', () {
    test('maps every SQL journal_source value without throwing', () {
      const sqlValues = [
        'manual',
        'sales_invoice',
        'purchase_invoice',
        'receipt_voucher',
        'payment_voucher',
        'rental_invoice',
        'contract_creation',
        'contract_closure',
        'opening_balance',
        'inventory_adjustment',
        'salary_payment',
        'sales_invoice_reversal',
        'purchase_invoice_reversal',
        'receipt_voucher_reversal',
        'payment_voucher_reversal',
        'sales_return',
        'purchase_return',
        'sales_return_reversal',
        'purchase_return_reversal',
        'customer_refund_voucher',
        'supplier_refund_receipt',
        'opening_stock',
        'inventory_stock_in',
        'inventory_stock_out',
        'stock_count',
        'inventory_document_reversal',
      ];

      for (final source in sqlValues) {
        final row = {
          'id': 'je-1',
          'entry_number': 'JE-001',
          'date': '2026-01-15',
          'source': source,
          'source_id': 'doc-1',
          'description_ar': null,
          'description_en': null,
          'is_posted': true,
          'reversal_of_entry_id': null,
          'reversed_by_entry_id': null,
          'journal_lines': [
            {'debit': '10', 'credit': '0'},
            {'debit': '0', 'credit': '10'},
          ],
        };

        final summary = mapJournalEntryListRow(row);
        expect(summary.source, JournalSource.fromDb(source));
        expect(summary.sourceId, 'doc-1');
      }
    });
  });
}
