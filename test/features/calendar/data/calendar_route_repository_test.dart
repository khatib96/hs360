import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';

import 'calendar_route_rpc_fixtures.dart';

AppSession _session({
  Set<String> permissions = const {},
  bool isManager = false,
}) {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: isManager ? 'manager' : 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: isManager, permissions: permissions),
  );
}

void main() {
  group('CalendarRepository Route View (M10) exact RPC contracts', () {
    test(
      'getRouteDay calls get_calendar_route_day with p_date/p_employee_id',
      () async {
        String? capturedName;
        Map<String, dynamic>? capturedParams;
        final repo = CalendarRepository(
          null,
          rpcInvoker: (name, params) async {
            capturedName = name;
            capturedParams = Map<String, dynamic>.from(params);
            return sampleRouteDayRpc();
          },
        );

        await repo.getRouteDay(
          _session(permissions: {'calendar.view_assigned'}),
          date: DateTime(2026, 7, 14),
          employeeId: 'emp-9',
        );

        expect(capturedName, 'get_calendar_route_day');
        expect(capturedParams, {
          'p_date': '2026-07-14',
          'p_employee_id': 'emp-9',
        });
      },
    );

    test(
      'getRouteDay omits employee_id (null) for assigned-only callers',
      () async {
        Map<String, dynamic>? capturedParams;
        final repo = CalendarRepository(
          null,
          rpcInvoker: (name, params) async {
            capturedParams = Map<String, dynamic>.from(params);
            return sampleRouteDayRpc();
          },
        );

        await repo.getRouteDay(
          _session(permissions: {'calendar.view_assigned'}),
          date: DateTime(2026, 7, 14),
        );

        expect(capturedParams!['p_employee_id'], isNull);
      },
    );

    test('getRouteDay rejects sessions without calendar access', () async {
      final repo = CalendarRepository(
        null,
        rpcInvoker: (name, params) async => sampleRouteDayRpc(),
      );

      await expectLater(
        repo.getRouteDay(_session(), date: DateTime(2026, 7, 14)),
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
      'listRouteEmployees calls list_calendar_route_employees with p_search/p_limit',
      () async {
        String? capturedName;
        Map<String, dynamic>? capturedParams;
        final repo = CalendarRepository(
          null,
          rpcInvoker: (name, params) async {
            capturedName = name;
            capturedParams = Map<String, dynamic>.from(params);
            return sampleRouteEmployeesRpc();
          },
        );

        await repo.listRouteEmployees(
          _session(permissions: {'calendar.view'}),
          search: 'ali',
          limit: 10,
        );

        expect(capturedName, 'list_calendar_route_employees');
        expect(capturedParams, {'p_search': 'ali', 'p_limit': 10});
      },
    );

    test(
      'listRouteEmployees rejects assigned-only sessions (no tenant-wide view)',
      () async {
        final repo = CalendarRepository(
          null,
          rpcInvoker: (name, params) async => sampleRouteEmployeesRpc(),
        );

        await expectLater(
          repo.listRouteEmployees(
            _session(permissions: {'calendar.view_assigned'}),
          ),
          throwsA(
            isA<CalendarException>().having(
              (e) => e.code,
              'code',
              CalendarException.permissionDenied,
            ),
          ),
        );
      },
    );

    test(
      'getEventDirections calls get_calendar_event_directions with p_event_id',
      () async {
        String? capturedName;
        Map<String, dynamic>? capturedParams;
        final repo = CalendarRepository(
          null,
          rpcInvoker: (name, params) async {
            capturedName = name;
            capturedParams = Map<String, dynamic>.from(params);
            return sampleDirectionsRpc();
          },
        );

        await repo.getEventDirections(
          _session(permissions: {'calendar.view_assigned'}),
          'event-42',
        );

        expect(capturedName, 'get_calendar_event_directions');
        expect(capturedParams, {'p_event_id': 'event-42'});
      },
    );
  });
}
