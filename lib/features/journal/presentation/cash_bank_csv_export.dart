import 'package:decimal/decimal.dart';

import '../domain/cash_bank_activity_row.dart';

/// Builds CSV for the currently loaded cash-bank page (not a full export).
String buildCashBankLoadedRowsCsv({
  required String accountCode,
  required String accountName,
  required Decimal openingBalance,
  required List<CashBankActivityRow> rows,
  required String dateColumnLabel,
  required String entryColumnLabel,
  required String sourceColumnLabel,
  required String descriptionColumnLabel,
  required String debitColumnLabel,
  required String creditColumnLabel,
  required String balanceColumnLabel,
  required String openingBalanceLabel,
}) {
  final buffer = StringBuffer()
    ..writeln(
      '${_escape(accountCode)},${_escape(accountName)}',
    )
    ..writeln(
      '${_escape(openingBalanceLabel)},${_escape(openingBalance.toString())}',
    )
    ..writeln(
      [
        dateColumnLabel,
        entryColumnLabel,
        sourceColumnLabel,
        descriptionColumnLabel,
        debitColumnLabel,
        creditColumnLabel,
        balanceColumnLabel,
      ].map(_escape).join(','),
    );

  for (final row in rows) {
    buffer.writeln(
      [
        row.entryDate.toIso8601String().split('T').first,
        row.entryNumber,
        row.source.toDb(),
        row.description ?? '',
        row.debit.toString(),
        row.credit.toString(),
        row.runningBalance.toString(),
      ].map(_escape).join(','),
    );
  }

  return buffer.toString();
}

String _escape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
