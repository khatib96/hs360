import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_route_scope.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';

import '../fake_calendar_repository.dart';

const _customerId = '11111111-1111-1111-1111-111111111111';
const _contractId = '22222222-2222-2222-2222-222222222222';

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
  Set<String> permissions = const {'calendar.view'},
  String userId = 'user-1',
  String tenantId = 'tenant-1',
  String tenantUserId = 'tu-1',
}) {
  return AppSession(
    userId: userId,
    email: 'test@example.com',
    tenantId: tenantId,
    tenantUserId: tenantUserId,
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
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

Future<void> _waitForIdle(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  for (var i = 0; i < 80; i++) {
    final state = container.read(calendarControllerProvider);
    if (!state.isLoadingSummary &&
        !state.isLoadingAgenda &&
        !state.isLoadingOverdue &&
        !state.isLoadingMoreInRange &&
        !state.isLoadingMoreOverdue) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('CalendarController stayed busy');
}

Future<void> _boot(ProviderContainer container) async {
  container.read(calendarControllerProvider);
  await container.read(calendarControllerProvider.notifier).ensureWeekStart(0);
  await _waitForIdle(container);
}

void main() {
  late CalendarClock previousClock;

  setUp(() {
    previousClock = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });

  tearDown(() {
    calendarClock = previousClock;
  });

  test(
    'applyRouteScope merges IDs into repo filters while state.filters stays clean',
    () async {
      final repo = FakeCalendarRepository();
      final container = _container(session: _session(), repo: repo);
      addTearDown(container.dispose);
      await _boot(container);

      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
        'contractId': _contractId,
      });
      await container
          .read(calendarControllerProvider.notifier)
          .applyRouteScope(scope);
      await _waitForIdle(container);

      final state = container.read(calendarControllerProvider);
      expect(state.routeScope.customerId, _customerId);
      expect(state.routeScope.contractId, _contractId);
      // Popover filters must never carry the scoped IDs.
      expect(state.filters.customerId, isNull);
      expect(state.filters.contractId, isNull);

      // The repository requests were merged at the load boundary.
      expect(repo.lastRangeFilters?.customerId, _customerId);
      expect(repo.lastRangeFilters?.contractId, _contractId);
      expect(repo.lastListFilters?.customerId, _customerId);
      expect(repo.lastListFilters?.contractId, _contractId);
    },
  );

  test('applyRouteScope with a date focuses and selects that date', () async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);
    await _boot(container);

    final scope = CalendarRouteScope.fromQueryParameters(const {
      'date': '2026-08-03',
    });
    await container
        .read(calendarControllerProvider.notifier)
        .applyRouteScope(scope);
    await _waitForIdle(container);

    final state = container.read(calendarControllerProvider);
    expect(state.selectedDate, DateTime(2026, 8, 3));
    expect(state.focusedMonth, DateTime(2026, 8));
    expect(state.hasExplicitSelectedDate, isTrue);
  });

  test('clearRouteScope drops the merged IDs from subsequent repo calls', () async {
    final repo = FakeCalendarRepository();
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);
    await _boot(container);

    final scope = CalendarRouteScope.fromQueryParameters(const {
      'customerId': _customerId,
    });
    await container
        .read(calendarControllerProvider.notifier)
        .applyRouteScope(scope);
    await _waitForIdle(container);
    expect(repo.lastRangeFilters?.customerId, _customerId);

    await container.read(calendarControllerProvider.notifier).clearRouteScope();
    await _waitForIdle(container);

    final state = container.read(calendarControllerProvider);
    expect(state.routeScope.isEmpty, isTrue);
    expect(repo.lastRangeFilters?.customerId, isNull);
    expect(repo.lastListFilters?.customerId, isNull);
  });

  test('an invalid scope is stored without any IDs and never reaches the repo', () async {
    final repo = FakeCalendarRepository();
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);
    await _boot(container);

    final scope = CalendarRouteScope.fromQueryParameters(const {
      'customerId': 'not-a-uuid',
    });
    await container
        .read(calendarControllerProvider.notifier)
        .applyRouteScope(scope);
    await _waitForIdle(container);

    final state = container.read(calendarControllerProvider);
    expect(state.routeScope.isInvalid, isTrue);
    expect(state.routeScopeInvalid, isTrue);
    expect(repo.lastRangeFilters?.customerId, isNull);
  });

  test('identity change (tenantUserId only) clears any active route scope', () async {
    final auth = _TestAuthController(_session(tenantUserId: 'tu-1'));
    final repo = FakeCalendarRepository();
    final container = _container(
      session: _session(tenantUserId: 'tu-1'),
      repo: repo,
      auth: auth,
    );
    addTearDown(container.dispose);
    await _boot(container);

    final scope = CalendarRouteScope.fromQueryParameters(const {
      'customerId': _customerId,
    });
    await container
        .read(calendarControllerProvider.notifier)
        .applyRouteScope(scope);
    await _waitForIdle(container);
    expect(
      container.read(calendarControllerProvider).routeScope.isEmpty,
      isFalse,
    );

    // Same userId/tenantId, only tenantUserId changes (e.g. re-provisioned
    // membership row) — must still reset like any other identity change.
    auth.setSession(_session(tenantUserId: 'tu-2'));
    await _waitForIdle(container);

    expect(
      container.read(calendarControllerProvider).routeScope.isEmpty,
      isTrue,
    );
  });

  test(
    'delayed response from a stale tenant does not write after switching tenants mid-scope',
    () async {
      final auth = _TestAuthController(_session(tenantId: 'tenant-a'));
      final holdSummary = Completer<void>();
      final holdAgenda = Completer<void>();
      final holdOverdue = Completer<void>();
      final repo =
          FakeCalendarRepository(
              listResult: sampleEventList(
                inRangeRows: [sampleCalendarEvent(id: 'tenant-a-event')],
                overdueRows: const [],
              ),
            )
            ..holdSummaryUntil = holdSummary
            ..holdAgendaUntil = holdAgenda
            ..holdOverdueUntil = holdOverdue;

      final container = _container(
        session: _session(tenantId: 'tenant-a'),
        repo: repo,
        auth: auth,
      );
      addTearDown(container.dispose);

      final bootFuture = container
          .read(calendarControllerProvider.notifier)
          .ensureWeekStart(0);
      await Future<void>.delayed(Duration.zero);

      final scope = CalendarRouteScope.fromQueryParameters(const {
        'customerId': _customerId,
      });
      final scopeFuture = container
          .read(calendarControllerProvider.notifier)
          .applyRouteScope(scope);
      await Future<void>.delayed(Duration.zero);
      // Scope is stored immediately; loads remain gated on the Completers.
      expect(
        container.read(calendarControllerProvider).routeScope.customerId,
        _customerId,
      );

      repo
        ..listResult = sampleEventList(
          inRangeRows: [sampleCalendarEvent(id: 'tenant-b-event')],
          overdueRows: const [],
        )
        ..holdSummaryUntil = null
        ..holdAgendaUntil = null
        ..holdOverdueUntil = null;

      auth.setSession(_session(tenantId: 'tenant-b', userId: 'user-b'));
      await Future<void>.delayed(Duration.zero);

      holdSummary.complete();
      holdAgenda.complete();
      holdOverdue.complete();
      await bootFuture;
      await scopeFuture;
      await _waitForIdle(container);

      final state = container.read(calendarControllerProvider);
      // Identity change clears the route scope and the stale tenant-a
      // response (with the tenant-a-scoped filters) never lands.
      expect(state.routeScope.isEmpty, isTrue);
      expect(state.agendaEvents.map((e) => e.id), ['tenant-b-event']);
      expect(
        state.agendaEvents.map((e) => e.id),
        isNot(contains('tenant-a-event')),
      );
    },
  );

  test('invalid route scope performs zero repository reads and clears rows', () async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        inRangeRows: [sampleCalendarEvent(id: 'should-not-appear')],
      ),
    );
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);
    await _boot(container);
    final beforeSummary = repo.getRangeSummaryCount;
    final beforeList = repo.listEventsCount;

    await container.read(calendarControllerProvider.notifier).applyRouteScope(
      CalendarRouteScope.fromQueryParameters(const {
        'customerId': 'not-a-uuid',
      }),
    );
    await _waitForIdle(container);

    final state = container.read(calendarControllerProvider);
    expect(state.routeScope.isInvalid, isTrue);
    expect(state.routeScope.showsBanner, isTrue);
    expect(state.days, isEmpty);
    expect(state.agendaEvents, isEmpty);
    expect(state.overdueEvents, isEmpty);
    expect(repo.getRangeSummaryCount, beforeSummary);
    expect(repo.listEventsCount, beforeList);
  });

  test('date-only scope focuses the day without entity banner state', () async {
    final repo = FakeCalendarRepository();
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);
    await _boot(container);

    await container.read(calendarControllerProvider.notifier).applyRouteScope(
      CalendarRouteScope.fromQueryParameters(const {'date': '2026-08-20'}),
    );
    await _waitForIdle(container);

    final state = container.read(calendarControllerProvider);
    expect(state.selectedDate, DateTime(2026, 8, 20));
    expect(state.focusedMonth, DateTime(2026, 8));
    expect(state.routeScope.hasEntityScope, isFalse);
    expect(state.routeScope.showsBanner, isFalse);
    expect(state.routeScope.date, DateTime(2026, 8, 20));
  });
}
