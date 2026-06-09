import 'package:decimal/decimal.dart';

import 'tenant_currency_format.dart';

/// Formats [Decimal] money values without converting through [double].
String formatDocumentMoney(
  Decimal value,
  TenantCurrencyFormat format, {
  String? languageCode,
  bool includeSymbol = true,
}) {
  final places = format.decimalPlaces;
  final scaled = _roundDecimal(value, places);
  final negative = scaled < Decimal.zero;
  final abs = negative ? -scaled : scaled;

  final parts = abs.toString().split('.');
  final intPart = parts.first;
  final fracPart = places > 0
      ? _padFraction(parts.length > 1 ? parts[1] : '', places)
      : '';

  final grouped = _groupInteger(intPart, format.thousandSeparator);
  final number = places > 0
      ? '$grouped${format.decimalSeparator}$fracPart'
      : grouped;

  if (!includeSymbol) {
    return negative ? '-$number' : number;
  }

  final symbol = format.symbolForLocale(languageCode ?? 'en');
  final signed = negative ? '-$number' : number;
  if (format.symbolPosition == 'before') {
    return '$symbol$signed';
  }
  return '$signed $symbol';
}

/// Fast path for DTO money strings that are already normalized to the tenant
/// decimal scale. Returns null when parsing or Decimal rounding is required.
String? tryFormatSerializedDocumentMoney(
  String rawValue,
  TenantCurrencyFormat format, {
  String? languageCode,
  bool includeSymbol = true,
}) {
  final value = rawValue.trim();
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(value);
  if (match == null) return null;

  final places = format.decimalPlaces;
  final fraction = match.group(3) ?? '';
  if (fraction.length > places) return null;

  var integer = match.group(2)!;
  integer = integer.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final paddedFraction = places > 0 ? _padFraction(fraction, places) : '';
  final grouped = _groupInteger(integer, format.thousandSeparator);
  final number = places > 0
      ? '$grouped${format.decimalSeparator}$paddedFraction'
      : grouped;
  final isZero =
      integer.replaceAll('0', '').isEmpty &&
      paddedFraction.replaceAll('0', '').isEmpty;
  final signed = match.group(1) == '-' && !isZero ? '-$number' : number;

  if (!includeSymbol) return signed;
  final symbol = format.symbolForLocale(languageCode ?? 'en');
  if (format.symbolPosition == 'before') {
    return '$symbol$signed';
  }
  return '$signed $symbol';
}

Decimal _roundDecimal(Decimal value, int places) {
  if (places <= 0) {
    return value.round(scale: 0);
  }
  return value.round(scale: places);
}

String _padFraction(String fraction, int places) {
  if (fraction.length >= places) {
    return fraction.substring(0, places);
  }
  return fraction.padRight(places, '0');
}

String _groupInteger(String digits, String separator) {
  if (digits.length <= 3) return digits;
  final buffer = StringBuffer();
  var count = 0;
  for (var i = digits.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) {
      buffer.write(separator);
    }
    buffer.write(digits[i]);
    count++;
  }
  return buffer.toString().split('').reversed.join();
}
