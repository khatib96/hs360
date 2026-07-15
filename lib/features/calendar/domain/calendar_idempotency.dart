import 'dart:math';

import '../../../core/errors/calendar_exception.dart';

/// Preserves a mutation idempotency key across retries until a definite outcome.
///
/// Mirrors [FinanceIdempotencySession] for calendar mutation RPCs.
class CalendarIdempotencySession {
  CalendarIdempotencySession() : _key = _newUuidV4();

  String _key;

  String get key => _key;

  void regenerate() {
    _key = _newUuidV4();
  }

  void clear() {
    _key = _newUuidV4();
  }

  /// Returns true when the same key should be reused on retry.
  bool shouldPreserveKeyOn(CalendarException error) {
    return switch (error.code) {
      CalendarException.validationFailed ||
      CalendarException.permissionDenied ||
      CalendarException.idempotencyPayloadMismatch ||
      CalendarException.tenantNotFound ||
      CalendarException.staleVersion ||
      CalendarException.notAvailable ||
      CalendarException.malformedResponse ||
      CalendarException.confirmationRequired => false,
      _ => true,
    };
  }
}

String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-'
      '${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-'
      '${value.substring(16, 20)}-'
      '${value.substring(20, 32)}';
}
