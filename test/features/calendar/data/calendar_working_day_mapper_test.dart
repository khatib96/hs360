import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_read_rpc_parsers.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';

import 'calendar_read_fixtures.dart';

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
}
