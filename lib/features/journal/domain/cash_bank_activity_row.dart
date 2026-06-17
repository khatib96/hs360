import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../accounting/domain/journal_source.dart';

class CashBankActivityRow {
  const CashBankActivityRow({
    required this.entryDate,
    required this.entryNumber,
    required this.source,
    this.sourceId,
    this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });

  final DateTime entryDate;
  final String entryNumber;
  final JournalSource source;
  final String? sourceId;
  final String? description;
  final Decimal debit;
  final Decimal credit;
  final Decimal runningBalance;

  factory CashBankActivityRow.fromJson(Map<String, dynamic> json) {
    return CashBankActivityRow(
      entryDate: DateTime.parse(json['entry_date'] as String),
      entryNumber: json['entry_number'] as String,
      source: JournalSource.fromDb(json['source'] as String?),
      sourceId: json['source_id'] as String?,
      description: json['description'] as String?,
      debit: parseDecimal(json['debit']),
      credit: parseDecimal(json['credit']),
      runningBalance: parseDecimal(json['running_balance']),
    );
  }
}

class CashBankActivityPage {
  const CashBankActivityPage({
    required this.accountId,
    required this.accountCode,
    required this.accountNameAr,
    required this.accountNameEn,
    this.dateFrom,
    this.dateTo,
    required this.openingBalance,
    required this.limit,
    required this.offset,
    required this.rows,
  });

  final String accountId;
  final String accountCode;
  final String accountNameAr;
  final String accountNameEn;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Decimal openingBalance;
  final int limit;
  final int offset;
  final List<CashBankActivityRow> rows;
}
