import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../accounting/domain/journal_source.dart';

/// One row from [get_customer_statement] RPC.
class CustomerStatementRow {
  const CustomerStatementRow({
    required this.entryDate,
    required this.entryNumber,
    required this.source,
    this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });

  final DateTime entryDate;
  final String entryNumber;
  final JournalSource source;
  final String? description;
  final Decimal debit;
  final Decimal credit;
  final Decimal runningBalance;

  factory CustomerStatementRow.fromRow(Map<String, dynamic> row) {
    return CustomerStatementRow(
      entryDate: DateTime.parse(row['entry_date'] as String),
      entryNumber: row['entry_number'] as String,
      source: JournalSource.fromDb(row['source'] as String?),
      description: row['description'] as String?,
      debit: parseDecimal(row['debit']),
      credit: parseDecimal(row['credit']),
      runningBalance: parseDecimal(row['running_balance']),
    );
  }
}
