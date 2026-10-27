import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Formats money for display without converting through [double].
///
/// Grouping, digits, and signs follow [locale] exactly like
/// `NumberFormat('#,##0.000', locale)` would for the same value.
String formatMoney(Decimal value, {int decimalPlaces = 3, String? locale}) {
  final places = decimalPlaces < 0 ? 0 : decimalPlaces;
  final rounded = value.round(scale: places);
  final negative = rounded < Decimal.zero;
  final parts = (negative ? -rounded : rounded)
      .toStringAsFixed(places)
      .split('.');

  final formatter = NumberFormat('#,##0', locale ?? 'en');
  final symbols = formatter.symbols;
  final grouped = formatter.format(int.parse(parts.first));
  final fraction = parts.length > 1
      ? '${symbols.DECIMAL_SEP}${_localizeDigits(parts[1], symbols.ZERO_DIGIT)}'
      : '';

  return '${negative ? symbols.MINUS_SIGN : ''}$grouped$fraction';
}

String _localizeDigits(String asciiDigits, String zeroDigit) {
  final zero = zeroDigit.codeUnitAt(0);
  if (zero == 0x30) return asciiDigits;
  return String.fromCharCodes(
    asciiDigits.codeUnits.map((unit) => zero + unit - 0x30),
  );
}
