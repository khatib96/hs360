import 'package:decimal/decimal.dart';

/// Parses Postgres numeric values without using [double].
Decimal parseDecimal(dynamic value) {
  final parsed = tryParseDecimal(value);
  if (parsed == null) {
    throw FormatException('Cannot parse decimal from $value');
  }
  return parsed;
}

/// Returns null for null input; never converts via [double].
Decimal? tryParseDecimal(dynamic value) {
  if (value == null) return null;
  if (value is Decimal) return value;
  if (value is int) return Decimal.fromInt(value);
  if (value is BigInt) return Decimal.fromBigInt(value);
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return Decimal.parse(trimmed);
  }
  // Postgres may return num from JSON — use string conversion to avoid double.
  if (value is num) {
    return Decimal.parse(value.toString());
  }
  throw FormatException('Unsupported decimal type: ${value.runtimeType}');
}
