import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_manual_mutation.dart';
import 'package:hs360/features/calendar/domain/calendar_mutation_validators.dart';
import 'package:hs360/features/calendar/domain/calendar_schedule_mutation.dart';

void main() {
  group('CalendarAssignmentData', () {
    test('always includes assigned_agent_id, even when null (unassign)', () {
      expect(const CalendarAssignmentData().toRpcPayload(), {
        'assigned_agent_id': null,
      });
      expect(
        const CalendarAssignmentData(
          assignedAgentId: '11111111-1111-1111-1111-111111111111',
        ).toRpcPayload(),
        {'assigned_agent_id': '11111111-1111-1111-1111-111111111111'},
      );
    });
  });

  group('CalendarRescheduleData', () {
    test('payload carries date-only string and trimmed reason', () {
      final payload = CalendarRescheduleData(
        scheduledDate: DateTime(2026, 8, 3),
        reason: '  moved by customer  ',
      ).toRpcPayload();
      expect(payload, {
        'scheduled_date': '2026-08-03',
        'reason': 'moved by customer',
      });
    });

    test('acknowledgements nest unhashed like M7A', () {
      final payload = CalendarRescheduleData(
        scheduledDate: DateTime(2026, 8, 3),
        reason: 'x',
        acknowledgements: const CalendarManualAcknowledgements(
          acknowledgeNonWorkingDay: true,
          acknowledgeOverlap: true,
          dayOffOverrideReason: 'urgent delivery',
        ),
      ).toRpcPayload();
      expect(payload['acknowledgements'], {
        'acknowledge_overlap': true,
        'acknowledge_non_working_day': true,
        'day_off_override_reason': 'urgent delivery',
      });
    });

    test('copyWith replaces only acknowledgements', () {
      final original = CalendarRescheduleData(
        scheduledDate: DateTime(2026, 8, 3),
        reason: 'r',
      );
      final next = original.copyWith(
        acknowledgements: const CalendarManualAcknowledgements(
          acknowledgeScheduleUnconfigured: true,
        ),
      );
      expect(next.scheduledDate, original.scheduledDate);
      expect(next.reason, original.reason);
      expect(next.acknowledgements.acknowledgeScheduleUnconfigured, isTrue);
    });
  });

  group('validateRescheduleReason', () {
    test('requires a non-empty reason', () {
      expect(CalendarMutationValidators.validateRescheduleReason(null).codes, [
        CalendarMutationValidators.rescheduleReasonRequired,
      ]);
      expect(CalendarMutationValidators.validateRescheduleReason('   ').codes, [
        CalendarMutationValidators.rescheduleReasonRequired,
      ]);
    });

    test('caps the reason at 1000 characters', () {
      expect(
        CalendarMutationValidators.validateRescheduleReason('a' * 1000).isValid,
        isTrue,
      );
      expect(
        CalendarMutationValidators.validateRescheduleReason('a' * 1001).codes,
        [CalendarMutationValidators.rescheduleReasonTooLong],
      );
    });
  });

  group('existing schedule mutation validators stay intact', () {
    test('validateAssignmentAgentId accepts null and UUIDs only', () {
      expect(
        CalendarMutationValidators.validateAssignmentAgentId(null).isValid,
        isTrue,
      );
      expect(
        CalendarMutationValidators.validateAssignmentAgentId(
          '11111111-1111-1111-1111-111111111111',
        ).isValid,
        isTrue,
      );
      expect(
        CalendarMutationValidators.validateAssignmentAgentId('nope').codes,
        [CalendarMutationValidators.agentIdInvalid],
      );
    });

    test('validateRescheduleTargetDate rejects invalid dates', () {
      expect(
        CalendarMutationValidators.validateRescheduleTargetDate(
          '2026-08-03',
        ).isValid,
        isTrue,
      );
      expect(
        CalendarMutationValidators.validateRescheduleTargetDate('').codes,
        [CalendarMutationValidators.dateRequired],
      );
      expect(
        CalendarMutationValidators.validateRescheduleTargetDate(
          '2026-13-99',
        ).codes,
        [CalendarMutationValidators.dateInvalid],
      );
    });
  });
}
