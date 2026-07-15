import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_agenda_grouping.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_meeting_mode.dart';
import 'package:hs360/features/calendar/domain/calendar_time_window.dart';

import '../fake_calendar_repository.dart';

void main() {
  group('CalendarEventType M7A', () {
    test('maps new manual types', () {
      expect(
        CalendarEventType.fromRpc('customer_visit'),
        CalendarEventType.customerVisit,
      );
      expect(
        CalendarEventType.fromRpc('internal_meeting'),
        CalendarEventType.internalMeeting,
      );
      expect(
        CalendarEventType.fromRpc('internal_task'),
        CalendarEventType.internalTask,
      );
      expect(
        CalendarEventType.fromRpc('internal_activity'),
        CalendarEventType.internalActivity,
      );
      expect(CalendarEventType.internalMeeting.rpcValue, 'internal_meeting');
      expect(CalendarEventType.manualCreatable, hasLength(5));
    });
  });

  group('CalendarMeetingMode', () {
    test('round-trips', () {
      for (final mode in CalendarMeetingMode.values) {
        expect(CalendarMeetingMode.fromRpc(mode.rpcValue), mode);
      }
      expect(CalendarMeetingMode.fromRpc('hybrid'), isNull);
    });
  });

  group('groupCalendarAgendaEvents', () {
    test('groups without re-sorting within sections', () {
      final timedA = sampleCalendarEvent(
        id: 't1',
        timeWindow: const CalendarTimeWindow(
          startLocal: '09:00',
          endLocal: '10:00',
          timezoneName: 'Asia/Kuwait',
        ),
      );
      final dayB = sampleCalendarEvent(id: 'd1');
      final timedC = sampleCalendarEvent(
        id: 't2',
        timeWindow: const CalendarTimeWindow(
          startLocal: '11:00',
          endLocal: '12:00',
          timezoneName: 'Asia/Kuwait',
        ),
      );
      final dayD = sampleCalendarEvent(id: 'd2');

      final groups = groupCalendarAgendaEvents([timedA, dayB, timedC, dayD]);
      expect(groups.timedAppointments.map((e) => e.id), ['t1', 't2']);
      expect(groups.dayTasks.map((e) => e.id), ['d1', 'd2']);
    });
  });
}
