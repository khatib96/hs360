import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_working_date_exception_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';

import 'calendar_working_date_exception_fixtures.dart';
import 'calendar_working_date_exception_test_helpers.dart';

void main() {
  group('CalendarWorkingDateExceptionRepository exact RPC contracts', () {
    test('list_working_date_exceptions name and parameter map', () async {
      String? capturedName;
      Map<String, dynamic>? capturedParams;
      final repo = CalendarWorkingDateExceptionRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedName = name;
          capturedParams = Map<String, dynamic>.from(params);
          return validExceptionListRpc();
        },
      );

      await repo.listExceptions(
        testSession(isManager: true),
        status: CalendarWorkingDateExceptionStatusFilter.cancelled,
        kind: CalendarWorkingDateExceptionKind.companyClosure,
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 12, 31),
        cursor: 'cursor-1',
        limit: 20,
      );

      expect(capturedName, 'list_working_date_exceptions');
      expect(capturedParams, {
        'p_filters': {
          'status': 'cancelled',
          'kind': 'company_closure',
          'date_from': '2026-01-01',
          'date_to': '2026-12-31',
        },
        'p_cursor': 'cursor-1',
        'p_limit': 20,
      });
    });

    test('list_working_date_exceptions omits kind/date when absent', () async {
      Map<String, dynamic>? capturedParams;
      final repo = CalendarWorkingDateExceptionRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedParams = Map<String, dynamic>.from(params);
          return validExceptionListRpc();
        },
      );

      await repo.listExceptions(testSession(isManager: true));

      final filters = capturedParams!['p_filters'] as Map<String, dynamic>;
      expect(filters, {'status': 'active'});
    });

    test('get_working_date_exception name and parameter map', () async {
      String? capturedName;
      Map<String, dynamic>? capturedParams;
      final repo = CalendarWorkingDateExceptionRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedName = name;
          capturedParams = Map<String, dynamic>.from(params);
          return validHolidayExceptionRpc();
        },
      );

      await repo.getException(testSession(isManager: true), 'wde-1');

      expect(capturedName, 'get_working_date_exception');
      expect(capturedParams, {'p_exception_id': 'wde-1'});
    });

    test('create_working_date_exception name and parameter map', () async {
      String? capturedName;
      Map<String, dynamic>? capturedParams;
      final repo = CalendarWorkingDateExceptionRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedName = name;
          capturedParams = Map<String, dynamic>.from(params);
          return okMutationResultRpc();
        },
      );

      await repo.createException(
        testSession(isManager: true),
        data: WorkingDateExceptionData(
          kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
          startDate: DateTime(2026, 8, 8),
          endDate: DateTime(2026, 8, 8),
          titleAr: 'يوم عمل',
          dayMode: TenantWorkingDayMode.workingHours,
          workStart: '08:00',
          workEnd: '12:00',
        ),
        idempotencyKey: 'idem-1',
      );

      expect(capturedName, 'create_working_date_exception');
      expect(capturedParams, {
        'p_data': {
          'kind': 'exceptional_working_day',
          'start_date': '2026-08-08',
          'end_date': '2026-08-08',
          'title_ar': 'يوم عمل',
          'title_en': null,
          'notes': null,
          'day_mode': 'working_hours',
          'work_start': '08:00',
          'work_end': '12:00',
        },
        'p_idempotency_key': 'idem-1',
      });
    });

    test('update_working_date_exception name and parameter map', () async {
      String? capturedName;
      Map<String, dynamic>? capturedParams;
      final repo = CalendarWorkingDateExceptionRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedName = name;
          capturedParams = Map<String, dynamic>.from(params);
          return okMutationResultRpc();
        },
      );

      await repo.updateException(
        testSession(isManager: true),
        exceptionId: 'wde-1',
        expectedVersion: 3,
        data: sampleWorkingDateExceptionData(),
        idempotencyKey: 'idem-2',
      );

      expect(capturedName, 'update_working_date_exception');
      expect(capturedParams, {
        'p_exception_id': 'wde-1',
        'p_expected_version': 3,
        'p_data': {
          'kind': 'official_holiday',
          'start_date': '2026-08-01',
          'end_date': '2026-08-01',
          'title_ar': 'عيد',
          'title_en': 'Holiday',
          'notes': null,
          'day_mode': null,
          'work_start': null,
          'work_end': null,
        },
        'p_idempotency_key': 'idem-2',
      });
    });

    test('cancel_working_date_exception name and parameter map', () async {
      String? capturedName;
      Map<String, dynamic>? capturedParams;
      final repo = CalendarWorkingDateExceptionRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedName = name;
          capturedParams = Map<String, dynamic>.from(params);
          return okMutationResultRpc();
        },
      );

      await repo.cancelException(
        testSession(isManager: true),
        exceptionId: 'wde-1',
        expectedVersion: 2,
        reason: '  Owner correction  ',
        idempotencyKey: 'idem-3',
      );

      expect(capturedName, 'cancel_working_date_exception');
      expect(capturedParams, {
        'p_exception_id': 'wde-1',
        'p_expected_version': 2,
        'p_reason': 'Owner correction',
        'p_idempotency_key': 'idem-3',
      });
    });

    test('overlap failure maps to workingDateExceptionOverlap', () async {
      final repo = CalendarWorkingDateExceptionRepository(
        null,
        rpcInvoker: (name, params) async {
          throw Exception('working_date_exception_overlap');
        },
      );

      await expectLater(
        repo.createException(
          testSession(isManager: true),
          data: sampleWorkingDateExceptionData(),
          idempotencyKey: 'idem-1',
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.workingDateExceptionOverlap,
          ),
        ),
      );
    });

    test('stale version failure maps to staleVersion', () async {
      final repo = CalendarWorkingDateExceptionRepository(
        null,
        rpcInvoker: (name, params) async {
          throw Exception('stale_version');
        },
      );

      await expectLater(
        repo.updateException(
          testSession(isManager: true),
          exceptionId: 'wde-1',
          expectedVersion: 1,
          data: sampleWorkingDateExceptionData(),
          idempotencyKey: 'idem-1',
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.staleVersion,
          ),
        ),
      );
    });

    test('legacy not_found maps to the stable unavailable code', () async {
      final repo = CalendarWorkingDateExceptionRepository(
        null,
        rpcInvoker: (name, params) async => throw Exception('not_found'),
      );

      await expectLater(
        repo.getException(testSession(isManager: true), 'missing'),
        throwsA(
          isA<CalendarException>().having(
            (error) => error.code,
            'code',
            CalendarException.notAvailable,
          ),
        ),
      );
    });
  });
}
