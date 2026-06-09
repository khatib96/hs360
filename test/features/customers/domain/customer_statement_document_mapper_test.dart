import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/journal_source.dart';
import 'package:hs360/features/customers/domain/customer_balance_summary.dart';
import 'package:hs360/features/customers/domain/customer_statement_document_mapper.dart';
import 'package:hs360/features/customers/domain/customer_statement_row.dart';

void main() {
  test('maps statement rows to document payload', () {
    final rows = [
      CustomerStatementRow(
        entryDate: DateTime(2026, 3, 1),
        entryNumber: 'JE-100',
        source: JournalSource.salesInvoice,
        description: 'Invoice',
        debit: Decimal.parse('25.000'),
        credit: Decimal.zero,
        runningBalance: Decimal.parse('125.000'),
      ),
    ];
    final summary = CustomerBalanceSummary(
      debitTotal: Decimal.parse('25.000'),
      creditTotal: Decimal.zero,
      balance: Decimal.parse('125.000'),
    );

    final payload = mapCustomerStatementToDocumentPayload(
      customerId: 'c1',
      customer: const {
        'id': 'c1',
        'code': 'C-001',
        'name_ar': 'عميل',
        'name_en': 'Customer',
      },
      rows: rows,
      summary: summary,
      fromDate: DateTime(2026, 1, 1),
      toDate: DateTime(2026, 3, 31),
    );

    expect(payload.lines, hasLength(1));
    expect(payload.lines.first.source, 'sales_invoice');
    expect(payload.summary.closingBalance, Decimal.parse('125.000'));
    expect(payload.customer['code'], 'C-001');
  });
}
