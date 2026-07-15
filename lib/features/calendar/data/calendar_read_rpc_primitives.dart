import 'package:decimal/decimal.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../../core/utils/decimal_parser.dart';
import '../domain/calendar_date.dart';

Never malformedCalendarResponse(String detail) {
  throw CalendarException(
    code: CalendarException.malformedResponse,
    technicalDetail: detail,
  );
}

Map<String, dynamic> requireMap(dynamic value, String detail) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return malformedCalendarResponse(detail);
}

List<dynamic> requireList(dynamic value, String detail) {
  if (value is List) return value;
  return malformedCalendarResponse(detail);
}

String? optionalString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return malformedCalendarResponse(
    'expected string or null, got ${value.runtimeType}',
  );
}

String requireString(dynamic value, String detail) {
  if (value is String) return value;
  return malformedCalendarResponse(detail);
}

bool requireBool(dynamic value, String detail) {
  if (value is bool) return value;
  return malformedCalendarResponse(detail);
}

/// Nullable/absent bool → null (does not reject).
bool? optionalBool(dynamic value, String detail) {
  if (value == null) return null;
  if (value is bool) return value;
  return malformedCalendarResponse(detail);
}

int requireInt(dynamic value, String detail) {
  if (value is int) return value;
  if (value is num) {
    final asInt = value.toInt();
    if (asInt == value) return asInt;
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return malformedCalendarResponse(detail);
}

int? parseNullableInt(dynamic value, String detail) {
  if (value == null) return null;
  return requireInt(value, detail);
}

DateTime parseRequiredCalendarDate(dynamic value) {
  if (value is! String) {
    return malformedCalendarResponse(
      'expected YYYY-MM-DD string, got ${value.runtimeType}',
    );
  }
  try {
    return parseCalendarDateOnly(value);
  } on FormatException catch (e) {
    return malformedCalendarResponse(e.message);
  }
}

DateTime? parseOptionalCalendarDate(dynamic value) {
  if (value == null) return null;
  return parseRequiredCalendarDate(value);
}

T requireEnum<T>(dynamic value, T? Function(String) fromRpc, String detail) {
  final raw = requireString(value, detail);
  final parsed = fromRpc(raw);
  if (parsed == null) {
    return malformedCalendarResponse('$detail: unknown value "$raw"');
  }
  return parsed;
}

T? optionalEnum<T>(dynamic value, T? Function(String) fromRpc, String detail) {
  if (value == null) return null;
  return requireEnum(value, fromRpc, detail);
}

Decimal? optionalDecimal(dynamic value, String detail) {
  if (value == null) return null;
  return requireDecimal(value, detail);
}

Decimal requireDecimal(dynamic value, String detail) {
  if (value == null) return malformedCalendarResponse('$detail required');
  try {
    final parsed = tryParseDecimal(value);
    if (parsed == null) return malformedCalendarResponse(detail);
    return parsed;
  } on FormatException catch (e) {
    return malformedCalendarResponse('$detail: ${e.message}');
  }
}
