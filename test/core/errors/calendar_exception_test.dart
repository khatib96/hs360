import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('CalendarException.fromSupabase', () {
    test('maps tenant_not_found', () {
      expect(
        CalendarException.fromSupabase(Exception('tenant_not_found')).code,
        CalendarException.tenantNotFound,
      );
    });

    test('maps permission_denied from PostgrestException', () {
      expect(
        CalendarException.fromSupabase(
          const PostgrestException(message: 'permission_denied'),
        ).code,
        CalendarException.permissionDenied,
      );
    });

    test('maps invalid_cursor', () {
      expect(
        CalendarException.fromSupabase(Exception('invalid_cursor')).code,
        CalendarException.invalidCursor,
      );
    });

    test('maps not_available and malformed_response', () {
      expect(
        CalendarException.fromSupabase(Exception('not_available')).code,
        CalendarException.notAvailable,
      );
      expect(
        CalendarException.fromSupabase(Exception('malformed_response')).code,
        CalendarException.malformedResponse,
      );
    });

    test('maps validation_failed to invalidCursor when cursorSupplied', () {
      expect(
        CalendarException.fromSupabase(
          Exception('validation_failed'),
          cursorSupplied: true,
        ).code,
        CalendarException.invalidCursor,
      );
    });

    test('maps validation_failed normally when cursor not supplied', () {
      expect(
        CalendarException.fromSupabase(Exception('validation_failed')).code,
        CalendarException.validationFailed,
      );
    });

    test('maps unknown messages to unknown', () {
      expect(
        CalendarException.fromSupabase(Exception('network timeout')).code,
        CalendarException.unknown,
      );
    });

    test('rethrow-preserving when already CalendarException', () {
      const original = CalendarException(
        code: CalendarException.malformedResponse,
      );
      expect(CalendarException.fromSupabase(original), same(original));
    });

    test('notConfigured factory', () {
      expect(
        CalendarException.notConfigured().code,
        CalendarException.supabaseNotConfigured,
      );
    });
  });
}
