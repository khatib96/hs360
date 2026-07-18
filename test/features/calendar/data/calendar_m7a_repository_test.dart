import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_manual_mutation.dart';

import 'calendar_read_fixtures.dart';

AppSession _session() {
  return AppSession(
    userId: 'user-1',
    email: 't@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'manager',
    displayName: 'Mgr',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: true, permissions: {}),
  );
}

void main() {
  group('CalendarRepository M7A RPCs', () {
    test('create_manual_calendar_event contract', () async {
      late String name;
      late Map<String, dynamic> params;
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async {
          name = n;
          params = p;
          return {
            'status': 'ok',
            'event': validCalendarEventRpc(sourceKind: 'manual'),
          };
        },
      );

      final result = await repo.createManualEvent(
        _session(),
        data: CalendarManualEventData(
          type: CalendarEventType.internalTask,
          scheduledDate: DateTime(2026, 7, 15),
          titleAr: 'مهمة',
        ),
        idempotencyKey: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      );

      expect(name, 'create_manual_calendar_event');
      expect(
        params['p_idempotency_key'],
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      );
      expect((params['p_data'] as Map)['type'], 'internal_task');
      expect(result, isA<CalendarManualMutationOk>());
    });

    test('update/cancel/mark_done/participants contracts', () async {
      final calls = <String>[];
      final repo = CalendarRepository(
        null,
        rpcInvoker: (n, p) async {
          calls.add(n);
          if (n == 'list_calendar_participant_candidates') {
            return {
              'rows': [
                {
                  'employee_id': '11111111-1111-1111-1111-111111111111',
                  'name_ar': 'أ',
                  'name_en': 'A',
                  'is_active': true,
                  'has_app_account': false,
                  'has_active_tenant_account': true,
                  'has_calendar_access': true,
                },
              ],
            };
          }
          return {
            'status': 'ok',
            'event': validCalendarEventRpc(sourceKind: 'manual'),
          };
        },
      );

      await repo.updateManualEvent(
        _session(),
        eventId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        expectedVersion: 2,
        data: CalendarManualEventData(
          type: CalendarEventType.custom,
          scheduledDate: DateTime(2026, 7, 15),
          titleAr: 'مخصص',
        ),
        idempotencyKey: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      );
      await repo.cancelManualEvent(
        _session(),
        eventId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        expectedVersion: 2,
        reason: 'Changed plans',
        idempotencyKey: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      );
      await repo.markManualEventDone(
        _session(),
        eventId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        expectedVersion: 2,
        idempotencyKey: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      );
      final candidates = await repo.listParticipantCandidates(
        _session(),
        search: 'a',
      );

      expect(calls, [
        'update_manual_calendar_event',
        'cancel_manual_calendar_event',
        'mark_manual_event_done',
        'list_calendar_participant_candidates',
      ]);
      expect(candidates, hasLength(1));
    });

    test('maps stale_version from supabase errors', () {
      final mapped = CalendarException.fromSupabase(Exception('stale_version'));
      expect(mapped.code, CalendarException.staleVersion);
    });
  });
}
