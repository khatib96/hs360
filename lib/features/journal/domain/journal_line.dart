import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

class JournalLine {
  const JournalLine({
    required this.id,
    required this.lineOrder,
    required this.accountId,
    this.accountCode,
    this.accountNameAr,
    this.accountNameEn,
    required this.debit,
    required this.credit,
    this.description,
  });

  final String id;
  final int lineOrder;
  final String accountId;
  final String? accountCode;
  final String? accountNameAr;
  final String? accountNameEn;
  final Decimal debit;
  final Decimal credit;
  final String? description;

  factory JournalLine.fromRow(Map<String, dynamic> row) {
    final account = row['chart_of_accounts'];
    Map<String, dynamic>? accountMap;
    if (account is Map) {
      accountMap = Map<String, dynamic>.from(account);
    }
    return JournalLine(
      id: row['id'] as String,
      lineOrder: row['line_order'] as int,
      accountId: row['account_id'] as String,
      accountCode: accountMap?['code'] as String?,
      accountNameAr: accountMap?['name_ar'] as String?,
      accountNameEn: accountMap?['name_en'] as String?,
      debit: parseDecimal(row['debit']),
      credit: parseDecimal(row['credit']),
      description: row['description'] as String?,
    );
  }
}

abstract final class JournalLineColumns {
  static const list = '''
id, line_order, account_id, debit, credit, description,
chart_of_accounts (code, name_ar, name_en)
''';
}
