import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_schedule_mutation.dart';

import 'calendar_read_fixtures.dart';

AppSession _session({
  Set<String> permissions = const {'calendar.view', 'calendar.edit'},
  bool isManager = false,
}) {
  return AppSession(
    userId: 'user-1',
    email: 't@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: isManager ? 'manager' : 'user',
    displayName: 'User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: isManager, permissions: permissions),
  );
}

void main() {
  group('CalendarRepository.assignCalendarEvent', () {
    test('sends locked RPC contract', () async {
      late String name;
      late Map<String, dynamic> params;
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async {
          name = n;
          params = p;
          return validScheduleMutationOkRpc();
        },
      );

      final result = await repo.assignCalendarEvent(
        _session(),
        eventId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        expectedVersion: 3,
        data: const CalendarAssignmentData(
          assignedAgentId: '11111111-1111-1111-1111-111111111111',
        ),
        idempotencyKey: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      );

      expect(name, 'assign_calendar_event');
      expect(params['p_event_id'], 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      expect(params['p_expected_version'], 3);
      expect(params['p_data'], {
        'assigned_agent_id': '11111111-1111-1111-1111-111111111111',
      });
      expect(
        params['p_idempotency_key'],
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      );
      expect((result as CalendarScheduleMutationOk).changed, isTrue);
    });

    test('unassign sends explicit null agent key', () async {
      late Map<String, dynamic> params;
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async {
          params = p;
          return validScheduleMutationOkRpc();
        },
      );
      await repo.assignCalendarEvent(
        _session(),
        eventId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        expectedVersion: 1,
        data: const CalendarAssignmentData(),
        idempotencyKey: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      );
      final data = params['p_data'] as Map;
      expect(data.containsKey('assigned_agent_id'), isTrue);
      expect(data['assigned_agent_id'], isNull);
    });

    test('requires calendar.edit', () async {
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async => fail('must not invoke RPC'),
      );
      expect(
        () => repo.assignCalendarEvent(
          _session(permissions: const {'calendar.view'}),
          eventId: 'e',
          expectedVersion: 1,
          data: const CalendarAssignmentData(),
          idempotencyKey: 'k',
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.permissionDenied,
          ),
        ),
      );
    });

    test('rejects malformed agent id client-side', () async {
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async => fail('must not invoke RPC'),
      );
      expect(
        () => repo.assignCalendarEvent(
          _session(),
          eventId: 'e',
          expectedVersion: 1,
          data: const CalendarAssignmentData(assignedAgentId: 'not-a-uuid'),
          idempotencyKey: 'k',
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.validationFailed,
          ),
        ),
      );
    });

    test('maps calendar_assignment_not_applicable errors', () async {
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async =>
            throw Exception('calendar_assignment_not_applicable'),
      );
      expect(
        () => repo.assignCalendarEvent(
          _session(isManager: true, permissions: const {}),
          eventId: 'e',
          expectedVersion: 1,
          data: const CalendarAssignmentData(),
          idempotencyKey: 'k',
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.assignmentNotApplicable,
          ),
        ),
      );
    });
  });

  group('CalendarRepository.listParticipantCandidates', () {
    test('returns a frozen candidate list (mutation attempts throw)', () async {
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async => {
          'rows': [
            {
              'employee_id': '11111111-1111-1111-1111-111111111111',
              'name_ar': 'موظف',
              'name_en': 'Employee',
              'is_active': true,
              'has_app_account': true,
              'has_active_tenant_account': true,
              'has_calendar_access': true,
            },
          ],
        },
      );

      final candidates = await repo.listParticipantCandidates(_session());

      expect(candidates, hasLength(1));
      expect(() => candidates.removeAt(0), throwsUnsupportedError);
      expect(() => candidates.clear(), throwsUnsupportedError);
      expect(() => candidates.add(candidates.first), throwsUnsupportedError);
    });
  });

  group('CalendarRepository.rescheduleCalendarEvent', () {
    test('sends locked RPC contract with acknowledgements', () async {
      late String name;
      late Map<String, dynamic> params;
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async {
          name = n;
          params = p;
          return validScheduleMutationOkRpc();
        },
      );

      await repo.rescheduleCalendarEvent(
        _session(),
        eventId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        expectedVersion: 2,
        data: CalendarRescheduleData(
          scheduledDate: DateTime(2026, 8, 3),
          reason: 'customer request',
        ),
        idempotencyKey: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      );

      expect(name, 'reschedule_calendar_event');
      expect(params['p_expected_version'], 2);
      expect(params['p_data'], {
        'scheduled_date': '2026-08-03',
        'reason': 'customer request',
      });
    });

    test('rejects empty reason client-side', () async {
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async => fail('must not invoke RPC'),
      );
      expect(
        () => repo.rescheduleCalendarEvent(
          _session(),
          eventId: 'e',
          expectedVersion: 1,
          data: CalendarRescheduleData(
            scheduledDate: DateTime(2026, 8, 3),
            reason: '   ',
          ),
          idempotencyKey: 'k',
        ),
        throwsA(
          isA<CalendarException>().having(
            (e) => e.code,
            'code',
            CalendarException.validationFailed,
          ),
        ),
      );
    });

    test('soft confirmation_required maps to result type', () async {
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async => {
          'status': 'confirmation_required',
          'code': 'calendar_conflict_confirmation_required',
          'conflicts': {
            'schedule_warnings': [
              {'code': 'non_working_day'},
            ],
            'overlap_warnings': <Map<String, dynamic>>[],
            'overlap_total_count': 0,
          },
        },
      );
      final result = await repo.rescheduleCalendarEvent(
        _session(),
        eventId: 'e',
        expectedVersion: 1,
        data: CalendarRescheduleData(
          scheduledDate: DateTime(2026, 8, 3),
          reason: 'r',
        ),
        idempotencyKey: 'k',
      );
      expect(result, isA<CalendarScheduleMutationConfirmationRequired>());
    });

    test('maps stale_version errors', () async {
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async => throw Exception('stale_version'),
      );
      expect(
        () => repo.rescheduleCalendarEvent(
          _session(),
          eventId: 'e',
          expectedVersion: 1,
          data: CalendarRescheduleData(
            scheduledDate: DateTime(2026, 8, 3),
            reason: 'r',
          ),
          idempotencyKey: 'k',
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
  });
}
