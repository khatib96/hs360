import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_event_list_rpc_mapper.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';

import 'calendar_read_fixtures.dart';

Matcher _malformed() => isA<CalendarException>().having(
  (e) => e.code,
  'code',
  CalendarException.malformedResponse,
);

void main() {
  group('mapCalendarEventListFromRpc', () {
    test('maps valid list with null execution_summary', () {
      final result = mapCalendarEventListFromRpc(
        validEventListRpc(
          inRangeRows: [validCalendarEventRpc(executionSummary: null)],
          overdueRows: const [],
          hasMoreOverdue: false,
          nextCursorOverdue: null,
        ),
      );

      expect(result.dateFrom, DateTime(2026, 7, 14));
      expect(result.dateTo, DateTime(2026, 7, 14));
      expect(result.limit, 50);
      expect(result.scope, CalendarReadScope.tenantWide);
      expect(result.inRange.rows, hasLength(1));
      expect(result.inRange.rows.single.executionSummary, isNull);
    });

    test('maps real execution_summary with Decimal quantities', () {
      final result = mapCalendarEventListFromRpc(
        validEventListRpc(
          inRangeRows: [
            validCalendarEventRpc(
              executionSummary: validExecutionSummaryRpc(
                actualQuantityDelivered: 12.5,
                contractedQuantityPerCycle: '10.00',
              ),
            ),
          ],
          overdueRows: const [],
          hasMoreOverdue: false,
          nextCursorOverdue: null,
        ),
      );

      final summary = result.inRange.rows.single.executionSummary!;
      expect(summary.actualCompletionDate, DateTime(2026, 7, 10));
      expect(summary.actualQuantityDelivered, Decimal.parse('12.5'));
      expect(summary.quantityUnit, 'cylinder');
      expect(summary.contractedQuantityPerCycle, Decimal.parse('10.00'));
      expect(summary.nextDueOverridden, isTrue);
      expect(summary.confirmedNextDueDate, DateTime(2026, 8, 12));
    });

    test('maps unconfigured event working_day and schedule_state', () {
      final result = mapCalendarEventListFromRpc(
        validEventListRpc(
          inRangeRows: [unconfiguredCalendarEventRpc()],
          overdueRows: const [],
          hasMoreOverdue: false,
          nextCursorOverdue: null,
        ),
      );

      final event = result.inRange.rows.single;
      expect(event.scheduleState, CalendarScheduleState.scheduleUnconfigured);
      expect(event.workingDay.dayMode, TenantWorkingDayMode.unreviewed);
      expect(event.workingDay.scheduleConfigured, isFalse);
    });

    test('missing event.original_due_date → malformed', () {
      final event = validCalendarEventRpc()..remove('original_due_date');
      expect(
        () => mapCalendarEventListFromRpc(
          validEventListRpc(inRangeRows: [event], overdueRows: const []),
        ),
        throwsA(_malformed()),
      );
    });

    test('maps absent optional linked fields', () {
      final result = mapCalendarEventListFromRpc(
        validEventListRpc(
          inRangeRows: [validCalendarEventAbsentOptionalRpc()],
          overdueRows: const [],
          hasMoreOverdue: false,
          nextCursorOverdue: null,
        ),
      );

      final event = result.inRange.rows.single;
      expect(event.customerId, isNull);
      expect(event.contractId, isNull);
      expect(event.assignedAgentId, isNull);
      expect(event.serviceLocationId, isNull);
    });

    test('keeps independent cursors and has_more per bucket', () {
      final result = mapCalendarEventListFromRpc(
        validEventListRpc(
          nextCursorInRange: 'in-cursor',
          nextCursorOverdue: 'od-cursor',
          hasMoreInRange: true,
          hasMoreOverdue: false,
        ),
      );

      expect(result.inRange.nextCursor, 'in-cursor');
      expect(result.inRange.hasMore, isTrue);
      expect(result.overdueOutsideRange.nextCursor, 'od-cursor');
      expect(result.overdueOutsideRange.hasMore, isFalse);
      expect(result.inRange.rows, hasLength(1));
      expect(result.overdueOutsideRange.rows, hasLength(1));
    });

    test('throws malformedResponse when execution_summary key missing', () {
      final event = validCalendarEventRpc()..remove('execution_summary');
      expect(
        () => mapCalendarEventListFromRpc(
          validEventListRpc(inRangeRows: [event], overdueRows: const []),
        ),
        throwsA(_malformed()),
      );
    });

    test('throws malformedResponse for unknown enum', () {
      expect(
        () => mapCalendarEventListFromRpc(
          validEventListRpc(
            inRangeRows: [validCalendarEventRpc(type: 'not_a_type')],
            overdueRows: const [],
          ),
        ),
        throwsA(_malformed()),
      );
    });

    test('throws malformedResponse for invalid date', () {
      expect(
        () => mapCalendarEventListFromRpc(
          validEventListRpc(
            inRangeRows: [validCalendarEventRpc(scheduledDate: '2026-02-30')],
            overdueRows: const [],
          ),
        ),
        throwsA(_malformed()),
      );
    });

    test('throws malformedResponse for invalid numeric qty', () {
      expect(
        () => mapCalendarEventListFromRpc(
          validEventListRpc(
            inRangeRows: [validCalendarEventRpc(qtyPerRefill: 'not-a-number')],
            overdueRows: const [],
          ),
        ),
        throwsA(_malformed()),
      );
    });
  });
}
