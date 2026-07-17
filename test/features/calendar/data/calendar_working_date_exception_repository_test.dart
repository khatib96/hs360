import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_working_date_exception_repository.dart';

import 'calendar_working_date_exception_fixtures.dart';
import 'calendar_working_date_exception_test_helpers.dart';

void main() {
  group('CalendarWorkingDateExceptionRepository permissions', () {
    test('listExceptions requires settings.calendar.view', () async {
      final repo = CalendarWorkingDateExceptionRepository(null);
      await expectLater(
        repo.listExceptions(testSession()),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.permissionDenied,
          ),
        ),
      );
    });

    test('getException requires settings.calendar.view', () async {
      final repo = CalendarWorkingDateExceptionRepository(null);
      await expectLater(
        repo.getException(testSession(), 'wde-1'),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.permissionDenied,
          ),
        ),
      );
    });

    test('createException requires settings.calendar.edit', () async {
      final repo = CalendarWorkingDateExceptionRepository(null);
      await expectLater(
        repo.createException(
          testSession(permissions: {'settings.calendar.view'}),
          data: sampleWorkingDateExceptionData(),
          idempotencyKey: 'idem-1',
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.permissionDenied,
          ),
        ),
      );
    });

    test('updateException requires settings.calendar.edit', () async {
      final repo = CalendarWorkingDateExceptionRepository(null);
      await expectLater(
        repo.updateException(
          testSession(),
          exceptionId: 'wde-1',
          expectedVersion: 1,
          data: sampleWorkingDateExceptionData(),
          idempotencyKey: 'idem-1',
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.permissionDenied,
          ),
        ),
      );
    });

    test('cancelException requires settings.calendar.edit', () async {
      final repo = CalendarWorkingDateExceptionRepository(null);
      await expectLater(
        repo.cancelException(
          testSession(),
          exceptionId: 'wde-1',
          expectedVersion: 1,
          reason: 'reason',
          idempotencyKey: 'idem-1',
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.permissionDenied,
          ),
        ),
      );
    });

    test(
      'supabaseNotConfigured after permission ok with null client',
      () async {
        final repo = CalendarWorkingDateExceptionRepository(null);
        await expectLater(
          repo.listExceptions(
            testSession(permissions: {'settings.calendar.view'}),
          ),
          throwsA(
            isA<CalendarException>().having(
              (e) => e.code,
              'code',
              CalendarException.supabaseNotConfigured,
            ),
          ),
        );
      },
    );
  });

  group('CalendarWorkingDateExceptionRepository validation', () {
    test('listExceptions rejects a lone date_from/date_to', () async {
      final repo = CalendarWorkingDateExceptionRepository(null);
      await expectLater(
        repo.listExceptions(
          testSession(permissions: {'settings.calendar.view'}),
          dateFrom: DateTime(2026, 1, 1),
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.validationFailed,
          ),
        ),
      );
    });

    test('listExceptions rejects limits outside 1..100', () async {
      final repo = CalendarWorkingDateExceptionRepository(null);
      for (final limit in [0, 101]) {
        await expectLater(
          repo.listExceptions(
            testSession(permissions: {'settings.calendar.view'}),
            limit: limit,
          ),
          throwsA(
            isA<CalendarException>().having(
              (error) => error.code,
              'code',
              CalendarException.validationFailed,
            ),
          ),
        );
      }
    });

    test('listExceptions rejects reversed and oversized ranges', () async {
      final repo = CalendarWorkingDateExceptionRepository(null);
      for (final dates in [
        (DateTime(2026, 2, 1), DateTime(2026, 1, 1)),
        (DateTime(2026, 1, 1), DateTime(2029, 1, 2)),
      ]) {
        await expectLater(
          repo.listExceptions(
            testSession(permissions: {'settings.calendar.view'}),
            dateFrom: dates.$1,
            dateTo: dates.$2,
          ),
          throwsA(
            isA<CalendarException>().having(
              (error) => error.code,
              'code',
              CalendarException.validationFailed,
            ),
          ),
        );
      }
    });

    test(
      'cancelException rejects an empty reason before invoking rpc',
      () async {
        var invoked = false;
        final repo = CalendarWorkingDateExceptionRepository(
          null,
          rpcInvoker: (name, params) async {
            invoked = true;
            return okMutationResultRpc();
          },
        );
        await expectLater(
          repo.cancelException(
            testSession(isManager: true),
            exceptionId: 'wde-1',
            expectedVersion: 1,
            reason: '   ',
            idempotencyKey: 'idem-1',
          ),
          throwsA(
            isA<CalendarException>().having(
              (e) => e.code,
              'code',
              CalendarException.validationFailed,
            ),
          ),
        );
        expect(invoked, isFalse);
      },
    );
  });
}
