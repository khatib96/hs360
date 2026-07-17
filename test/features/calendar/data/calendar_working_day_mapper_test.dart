import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_read_rpc_parsers.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';

import 'calendar_read_fixtures.dart';
import 'calendar_working_date_exception_fixtures.dart';

Matcher _malformed() => isA<CalendarException>().having(
  (e) => e.code,
  'code',
  CalendarException.malformedResponse,
);

void main() {
  group('mapCalendarWorkingDay', () {
    test('unconfigured strip_nulls working day maps to unreviewed', () {
      final day = mapCalendarWorkingDay(unconfiguredWorkingDayRpc());

      expect(day.dayMode, TenantWorkingDayMode.unreviewed);
      expect(day.scheduleConfigured, isFalse);
      expect(day.isUnreviewed, isTrue);
      expect(day.isDayOff, isFalse);
      expect(day.is24Hours, isFalse);
      expect(day.isWorkingHours, isFalse);
      expect(day.workStart, isNull);
      expect(day.workEnd, isNull);
    });

    test('unconfigured without is_unreviewed still maps to unreviewed', () {
      final day = mapCalendarWorkingDay(
        unconfiguredWorkingDayRpc(includeIsUnreviewed: false),
      );
      expect(day.dayMode, TenantWorkingDayMode.unreviewed);
      expect(day.isUnreviewed, isTrue);
    });

    test('day_off maps OK', () {
      final day = mapCalendarWorkingDay(dayOffWorkingDayRpc());
      expect(day.dayMode, TenantWorkingDayMode.dayOff);
      expect(day.isDayOff, isTrue);
      expect(day.workStart, isNull);
    });

    test('working_hours maps OK', () {
      final day = mapCalendarWorkingDay(workingHoursWorkingDayRpc());
      expect(day.dayMode, TenantWorkingDayMode.workingHours);
      expect(day.isWorkingHours, isTrue);
      expect(day.workStart, '08:00');
      expect(day.workEnd, '17:00');
    });

    test('24_hours maps OK', () {
      final day = mapCalendarWorkingDay(hours24WorkingDayRpc());
      expect(day.dayMode, TenantWorkingDayMode.hours24);
      expect(day.is24Hours, isTrue);
      expect(day.workStart, isNull);
    });

    test('working_hours without work_start is malformed', () {
      final raw = workingHoursWorkingDayRpc()..remove('work_start');
      expect(() => mapCalendarWorkingDay(raw), throwsA(_malformed()));
    });

    test('day_off with work_start is malformed', () {
      final raw = dayOffWorkingDayRpc()..['work_start'] = '08:00';
      expect(() => mapCalendarWorkingDay(raw), throwsA(_malformed()));
    });

    test('day_off with is_working_hours true is malformed', () {
      final raw = dayOffWorkingDayRpc()..['is_working_hours'] = true;
      expect(() => mapCalendarWorkingDay(raw), throwsA(_malformed()));
    });
  });

  group('mapCalendarWorkingDay — M7B date_exception', () {
    test('absent date_exception key maps to null (no override)', () {
      final day = mapCalendarWorkingDay(workingHoursWorkingDayRpc());
      expect(day.dateException, isNull);
    });

    test('null date_exception value maps to null', () {
      final raw = workingHoursWorkingDayRpc()..['date_exception'] = null;
      final day = mapCalendarWorkingDay(raw);
      expect(day.dateException, isNull);
    });

    test('day_off resolved by an official_holiday exception', () {
      final raw = dayOffWorkingDayRpc()
        ..['date_exception'] = validDateExceptionRefRpc(
          kind: 'official_holiday',
          titleAr: 'عيد',
          titleEn: 'Holiday',
        );
      final day = mapCalendarWorkingDay(raw);
      expect(day.isDayOff, isTrue);
      expect(
        day.dateException!.kind,
        CalendarWorkingDateExceptionKind.officialHoliday,
      );
      expect(day.dateException!.titleEn, 'Holiday');
    });

    test('working_hours resolved by an exceptional_working_day exception', () {
      final raw =
          workingHoursWorkingDayRpc(workStart: '09:00', workEnd: '13:00')
            ..['date_exception'] = validDateExceptionRefRpc(
              kind: 'exceptional_working_day',
            );
      final day = mapCalendarWorkingDay(raw);
      expect(day.isWorkingHours, isTrue);
      expect(day.workStart, '09:00');
      expect(
        day.dateException!.kind,
        CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
      );
    });

    test('24_hours resolved by an exceptional_working_day exception', () {
      final raw = hours24WorkingDayRpc()
        ..['date_exception'] = validDateExceptionRefRpc(
          kind: 'exceptional_working_day',
        );
      final day = mapCalendarWorkingDay(raw);
      expect(day.is24Hours, isTrue);
      expect(
        day.dateException!.kind,
        CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
      );
    });

    test('unreviewed day_mode cannot carry an active date_exception', () {
      final raw = unconfiguredWorkingDayRpc()
        ..['date_exception'] = validDateExceptionRefRpc();
      expect(() => mapCalendarWorkingDay(raw), throwsA(_malformed()));
    });

    test(
      'company_closure exception resolving to working_hours is malformed',
      () {
        final raw = workingHoursWorkingDayRpc()
          ..['date_exception'] = validDateExceptionRefRpc(
            kind: 'company_closure',
          );
        expect(() => mapCalendarWorkingDay(raw), throwsA(_malformed()));
      },
    );

    test(
      'exceptional_working_day exception resolving to day_off is malformed',
      () {
        final raw = dayOffWorkingDayRpc()
          ..['date_exception'] = validDateExceptionRefRpc(
            kind: 'exceptional_working_day',
          );
        expect(() => mapCalendarWorkingDay(raw), throwsA(_malformed()));
      },
    );

    test('date_exception with a non-safe id key is malformed', () {
      final raw = dayOffWorkingDayRpc()
        ..['date_exception'] = (validDateExceptionRefRpc()..['id'] = 'x');
      expect(() => mapCalendarWorkingDay(raw), throwsA(_malformed()));
    });
  });
}
