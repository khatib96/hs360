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
    final normalized = _normalizeDecimalText(value);
    if (normalized == null) return null;
    try {
      return Decimal.parse(normalized);
    } on FormatException {
      return null;
    }
  }
  // Postgres may return num from JSON — use string conversion to avoid double.
  if (value is num) {
    return Decimal.parse(value.toString());
  }
  throw FormatException('Unsupported decimal type: ${value.runtimeType}');
}

String? _normalizeDecimalText(String value) {
  var trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  trimmed = trimmed
      .replaceAll('٠', '0')
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll('٣', '3')
      .replaceAll('٤', '4')
      .replaceAll('٥', '5')
      .replaceAll('٦', '6')
      .replaceAll('٧', '7')
      .replaceAll('٨', '8')
      .replaceAll('٩', '9')
      .replaceAll('۰', '0')
      .replaceAll('۱', '1')
      .replaceAll('۲', '2')
      .replaceAll('۳', '3')
      .replaceAll('۴', '4')
      .replaceAll('۵', '5')
      .replaceAll('۶', '6')
      .replaceAll('۷', '7')
      .replaceAll('۸', '8')
      .replaceAll('۹', '9')
      .replaceAll('٫', '.')
      .replaceAll('،', ',')
      .replaceAll(' ', '');

  if (trimmed == '.' || trimmed == ',' || trimmed == '-' || trimmed == '+') {
    return null;
  }

  if (trimmed.contains('.') && trimmed.contains(',')) {
    trimmed = trimmed.replaceAll(',', '');
  } else if (!trimmed.contains('.') && trimmed.contains(',')) {
    trimmed = trimmed.replaceAll(',', '.');
  }

  if (trimmed.startsWith('.')) trimmed = '0$trimmed';
  if (trimmed.endsWith('.')) trimmed = '${trimmed}0';

  return trimmed;
}
