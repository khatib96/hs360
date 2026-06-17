import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';

/// Money amount with tenant currency metadata from list RPC rows.
class CurrencyTotalDto {
  const CurrencyTotalDto({
    required this.amount,
    this.currencyCode,
    this.currencySymbol,
    this.decimalPlaces = 3,
  });

  final Decimal amount;
  final String? currencyCode;
  final String? currencySymbol;
  final int decimalPlaces;

  factory CurrencyTotalDto.fromRpcRow(
    Map<String, dynamic> row, {
    String amountKey = 'total',
  }) {
    return CurrencyTotalDto(
      amount: parseDecimal(row[amountKey]),
      currencyCode: row['currency_code'] as String?,
      currencySymbol: row['currency_symbol'] as String?,
      decimalPlaces: row['currency_decimal_places'] as int? ?? 3,
    );
  }
}
