import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Formats money for display. Not wired to app localization in M2.
String formatMoney(Decimal value, {int decimalPlaces = 3, String? locale}) {
  final pattern = decimalPlaces > 0 ? '#,##0.${'0' * decimalPlaces}' : '#,##0';
  final formatter = NumberFormat(pattern, locale ?? 'en');
  return formatter.format(value.toDouble());
}
