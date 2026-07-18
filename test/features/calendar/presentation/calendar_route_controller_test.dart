import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_route_employee.dart';
import 'package:hs360/features/calendar/presentation/calendar_route_controller.dart';
import 'package:hs360/features/calendar/presentation/calendar_route_state.dart';

import '../fake_calendar_repository.dart';
import '../fake_calendar_route_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  AppSession? _session;

  @override
  FutureOr<AppSession?> build() => _session;

  void setSession(AppSession? session) {
    _session = session;
    state = AsyncData(session);
  }
}

AppSession _session({
  Set<String> permissions = const {'calendar.view_assigned'},
  String accountType = 'user',
  String userId = 'user-1',
  String tenantId = 'tenant-1',
}) {
  return AppSession(
    userId: userId,
    email: 'test@example.com',
    tenantId: tenantId,
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

ProviderContainer _container({
  required AppSession? session,
  required FakeCalendarRepository repo,
  _TestAuthController? auth,
}) {
  final authController = auth ?? _TestAuthController(session);
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => authController),
      calendarRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
}

void main() {
  group('CalendarRouteController assigned-only isolation', () {
    test('assigned-only session loads the day without an employee picker', () async {
      final repo = FakeCalendarRepository()
        ..routeDayResult = sampleRouteResult(employeeId: 'self-emp');
      final container = _container(
        session: _session(permissions: {'calendar.view_assigned'}),
        repo: repo,
      );
      addTearDown(container.dispose);

      await container
          .read(calendarRouteControllerProvider.notifier)
          .ensureInitialized(date: DateTime(2026, 7, 14));

      final state = container.read(calendarRouteControllerProvider);
      expect(state.isTenantWide, isFalse);
      expect(state.awaitingEmployeeSelection, isFalse);
      expect(state.points, hasLength(1));
      expect(repo.getRouteDayCount, 1);
      expect(repo.lastRouteDayEmployeeId, isNull);
      expect(repo.listRouteEmployeesCount, 0);
    });

    test('tenant-wide session waits for an explicit employee before loading the day', () async {
      final repo = FakeCalendarRepository();
      final container = _container(
        session: _session(permissions: {'calendar.view'}),
        repo: repo,
      );
      addTearDown(container.dispose);

      await container
          .read(calendarRouteControllerProvider.notifier)
          .ensureInitialized(date: DateTime(2026, 7, 14));

      final state = container.read(calendarRouteControllerProvider);
      expect(state.isTenantWide, isTrue);
      expect(state.awaitingEmployeeSelection, isTrue);
      expect(repo.getRouteDayCount, 0);
      expect(repo.listRouteEmployeesCount, 1);

      await container
          .read(calendarRouteControllerProvider.notifier)
          .selectEmployee('emp-5');

      expect(repo.getRouteDayCount, 1);
      expect(repo.lastRouteDayEmployeeId, 'emp-5');
      expect(
        container.read(calendarRouteControllerProvider).awaitingEmployeeSelection,
        isFalse,
      );
    });

    test('invalid ?date= is reported without touching the repository', () async {
      final repo = FakeCalendarRepository();
      final container = _container(
        session: _session(),
        repo: repo,
      );
      addTearDown(container.dispose);

      container.read(calendarRouteControllerProvider.notifier).reportInvalidDate();

      final state = container.read(calendarRouteControllerProvider);
      expect(state.dateInvalid, isTrue);
      expect(repo.getRouteDayCount, 0);
    });
  });

  group('CalendarRouteController stale-response protection', () {
    test('a slow first request does not clobber a faster later request', () async {
      final repo = FakeCalendarRepository();
      final container = _container(
        session: _session(permissions: {'calendar.view_assigned'}),
        repo: repo,
      );
      addTearDown(container.dispose);
      final notifier = container.read(calendarRouteControllerProvider.notifier);

      final hold = Completer<void>();
      repo.holdRouteDayUntil = hold;
      repo.routeDayResult = sampleRouteResult(
        date: DateTime(2026, 7, 1),
        points: [sampleRoutePoint(eventId: 'stale-event')],
      );

      final firstLoad = notifier.ensureInitialized(date: DateTime(2026, 7, 1));

      // Second selection completes before the first (held) request resolves.
      repo.holdRouteDayUntil = null;
      repo.routeDayResult = sampleRouteResult(
        date: DateTime(2026, 7, 2),
        points: [sampleRoutePoint(eventId: 'fresh-event')],
      );
      await notifier.selectDate(DateTime(2026, 7, 2));

      hold.complete();
      await firstLoad;

      final state = container.read(calendarRouteControllerProvider);
      expect(state.selectedDate, DateTime(2026, 7, 2));
      expect(state.points, hasLength(1));
      expect(state.points.single.event.id, 'fresh-event');
    });

    test('resets to a fresh state when the session logs out', () async {
      final repo = FakeCalendarRepository();
      final auth = _TestAuthController(
        _session(permissions: {'calendar.view_assigned'}),
      );
      final container = _container(
        session: null,
        repo: repo,
        auth: auth,
      );
      addTearDown(container.dispose);

      await container
          .read(calendarRouteControllerProvider.notifier)
          .ensureInitialized(date: DateTime(2026, 7, 14));
      expect(container.read(calendarRouteControllerProvider).points, isNotEmpty);

      auth.setSession(null);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(calendarRouteControllerProvider);
      expect(state.points, isEmpty);
      expect(state.hasLoadedDayOnce, isFalse);
    });
  });

  group('CalendarRouteController errors and tiles', () {
    test('day-load failure then retry succeeds; stale gen discarded', () async {
      final repo = FakeCalendarRepository()
        ..routeDayError =
            const CalendarException(code: CalendarException.unknown);
      final container = _container(
        session: _session(permissions: {'calendar.view_assigned'}),
        repo: repo,
      );
      addTearDown(container.dispose);
      final notifier = container.read(calendarRouteControllerProvider.notifier);

      await notifier.ensureInitialized(date: DateTime(2026, 7, 14));
      expect(
        container.read(calendarRouteControllerProvider).dayErrorCode,
        CalendarException.unknown,
      );

      repo.routeDayError = null;
      repo.routeDayResult = sampleRouteResult(
        date: DateTime(2026, 7, 14),
        points: [sampleRoutePoint(eventId: 'recovered')],
      );
      await notifier.refresh();

      final state = container.read(calendarRouteControllerProvider);
      expect(state.dayErrorCode, isNull);
      expect(state.points.single.event.id, 'recovered');
    });

    test('employees failure then retry succeeds', () async {
      final repo = FakeCalendarRepository()
        ..routeEmployeesError =
            const CalendarException(code: CalendarException.unknown)
        ..routeEmployeesResult = const CalendarRouteEmployeeListResult(
          employees: [
            CalendarRouteEmployee(
              employeeId: 'emp-9',
              nameAr: 'تسع',
              nameEn: 'Nine',
              isActive: true,
            ),
          ],
          hasMore: false,
        );
      final container = _container(
        session: _session(permissions: {'calendar.view'}),
        repo: repo,
      );
      addTearDown(container.dispose);
      final notifier = container.read(calendarRouteControllerProvider.notifier);

      await notifier.ensureInitialized(date: DateTime(2026, 7, 14));
      expect(
        container.read(calendarRouteControllerProvider).employeesErrorCode,
        CalendarException.unknown,
      );

      repo.routeEmployeesError = null;
      await notifier.loadEmployees();
      final state = container.read(calendarRouteControllerProvider);
      expect(state.employeesErrorCode, isNull);
      expect(state.employees.single.employeeId, 'emp-9');
    });

    test('retryTiles clears failure and bumps session id', () {
      final repo = FakeCalendarRepository();
      final container = _container(
        session: _session(permissions: {'calendar.view_assigned'}),
        repo: repo,
      );
      addTearDown(container.dispose);
      final notifier = container.read(calendarRouteControllerProvider.notifier);

      notifier.reportTileFailure();
      expect(
        container.read(calendarRouteControllerProvider).mapSurfaceState,
        CalendarRouteMapSurfaceState.tileFailure,
      );
      expect(container.read(calendarRouteControllerProvider).tileSessionId, 0);

      notifier.retryTiles();
      final state = container.read(calendarRouteControllerProvider);
      expect(state.mapSurfaceState, CalendarRouteMapSurfaceState.ok);
      expect(state.tileSessionId, 1);
    });

    test('loadDirectionsTarget does not launch and surfaces errors', () async {
      final repo = FakeCalendarRepository()
        ..directionsError =
            const CalendarException(code: CalendarException.unknown);
      final container = _container(
        session: _session(permissions: {'calendar.view_assigned'}),
        repo: repo,
      );
      addTearDown(container.dispose);
      final notifier = container.read(calendarRouteControllerProvider.notifier);

      final target = await notifier.loadDirectionsTarget('e1');
      expect(target, isNull);
      expect(
        container.read(calendarRouteControllerProvider).directionsErrorCode,
        CalendarException.unknown,
      );
      expect(repo.getEventDirectionsCount, 1);
    });
  });
}
