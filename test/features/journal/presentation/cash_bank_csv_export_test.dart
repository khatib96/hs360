import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/journal_source.dart';
import 'package:hs360/features/journal/domain/cash_bank_activity_row.dart';
import 'package:hs360/features/journal/presentation/cash_bank_csv_export.dart';

void main() {
  test('buildCashBankLoadedRowsCsv includes opening balance and loaded rows', () {
    final csv = buildCashBankLoadedRowsCsv(
      accountCode: '1000',
      accountName: 'Cash',
      openingBalance: Decimal.parse('10.000'),
      rows: [
        CashBankActivityRow(
          entryDate: DateTime(2026, 6, 1),
          entryNumber: 'JE-001',
          source: JournalSource.receiptVoucher,
          description: 'Receipt',
          debit: Decimal.parse('5.000'),
          credit: Decimal.zero,
          runningBalance: Decimal.parse('15.000'),
        ),
      ],
      dateColumnLabel: 'Date',
      entryColumnLabel: 'Entry',
      sourceColumnLabel: 'Source',
      descriptionColumnLabel: 'Description',
      debitColumnLabel: 'Debit',
      creditColumnLabel: 'Credit',
      balanceColumnLabel: 'Balance',
      openingBalanceLabel: 'Opening',
    );

    expect(csv, contains('1000,Cash'));
    expect(csv, contains('Opening,10'));
    expect(csv, contains('JE-001'));
    expect(csv, contains('receipt_voucher'));
  });
}
