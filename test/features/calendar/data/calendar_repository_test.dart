import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';

import '../fake_calendar_repository.dart';
import 'calendar_read_fixtures.dart';

AppSession _session({
  Set<String> permissions = const {},
  String accountType = 'user',
}) {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: accountType,
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: accountType == 'manager',
      permissions: permissions,
    ),
  );
}

void main() {
  group('CalendarRepository permissions and validation', () {
    test('permission denied before client when no calendar access', () async {
      final repo = CalendarRepository(null);
      await expectLater(
        repo.getRangeSummary(
          _session(),
          dateFrom: DateTime(2026, 7, 1),
          dateTo: DateTime(2026, 7, 31),
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

    test(
      'assigned-only assigned_agent_id fails validation before client',
      () async {
        final repo = CalendarRepository(null);
        await expectLater(
          repo.listEvents(
            _session(permissions: {'calendar.view_assigned'}),
            dateFrom: DateTime(2026, 7, 14),
            dateTo: DateTime(2026, 7, 14),
            filters: CalendarFilters(assignedAgentId: 'agent-1'),
          ),
          throwsA(
            isA<CalendarException>().having(
              (e) => e.code,
              'code',
              CalendarException.validationFailed,
            ),
          ),
        );
      },
    );

    test(
      'supabaseNotConfigured after permission ok with null client',
      () async {
        final repo = CalendarRepository(null);
        await expectLater(
          repo.getRangeSummary(
            _session(permissions: {'calendar.view'}),
            dateFrom: DateTime(2026, 7, 1),
            dateTo: DateTime(2026, 7, 31),
          ),
          throwsA(
            isA<CalendarException>().having(
              (e) => e.code,
              'code',
              CalendarException.supabaseNotConfigured,
            ),
          ),
        );
      },
    );
  });

  group('CalendarRepository exact RPC contracts', () {
    test('get_calendar_range_summary name and parameter map', () async {
      String? capturedName;
      Map<String, dynamic>? capturedParams;

      final repo = CalendarRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedName = name;
          capturedParams = Map<String, dynamic>.from(params);
          return validRangeSummaryRpc();
        },
      );

      final filters = CalendarFilters(
        eventTypes: [CalendarEventType.refillDue],
        overdueOnly: true,
        search: 'ab',
      );

      await repo.getRangeSummary(
        _session(permissions: {'calendar.view'}),
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 31),
        filters: filters,
      );

      expect(capturedName, 'get_calendar_range_summary');
      expect(capturedParams, {
        'p_date_from': '2026-07-01',
        'p_date_to': '2026-07-31',
        'p_filters': filters.toCanonicalPayload(),
      });
      expect(capturedParams!['p_filters'], {
        'event_types': ['refill_due'],
        'overdue_only': true,
        'search': 'ab',
      });
    });

    test('list_calendar_events name and full parameter map', () async {
      String? capturedName;
      Map<String, dynamic>? capturedParams;

      final repo = CalendarRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedName = name;
          capturedParams = Map<String, dynamic>.from(params);
          return validEventListRpc(limit: 25);
        },
      );

      final filters = CalendarFilters(
        statuses: [CalendarEventStatus.pending],
        customerId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      );

      await repo.listEvents(
        _session(permissions: {'calendar.view'}),
        dateFrom: DateTime(2026, 7, 14),
        dateTo: DateTime(2026, 7, 14),
        filters: filters,
        cursorInRange: 'cursor-in',
        cursorOverdue: 'cursor-od',
        limit: 25,
        includeOverdueOutsideRange: true,
      );

      expect(capturedName, 'list_calendar_events');
      expect(capturedParams, {
        'p_date_from': '2026-07-14',
        'p_date_to': '2026-07-14',
        'p_filters': {
          'statuses': ['pending'],
          'customer_id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
        },
        'p_cursor_in_range': 'cursor-in',
        'p_cursor_overdue': 'cursor-od',
        'p_limit': 25,
        'p_include_overdue_outside_range': true,
      });
    });

    test('list_calendar_events default limit is 50', () async {
      Map<String, dynamic>? capturedParams;
      final repo = CalendarRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedParams = Map<String, dynamic>.from(params);
          return validEventListRpc();
        },
      );

      await repo.listEvents(
        _session(permissions: {'calendar.view'}),
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 1),
      );

      expect(capturedParams!['p_limit'], 50);
      expect(capturedParams!['p_include_overdue_outside_range'], isFalse);
      expect(capturedParams!['p_cursor_in_range'], isNull);
      expect(capturedParams!['p_cursor_overdue'], isNull);
      expect(capturedParams!['p_filters'], isEmpty);
    });

    test('list_calendar_events clamps limit above 100 to 100', () async {
      Map<String, dynamic>? capturedParams;
      final repo = CalendarRepository(
        null,
        rpcInvoker: (name, params) async {
          capturedParams = Map<String, dynamic>.from(params);
          return validEventListRpc(limit: 100);
        },
      );

      await repo.listEvents(
        _session(permissions: {'calendar.view'}),
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 1),
        limit: 999,
      );

      expect(capturedParams!['p_limit'], 100);
    });
  });

  group('FakeCalendarRepository', () {
    test('manager can call getRangeSummary and listEvents', () async {
      final fake = FakeCalendarRepository();
      final session = _session(accountType: 'manager');

      await fake.getRangeSummary(
        session,
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 31),
      );
      await fake.listEvents(
        session,
        dateFrom: DateTime(2026, 7, 14),
        dateTo: DateTime(2026, 7, 14),
      );

      expect(fake.getRangeSummaryCount, 1);
      expect(fake.listEventsCount, 1);
      expect(fake.lastRangeFrom, DateTime(2026, 7, 1));
      expect(fake.lastListFrom, DateTime(2026, 7, 14));
    });

    test('calendar.view and view_assigned can call through fake', () async {
      final fake = FakeCalendarRepository();

      await fake.getRangeSummary(
        _session(permissions: {'calendar.view'}),
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 31),
      );
      await fake.listEvents(
        _session(permissions: {'calendar.view_assigned'}),
        dateFrom: DateTime(2026, 7, 14),
        dateTo: DateTime(2026, 7, 14),
        includeOverdueOutsideRange: true,
        cursorOverdue: 'od-1',
      );

      expect(fake.getRangeSummaryCount, 1);
      expect(fake.listEventsCount, 1);
      expect(fake.lastIncludeOverdue, isTrue);
      expect(fake.lastCursorOverdue, 'od-1');
    });

    test('records filters and cursors', () async {
      final fake = FakeCalendarRepository();
      final filters = CalendarFilters(unassignedOnly: true);

      await fake.listEvents(
        _session(permissions: {'calendar.view'}),
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 1),
        filters: filters,
        cursorInRange: 'in-1',
        limit: 25,
      );

      expect(fake.lastListFilters, same(filters));
      expect(fake.lastCursorInRange, 'in-1');
      expect(fake.lastLimit, 25);
    });
  });
}
