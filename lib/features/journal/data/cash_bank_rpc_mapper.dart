import '../../../core/utils/decimal_parser.dart';
import '../domain/cash_bank_activity_row.dart';

CashBankActivityPage mapCashBankActivityPage(Map<String, dynamic> json) {
  final rowsRaw = json['rows'];
  return CashBankActivityPage(
    accountId: json['account_id'] as String,
    accountCode: json['account_code'] as String,
    accountNameAr: json['account_name_ar'] as String? ?? '',
    accountNameEn: json['account_name_en'] as String? ?? '',
    dateFrom: json['date_from'] != null
        ? DateTime.parse(json['date_from'] as String)
        : null,
    dateTo: json['date_to'] != null
        ? DateTime.parse(json['date_to'] as String)
        : null,
    openingBalance: parseDecimal(json['opening_balance'] ?? 0),
    limit: json['limit'] as int? ?? 50,
    offset: json['offset'] as int? ?? 0,
    rows: rowsRaw is List
        ? rowsRaw
              .map(
                (row) => CashBankActivityRow.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
        : const [],
  );
}
