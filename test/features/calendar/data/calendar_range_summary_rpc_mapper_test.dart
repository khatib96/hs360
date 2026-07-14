import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_range_summary_rpc_mapper.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';

import 'calendar_read_fixtures.dart';

void main() {
  group('mapCalendarRangeSummaryFromRpc', () {
    test('maps complete valid tenant-wide response', () {
      final result = mapCalendarRangeSummaryFromRpc(validRangeSummaryRpc());

      expect(result.dateFrom, DateTime(2026, 7, 1));
      expect(result.dateTo, DateTime(2026, 7, 31));
      expect(result.timezoneName, 'Asia/Kuwait');
      expect(result.workingScheduleConfigured, isTrue);
      expect(result.tenantLocalToday, DateTime(2026, 7, 14));
      expect(result.scope, CalendarReadScope.tenantWide);
      expect(result.filtersHash, 'hash-abc');
      expect(result.days, hasLength(1));
      expect(result.days.first.unassignedCount, 2);
      expect(result.days.first.eventCount, 3);
      expect(
        result.days.first.workingDay.dayMode,
        TenantWorkingDayMode.workingHours,
      );
      expect(
        result.overdueOutsideRange.state,
        CalendarOverdueOutsideRangeState.available,
      );
      expect(result.overdueOutsideRange.count, 1);
    });

    test('maps assigned-only null unassigned_count', () {
      final result = mapCalendarRangeSummaryFromRpc(
        validAssignedOnlyRangeSummaryRpc(),
      );

      expect(result.scope, CalendarReadScope.assignedOnly);
      expect(result.days.first.unassignedCount, isNull);
    });

    test('maps schedule_unconfigured overdue summary', () {
      final result = mapCalendarRangeSummaryFromRpc(
        scheduleUnconfiguredRangeSummaryRpc(),
      );

      expect(result.workingScheduleConfigured, isFalse);
      expect(
        result.overdueOutsideRange.state,
        CalendarOverdueOutsideRangeState.scheduleUnconfigured,
      );
      expect(result.overdueOutsideRange.count, isNull);
      expect(result.overdueOutsideRange.oldestOriginalDueDate, isNull);
    });

    test('maps unconfigured range summary with setup-relevant fields', () {
      final result = mapCalendarRangeSummaryFromRpc(
        unconfiguredRangeSummaryRpc(),
      );

      expect(result.workingScheduleConfigured, isFalse);
      expect(result.tenantLocalToday, isNull);
      expect(
        result.overdueOutsideRange.state,
        CalendarOverdueOutsideRangeState.scheduleUnconfigured,
      );
      expect(
        result.days.first.workingDay.dayMode,
        TenantWorkingDayMode.unreviewed,
      );
      expect(result.days.first.workingDay.scheduleConfigured, isFalse);
      expect(result.days.first.workingDay.isUnreviewed, isTrue);
    });

    test('throws malformedResponse for missing days', () {
      final raw = validRangeSummaryRpc()..remove('days');
      expect(
        () => mapCalendarRangeSummaryFromRpc(raw),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.malformedResponse,
          ),
        ),
      );
    });

    test('throws malformedResponse for invalid dates', () {
      final raw = validRangeSummaryRpc()..['date_from'] = '2026-02-30';
      expect(
        () => mapCalendarRangeSummaryFromRpc(raw),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.malformedResponse,
          ),
        ),
      );
    });

    test('throws malformedResponse for unknown scope', () {
      final raw = validRangeSummaryRpc()..['scope'] = 'everyone';
      expect(
        () => mapCalendarRangeSummaryFromRpc(raw),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.malformedResponse,
          ),
        ),
      );
    });

    test('throws malformedResponse for bad working_day day_mode', () {
      final raw = validRangeSummaryRpc();
      final days = List<Map<String, dynamic>>.from(
        (raw['days'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      days[0]['working_day'] = validWorkingDayRpc(dayMode: 'not_a_mode');
      raw['days'] = days;

      expect(
        () => mapCalendarRangeSummaryFromRpc(raw),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.malformedResponse,
          ),
        ),
      );
    });
  });
}
