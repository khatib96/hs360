import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Calendar repository failures with stable [code] values.
class CalendarException extends AppException {
  const CalendarException({required super.code, super.technicalDetail});

  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
  static const tenantNotFound = 'tenant_not_found';
  static const invalidCursor = 'invalid_cursor';
  static const notAvailable = 'not_available';
  static const malformedResponse = 'malformed_response';
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';
  static const staleVersion = 'stale_version';
  static const confirmationRequired = 'confirmation_required';
  static const idempotencyPayloadMismatch = 'idempotency_payload_mismatch';
  static const localTimeNonexistent = 'calendar_local_time_nonexistent';
  static const localTimeAmbiguous = 'calendar_local_time_ambiguous';
  static const timezoneUnconfigured = 'calendar_timezone_unconfigured';
  static const timeWindowCrossDate = 'calendar_time_window_cross_date';
  static const conflictConfirmationRequired =
      'calendar_conflict_confirmation_required';
  static const workingDateExceptionOverlap = 'working_date_exception_overlap';

  factory CalendarException.fromSupabase(
    Object error, {
    StackTrace? stackTrace,
    bool cursorSupplied = false,
  }) {
    if (error is CalendarException) return error;

    final message = _extractMessage(error).toLowerCase();

    if (message.contains('tenant_not_found')) {
      return CalendarException(code: tenantNotFound, technicalDetail: message);
    }
    if (message.contains('permission_denied')) {
      return CalendarException(
        code: permissionDenied,
        technicalDetail: message,
      );
    }
    if (message.contains('invalid_cursor')) {
      return CalendarException(code: invalidCursor, technicalDetail: message);
    }
    if (message.contains('not_available')) {
      return CalendarException(code: notAvailable, technicalDetail: message);
    }
    if (message.contains('not_found')) {
      return CalendarException(code: notAvailable, technicalDetail: message);
    }
    if (message.contains('malformed_response')) {
      return CalendarException(
        code: malformedResponse,
        technicalDetail: message,
      );
    }
    if (message.contains('stale_version')) {
      return CalendarException(code: staleVersion, technicalDetail: message);
    }
    if (message.contains('idempotency_payload_mismatch')) {
      return CalendarException(
        code: idempotencyPayloadMismatch,
        technicalDetail: message,
      );
    }
    if (message.contains('calendar_local_time_nonexistent')) {
      return CalendarException(
        code: localTimeNonexistent,
        technicalDetail: message,
      );
    }
    if (message.contains('calendar_local_time_ambiguous')) {
      return CalendarException(
        code: localTimeAmbiguous,
        technicalDetail: message,
      );
    }
    if (message.contains('calendar_timezone_unconfigured')) {
      return CalendarException(
        code: timezoneUnconfigured,
        technicalDetail: message,
      );
    }
    if (message.contains('calendar_time_window_cross_date')) {
      return CalendarException(
        code: timeWindowCrossDate,
        technicalDetail: message,
      );
    }
    if (message.contains('calendar_conflict_confirmation_required') ||
        message.contains('confirmation_required')) {
      return CalendarException(
        code: confirmationRequired,
        technicalDetail: message,
      );
    }
    if (message.contains('working_date_exception_overlap')) {
      return CalendarException(
        code: workingDateExceptionOverlap,
        technicalDetail: message,
      );
    }
    if (message.contains('validation_failed')) {
      if (cursorSupplied) {
        return CalendarException(code: invalidCursor, technicalDetail: message);
      }
      return CalendarException(
        code: validationFailed,
        technicalDetail: message,
      );
    }

    return CalendarException(code: unknown, technicalDetail: message);
  }

  factory CalendarException.notConfigured() {
    return const CalendarException(code: supabaseNotConfigured);
  }

  static String _extractMessage(Object error) {
    if (error is PostgrestException) {
      return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    }
    return error.toString();
  }
}
