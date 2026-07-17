import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_manual_mutation_mapper.dart';
import 'package:hs360/features/calendar/data/calendar_schedule_mutation_mapper.dart';
import 'package:hs360/features/calendar/domain/calendar_schedule_mutation.dart';

import 'calendar_read_fixtures.dart';

void main() {
  group('mapCalendarScheduleMutationResult', () {
    test('maps ok with changed=true', () {
      final result = mapCalendarScheduleMutationResult(
        validScheduleMutationOkRpc(),
      );
      expect(result, isA<CalendarScheduleMutationOk>());
      final ok = result as CalendarScheduleMutationOk;
      expect(ok.changed, isTrue);
      expect(ok.event.id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
    });

    test('maps ok with changed=false (ledgered no-op)', () {
      final result = mapCalendarScheduleMutationResult(
        validScheduleMutationOkRpc(changed: false),
      );
      expect((result as CalendarScheduleMutationOk).changed, isFalse);
    });

    test('maps confirmation_required conflicts (M7A shape)', () {
      final result = mapCalendarScheduleMutationResult({
        'status': 'confirmation_required',
        'code': 'calendar_conflict_confirmation_required',
        'conflicts': {
          'schedule_warnings': [
            {'code': 'non_working_day'},
          ],
          'overlap_warnings': [
            {'employee_id': 'emp-1'},
          ],
          'overlap_total_count': 1,
        },
      });
      expect(result, isA<CalendarScheduleMutationConfirmationRequired>());
      final confirm = result as CalendarScheduleMutationConfirmationRequired;
      expect(
        confirm.conflicts.scheduleWarnings.single['code'],
        'non_working_day',
      );
      expect(confirm.conflicts.overlapTotalCount, 1);
    });

    test('rejects missing changed flag', () {
      final raw = validScheduleMutationOkRpc()..remove('changed');
      expect(
        () => mapCalendarScheduleMutationResult(raw),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.malformedResponse,
          ),
        ),
      );
    });

    test('rejects unexpected status', () {
      expect(
        () => mapCalendarScheduleMutationResult({'status': 'nope'}),
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

  group('mapParticipantCandidates (M8 flags)', () {
    test('maps reachability flags strictly', () {
      final rows = mapParticipantCandidates({
        'rows': [
          validParticipantCandidateRpc(
            hasAppAccount: true,
            hasActiveTenantAccount: false,
            hasCalendarAccess: false,
          ),
        ],
      });
      final candidate = rows.single;
      expect(candidate.hasAppAccount, isTrue);
      expect(candidate.hasActiveTenantAccount, isFalse);
      expect(candidate.hasCalendarAccess, isFalse);
    });

    test('rejects rows without the new flags', () {
      final row = validParticipantCandidateRpc()..remove('has_calendar_access');
      expect(
        () => mapParticipantCandidates({
          'rows': [row],
        }),
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

  group('CalendarException.fromSupabase (M8 codes)', () {
    test('maps calendar_assignment_not_applicable', () {
      final mapped = CalendarException.fromSupabase(
        Exception('calendar_assignment_not_applicable'),
      );
      expect(mapped.code, CalendarException.assignmentNotApplicable);
    });
  });
}
