import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_working_date_exception_rpc_mapper.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';

import 'calendar_working_date_exception_fixtures.dart';

Matcher _malformed() => isA<CalendarException>().having(
  (e) => e.code,
  'code',
  CalendarException.malformedResponse,
);

void main() {
  group('mapCalendarDateExceptionRef', () {
    test('null maps to null', () {
      expect(mapCalendarDateExceptionRef(null), isNull);
    });

    test('maps safe projection', () {
      final ref = mapCalendarDateExceptionRef(validDateExceptionRefRpc());
      expect(ref, isNotNull);
      expect(ref!.kind, CalendarWorkingDateExceptionKind.officialHoliday);
      expect(ref.titleAr, 'عيد');
      expect(ref.titleEn, 'Holiday');
    });

    test('rejects an unexpected id key (non-safe leak)', () {
      final raw = validDateExceptionRefRpc()..['id'] = 'x';
      expect(() => mapCalendarDateExceptionRef(raw), throwsA(_malformed()));
    });

    test('rejects an unexpected notes key (non-safe leak)', () {
      final raw = validDateExceptionRefRpc()..['notes'] = 'internal';
      expect(() => mapCalendarDateExceptionRef(raw), throwsA(_malformed()));
    });

    test('rejects unknown kind', () {
      final raw = validDateExceptionRefRpc()..['kind'] = 'bogus';
      expect(() => mapCalendarDateExceptionRef(raw), throwsA(_malformed()));
    });
  });

  group('mapWorkingDateException', () {
    test('maps a holiday row (day_mode/work window null)', () {
      final exception = mapWorkingDateException(validHolidayExceptionRpc());
      expect(exception.kind, CalendarWorkingDateExceptionKind.officialHoliday);
      expect(exception.dayMode, isNull);
      expect(exception.workStart, isNull);
      expect(exception.workEnd, isNull);
      expect(exception.status, CalendarWorkingDateExceptionStatus.active);
      expect(exception.version, 1);
      expect(exception.createdAt, isA<DateTime>());
      expect(exception.titleFallback('en'), 'Holiday');
      expect(exception.titleFallback('ar'), 'عيد');
    });

    test('maps an exceptional working day row (working_hours)', () {
      final exception = mapWorkingDateException(
        validExceptionalWorkingDayRpc(),
      );
      expect(
        exception.kind,
        CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
      );
      expect(exception.dayMode, TenantWorkingDayMode.workingHours);
      expect(exception.workStart, '09:00');
      expect(exception.workEnd, '13:00');
    });

    test('maps an exceptional working day row (24_hours)', () {
      final exception = mapWorkingDateException(
        validExceptionalWorkingDayRpc(
          dayMode: '24_hours',
          workStart: null,
          workEnd: null,
        ),
      );
      expect(exception.dayMode, TenantWorkingDayMode.hours24);
      expect(exception.workStart, isNull);
      expect(exception.workEnd, isNull);
    });

    test('cancelled row maps cancel metadata', () {
      final exception = mapWorkingDateException(
        validHolidayExceptionRpc(
          status: 'cancelled',
          version: 2,
          cancelReason: 'Owner correction',
          cancelledAt: '2026-07-05T10:00:00+00:00',
          cancelledBy: 'cccccccc-0000-0000-0000-000000000001',
        ),
      );
      expect(exception.status, CalendarWorkingDateExceptionStatus.cancelled);
      expect(exception.isActive, isFalse);
      expect(exception.cancelReason, 'Owner correction');
      expect(exception.cancelledAt, isA<DateTime>());
    });

    test('holiday with a non-null day_mode is malformed', () {
      final raw = validHolidayExceptionRpc()..['day_mode'] = 'working_hours';
      expect(() => mapWorkingDateException(raw), throwsA(_malformed()));
    });

    test('holiday with a non-null work_start is malformed', () {
      final raw = validHolidayExceptionRpc()..['work_start'] = '08:00';
      expect(() => mapWorkingDateException(raw), throwsA(_malformed()));
    });

    test('exceptional working day without day_mode is malformed', () {
      final raw = validExceptionalWorkingDayRpc()..['day_mode'] = null;
      expect(() => mapWorkingDateException(raw), throwsA(_malformed()));
    });

    test('exceptional working_hours without work_start is malformed', () {
      final raw = validExceptionalWorkingDayRpc()..['work_start'] = null;
      expect(() => mapWorkingDateException(raw), throwsA(_malformed()));
    });

    test('exceptional 24_hours with a work_start is malformed', () {
      final raw = validExceptionalWorkingDayRpc(
        dayMode: '24_hours',
        workStart: null,
        workEnd: null,
      )..['work_start'] = '08:00';
      expect(() => mapWorkingDateException(raw), throwsA(_malformed()));
    });

    test('unknown day_mode value is malformed', () {
      final raw = validExceptionalWorkingDayRpc()..['day_mode'] = 'day_off';
      expect(() => mapWorkingDateException(raw), throwsA(_malformed()));
    });

    test('end_date before start_date is malformed', () {
      final raw = validHolidayExceptionRpc(
        startDate: '2026-08-05',
        endDate: '2026-08-01',
      );
      expect(() => mapWorkingDateException(raw), throwsA(_malformed()));
    });

    test('missing id is malformed', () {
      final raw = validHolidayExceptionRpc()..remove('id');
      expect(() => mapWorkingDateException(raw), throwsA(_malformed()));
    });
  });

  group('mapGetWorkingDateExceptionResult', () {
    test('maps the direct DTO (no status/exception wrapper)', () {
      final exception = mapGetWorkingDateExceptionResult(
        validHolidayExceptionRpc(),
      );
      expect(exception.kind, CalendarWorkingDateExceptionKind.officialHoliday);
    });
  });

  group('mapWorkingDateExceptionMutationResult', () {
    test('maps the shared ok/exception shape', () {
      final exception = mapWorkingDateExceptionMutationResult(
        okMutationResultRpc(),
        'create_working_date_exception',
      );
      expect(exception.kind, CalendarWorkingDateExceptionKind.officialHoliday);
    });

    test('unexpected status is malformed', () {
      final raw = okMutationResultRpc()..['status'] = 'weird';
      expect(
        () => mapWorkingDateExceptionMutationResult(raw, 'create'),
        throwsA(_malformed()),
      );
    });
  });

  group('mapWorkingDateExceptionListFromRpc', () {
    test('maps items, pagination, and filters_applied', () {
      final result = mapWorkingDateExceptionListFromRpc(
        validExceptionListRpc(
          items: [
            validHolidayExceptionRpc(id: 'a'),
            validExceptionalWorkingDayRpc(id: 'b'),
          ],
          hasMore: true,
          nextCursor: 'cursor-1',
          kind: null,
        ),
      );
      expect(result.items.map((e) => e.id).toList(), ['a', 'b']);
      expect(result.hasMore, isTrue);
      expect(result.nextCursor, 'cursor-1');
      expect(
        result.filtersApplied.status,
        CalendarWorkingDateExceptionStatusFilter.active,
      );
      expect(result.filtersApplied.kind, isNull);
      expect(result.filtersApplied.limit, 50);
      expect(result.filtersHash, 'hash-wde');
    });

    test('maps a kind filter when present', () {
      final result = mapWorkingDateExceptionListFromRpc(
        validExceptionListRpc(kind: 'company_closure'),
      );
      expect(
        result.filtersApplied.kind,
        CalendarWorkingDateExceptionKind.companyClosure,
      );
    });

    test('missing items key is malformed', () {
      final raw = validExceptionListRpc()..remove('items');
      expect(
        () => mapWorkingDateExceptionListFromRpc(raw),
        throwsA(_malformed()),
      );
    });
  });
}
