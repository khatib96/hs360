import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_event_list_rpc_mapper.dart';
import 'package:hs360/features/calendar/data/calendar_manual_mutation_mapper.dart';
import 'package:hs360/features/calendar/data/calendar_read_rpc_parsers.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_manual_mutation.dart';
import 'package:hs360/features/calendar/domain/calendar_meeting_mode.dart';

import 'calendar_read_fixtures.dart';

Matcher _malformed() => isA<CalendarException>().having(
  (e) => e.code,
  'code',
  CalendarException.malformedResponse,
);

void main() {
  group('M7A event parsing', () {
    test('maps time_window and participants', () {
      final event = mapCalendarEvent(
        validCalendarEventRpc(
          type: 'internal_meeting',
          sourceKind: 'manual',
          timeWindow: {
            'start_local': '09:00',
            'end_local': '10:30',
            'timezone_name': 'Asia/Kuwait',
          },
          participants: [
            {
              'employee_id': '11111111-1111-1111-1111-111111111111',
              'name_ar': 'موظف',
              'name_en': 'Employee',
              'is_active': true,
              'has_app_account': true,
            },
          ],
          meetingMode: 'online',
          meetingUrl: 'https://meet.example.com/x',
          scheduleVersion: 3,
        ),
      );

      expect(event.timeWindow?.startLocal, '09:00');
      expect(event.timeWindow?.endLocal, '10:30');
      expect(event.participants, hasLength(1));
      expect(event.participants.single.nameEn, 'Employee');
      expect(event.meetingMode, CalendarMeetingMode.online);
      expect(event.scheduleVersion, 3);
      expect(event.isTimed, isTrue);
    });

    test('requires time_window and participants keys', () {
      final missingTw = validCalendarEventRpc()..remove('time_window');
      expect(() => mapCalendarEvent(missingTw), throwsA(_malformed()));

      final missingParticipants = validCalendarEventRpc()
        ..remove('participants');
      expect(
        () => mapCalendarEvent(missingParticipants),
        throwsA(_malformed()),
      );
    });

    test('maps expanded available_actions', () {
      final actions = mapCalendarAvailableActions(
        validAvailableActionsRpc(
          canEditManual: true,
          canCancelManual: true,
          canMarkManualDone: true,
          canOpenMeetingLink: true,
        ),
      );
      expect(actions.canEditManual, isTrue);
      expect(actions.canCancelManual, isTrue);
      expect(actions.canMarkManualDone, isTrue);
      expect(actions.canOpenMeetingLink, isTrue);
    });

    test('list mapper preserves server order', () {
      final result = mapCalendarEventListFromRpc(
        validEventListRpc(
          inRangeRows: [
            validCalendarEventRpc(id: 'a', timeWindow: null),
            validCalendarEventRpc(
              id: 'b',
              timeWindow: {
                'start_local': '08:00',
                'end_local': '09:00',
                'timezone_name': 'Asia/Kuwait',
              },
            ),
          ],
          overdueRows: const [],
        ),
      );
      expect(result.inRange.rows.map((e) => e.id).toList(), ['a', 'b']);
    });
  });

  group('manual mutation mapper', () {
    test('maps confirmation_required soft result', () {
      final result = mapCalendarManualMutationResult({
        'status': 'confirmation_required',
        'code': 'calendar_conflict_confirmation_required',
        'conflicts': {
          'schedule_warnings': [
            {'code': 'non_working_day'},
          ],
          'overlap_warnings': <Map<String, dynamic>>[],
          'overlap_total_count': 2,
        },
      });
      expect(result, isA<CalendarManualMutationConfirmationRequired>());
      final conf = result as CalendarManualMutationConfirmationRequired;
      expect(conf.conflicts.overlapTotalCount, 2);
    });

    test('maps ok result with event', () {
      final result = mapCalendarManualMutationResult({
        'status': 'ok',
        'event': validCalendarEventRpc(sourceKind: 'manual'),
      });
      expect(result, isA<CalendarManualMutationOk>());
      expect(
        (result as CalendarManualMutationOk).event.sourceKind,
        CalendarEventSourceKind.manual,
      );
    });
  });

  group('available_actions gating shape', () {
    test('defaults deny mutative actions', () {
      const actions = CalendarAvailableActions(
        canViewCustomer: false,
        canViewContract: false,
        canAssign: false,
        canReschedule: false,
        canCreateManual: false,
        canOpenDirections: false,
        canEditManual: false,
        canCancelManual: false,
        canMarkManualDone: false,
        canOpenMeetingLink: false,
      );
      expect(actions.canEditManual, isFalse);
      expect(actions.canOpenMeetingLink, isFalse);
    });
  });
}
