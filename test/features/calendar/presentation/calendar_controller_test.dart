import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';

import '../fake_calendar_repository.dart';

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

/// Boots calendar with Sunday week start (Material index 0).
Future<void> _boot(ProviderContainer container) async {
  container.read(calendarControllerProvider);
  await container.read(calendarControllerProvider.notifier).ensureWeekStart(0);
  await _waitForIdle(container);
}

/// July 2026 padded range for Sunday week start.
final _july2026PaddedFrom = DateTime(2026, 6, 28);
final _july2026PaddedTo = DateTime(2026, 8, 1);

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
    'initial load uses padded month range and selected-day agenda',
    () async {
      final repo = FakeCalendarRepository(
        listResult: sampleEventList(
          inRangeRows: [sampleCalendarEvent(id: 'agenda-1')],
          overdueRows: [
            sampleCalendarEvent(
              id: 'overdue-1',
              scheduledDate: DateTime(2026, 6, 1),
            ),
          ],
          hasMoreInRange: true,
          nextCursorInRange: 'in-1',
          hasMoreOverdue: true,
          nextCursorOverdue: 'od-1',
        ),
      );
      final container = _container(session: _session(), repo: repo);
      addTearDown(container.dispose);

      await _boot(container);

      expect(repo.getRangeSummaryCount, 1);
      expect(repo.lastRangeFrom, _july2026PaddedFrom);
      expect(repo.lastRangeTo, _july2026PaddedTo);
      expect(repo.listEventsCount, 2);

      final state = container.read(calendarControllerProvider);
      expect(state.selectedDate, DateTime(2026, 7, 14));
      expect(state.focusedMonth, DateTime(2026, 7));
      expect(state.agendaEvents.single.id, 'agenda-1');
      expect(state.overdueEvents.single.id, 'overdue-1');
      expect(state.hasMoreInRange, isTrue);
      expect(state.hasMoreOverdue, isTrue);
      expect(state.isSummaryQueryAligned, isTrue);
    },
  );

  test('selectDate reloads agenda only', () async {
    final repo = FakeCalendarRepository();
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);

    await _boot(container);

    final summaryBefore = repo.getRangeSummaryCount;
    final listBefore = repo.listEventsCount;

    await container
        .read(calendarControllerProvider.notifier)
        .selectDate(DateTime(2026, 7, 15));
    await _waitForIdle(container);

    expect(repo.getRangeSummaryCount, summaryBefore);
    expect(repo.listEventsCount, listBefore + 1);
    expect(repo.lastListFrom, DateTime(2026, 7, 15));
    expect(repo.lastListTo, DateTime(2026, 7, 15));
    expect(repo.lastIncludeOverdue, isFalse);
    expect(
      container.read(calendarControllerProvider).selectedDate,
      DateTime(2026, 7, 15),
    );
    expect(
      container.read(calendarControllerProvider).hasExplicitSelectedDate,
      isTrue,
    );
  });

  test('goToNextMonth clamps selection and setFilters reset cursors', () async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        hasMoreInRange: true,
        nextCursorInRange: 'old-in',
        hasMoreOverdue: true,
        nextCursorOverdue: 'old-od',
      ),
    );
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);

    await _boot(container);

    expect(
      container.read(calendarControllerProvider).nextCursorInRange,
      'old-in',
    );

    // Select July 31 so next month clamps to Aug 31.
    await container
        .read(calendarControllerProvider.notifier)
        .selectDate(DateTime(2026, 7, 31));
    await _waitForIdle(container);

    repo.listResult = sampleEventList(
      tenantLocalToday: DateTime(2026, 7, 14),
      overdueRows: const [],
    );
    await container.read(calendarControllerProvider.notifier).goToNextMonth();
    await _waitForIdle(container);

    var state = container.read(calendarControllerProvider);
    expect(state.focusedMonth, DateTime(2026, 8));
    expect(state.selectedDate, DateTime(2026, 8, 31));
    expect(state.nextCursorInRange, isNull);
    expect(state.nextCursorOverdue, isNull);
    expect(repo.getRangeSummaryCount, greaterThanOrEqualTo(2));

    await container
        .read(calendarControllerProvider.notifier)
        .setFilters(CalendarFilters(unassignedOnly: true));
    await _waitForIdle(container);

    state = container.read(calendarControllerProvider);
    expect(state.filters.unassignedOnly, isTrue);
    expect(state.nextCursorInRange, isNull);
    expect(repo.lastRangeFilters?.unassignedOnly, isTrue);
  });

  test('goToMonth jumps directly and clamps the selected day', () async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);

    await _boot(container);
    await container
        .read(calendarControllerProvider.notifier)
        .selectDate(DateTime(2026, 7, 31));
    await _waitForIdle(container);

    await container
        .read(calendarControllerProvider.notifier)
        .goToMonth(DateTime(2027, 2));
    await _waitForIdle(container);

    final state = container.read(calendarControllerProvider);
    expect(state.focusedMonth, DateTime(2027, 2));
    expect(state.selectedDate, DateTime(2027, 2, 28));
    expect(
      repo.listCallLog.any(
        (call) =>
            !call.includeOverdue &&
            call.dateFrom == DateTime(2027, 2, 28) &&
            call.dateTo == DateTime(2027, 2, 28),
      ),
      isTrue,
    );
  });

  test('loadMoreInRange is a no-op when !hasMore', () async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(hasMoreInRange: false),
    );
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);

    await _boot(container);

    final listBefore = repo.listEventsCount;
    await container.read(calendarControllerProvider.notifier).loadMoreInRange();
    await _waitForIdle(container);

    expect(repo.listEventsCount, listBefore);
  });

  test('loadMoreOverdue merges only overdue bucket', () async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        inRangeRows: [sampleCalendarEvent(id: 'agenda-1')],
        overdueRows: [sampleCalendarEvent(id: 'overdue-1')],
        hasMoreOverdue: true,
        nextCursorOverdue: 'od-1',
      ),
    );
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);

    await _boot(container);

    repo.listResult = sampleEventList(
      inRangeRows: [sampleCalendarEvent(id: 'sibling-in-range')],
      overdueRows: [sampleCalendarEvent(id: 'overdue-2')],
      hasMoreOverdue: false,
      nextCursorOverdue: null,
    );

    await container.read(calendarControllerProvider.notifier).loadMoreOverdue();
    await _waitForIdle(container);

    final state = container.read(calendarControllerProvider);
    expect(
      state.agendaEvents.map((e) => e.id),
      isNot(contains('sibling-in-range')),
    );
    expect(state.overdueEvents.map((e) => e.id).toList(), [
      'overdue-1',
      'overdue-2',
    ]);
    expect(repo.lastIncludeOverdue, isTrue);
    expect(repo.lastCursorOverdue, 'od-1');
  });

  test('unconfigured schedule sets setup warning while agenda loads', () async {
    final repo = FakeCalendarRepository(
      rangeResult: sampleRangeSummary(workingScheduleConfigured: false),
      listResult: sampleEventList(
        inRangeRows: [sampleCalendarEvent(id: 'agenda-1')],
        overdueRows: const [],
      ),
    );
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);

    await _boot(container);

    final state = container.read(calendarControllerProvider);
    expect(state.showSetupWarning, isTrue);
    expect(state.workingScheduleConfigured, isFalse);
    expect(state.agendaEvents.single.id, 'agenda-1');
  });

  test('permission denial without calendar access', () async {
    final repo = FakeCalendarRepository();
    final container = _container(
      session: _session(permissions: {}),
      repo: repo,
    );
    addTearDown(container.dispose);

    await _boot(container);

    final state = container.read(calendarControllerProvider);
    expect(state.permissionDenied, isTrue);
    expect(repo.getRangeSummaryCount, 0);
    expect(repo.listEventsCount, 0);
  });

  test('surfaces CalendarException error codes from fake', () async {
    final repo = FakeCalendarRepository(
      rangeError: const CalendarException(code: CalendarException.notAvailable),
      listError: const CalendarException(
        code: CalendarException.malformedResponse,
      ),
    );
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);

    await _boot(container);

    final state = container.read(calendarControllerProvider);
    expect(state.summaryErrorCode, CalendarException.notAvailable);
    expect(state.agendaErrorCode, CalendarException.malformedResponse);
  });

  test('session change triggers reload', () async {
    final auth = _TestAuthController(_session());
    final repo = FakeCalendarRepository();
    final container = _container(session: _session(), repo: repo, auth: auth);
    addTearDown(container.dispose);

    await _boot(container);

    final summaryBefore = repo.getRangeSummaryCount;
    auth.setSession(_session(userId: 'user-2'));
    await _waitForIdle(container);

    expect(repo.getRangeSummaryCount, greaterThan(summaryBefore));
  });

  test('deferred tenant A load discarded after switch to B', () async {
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
    expect(repo.getRangeSummaryCount, greaterThanOrEqualTo(1));

    // State updates immediately; loads remain gated on the Completers.
    final filtersFuture = container
        .read(calendarControllerProvider.notifier)
        .setFilters(CalendarFilters(unassignedOnly: true));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(calendarControllerProvider).filters.unassignedOnly,
      isTrue,
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
    await filtersFuture;
    await _waitForIdle(container);

    final state = container.read(calendarControllerProvider);
    expect(state.filters.unassignedOnly, isFalse);
    expect(state.agendaEvents.map((e) => e.id), ['tenant-b-event']);
    expect(
      state.agendaEvents.map((e) => e.id),
      isNot(contains('tenant-a-event')),
    );
  });

  test(
    'concurrent loadMoreInRange and loadMoreOverdue both complete',
    () async {
      final holdInRange = Completer<void>();
      final holdOverdue = Completer<void>();
      final repo = FakeCalendarRepository(
        listResult: sampleEventList(
          inRangeRows: [sampleCalendarEvent(id: 'agenda-1')],
          overdueRows: [sampleCalendarEvent(id: 'overdue-1')],
          hasMoreInRange: true,
          nextCursorInRange: 'in-1',
          hasMoreOverdue: true,
          nextCursorOverdue: 'od-1',
        ),
      );
      final container = _container(session: _session(), repo: repo);
      addTearDown(container.dispose);

      await _boot(container);

      repo
        ..holdLoadMoreInRangeUntil = holdInRange
        ..holdLoadMoreOverdueUntil = holdOverdue
        ..listResult = sampleEventList(
          inRangeRows: [sampleCalendarEvent(id: 'agenda-2')],
          overdueRows: [sampleCalendarEvent(id: 'overdue-2')],
          hasMoreInRange: false,
          nextCursorInRange: null,
          hasMoreOverdue: false,
          nextCursorOverdue: null,
        );

      final inRangeFuture = container
          .read(calendarControllerProvider.notifier)
          .loadMoreInRange();
      final overdueFuture = container
          .read(calendarControllerProvider.notifier)
          .loadMoreOverdue();

      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(calendarControllerProvider).isLoadingMoreInRange,
        isTrue,
      );
      expect(
        container.read(calendarControllerProvider).isLoadingMoreOverdue,
        isTrue,
      );

      // Complete overdue first (reverse of start order).
      holdOverdue.complete();
      await overdueFuture;
      holdInRange.complete();
      await inRangeFuture;
      await _waitForIdle(container);

      final state = container.read(calendarControllerProvider);
      expect(state.isLoadingMoreInRange, isFalse);
      expect(state.isLoadingMoreOverdue, isFalse);
      expect(state.loadMoreInRangeErrorCode, isNull);
      expect(state.loadMoreOverdueErrorCode, isNull);
      expect(state.agendaEvents.map((e) => e.id).toList(), [
        'agenda-1',
        'agenda-2',
      ]);
      expect(state.overdueEvents.map((e) => e.id).toList(), [
        'overdue-1',
        'overdue-2',
      ]);
    },
  );

  test(
    'tenant_local_today from server becomes selectedDate before explicit',
    () async {
      final repo = FakeCalendarRepository(
        rangeResult: sampleRangeSummary(
          tenantLocalToday: DateTime(2026, 7, 15),
        ),
        listResult: sampleEventList(
          tenantLocalToday: DateTime(2026, 7, 15),
          inRangeRows: [sampleCalendarEvent(id: 'on-15')],
          overdueRows: const [],
        ),
      );
      final container = _container(session: _session(), repo: repo);
      addTearDown(container.dispose);

      // Device clock stays 2026-07-14 (setUp).
      await _boot(container);

      final state = container.read(calendarControllerProvider);
      expect(state.selectedDate, DateTime(2026, 7, 15));
      expect(state.tenantLocalToday, DateTime(2026, 7, 15));
      expect(state.hasExplicitSelectedDate, isFalse);
      expect(repo.lastListFrom, DateTime(2026, 7, 15));
    },
  );

  test('tenant today in another month moves visible range', () async {
    final repo = FakeCalendarRepository(
      rangeResult: sampleRangeSummary(
        dateFrom: DateTime(2026, 8, 1),
        dateTo: DateTime(2026, 8, 31),
        tenantLocalToday: DateTime(2026, 8, 3),
      ),
      listResult: sampleEventList(
        tenantLocalToday: DateTime(2026, 8, 3),
        dateFrom: DateTime(2026, 8, 3),
        dateTo: DateTime(2026, 8, 3),
        inRangeRows: [sampleCalendarEvent(id: 'aug')],
        overdueRows: const [],
      ),
    );
    // First summary response still uses July range request — inject August
    // today so controller adopts and shifts.
    repo.rangeResult = sampleRangeSummary(
      tenantLocalToday: DateTime(2026, 8, 3),
    );

    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);

    await _boot(container);

    final state = container.read(calendarControllerProvider);
    expect(state.selectedDate, DateTime(2026, 8, 3));
    expect(state.focusedMonth, DateTime(2026, 8));
    // Sunday-padded August 2026: Jul 26 … Sep 5
    expect(state.dateFrom, DateTime(2026, 7, 26));
    expect(state.dateTo, DateTime(2026, 9, 5));
  });

  test(
    'explicit selectDate preserved when later summary has different today',
    () async {
      final repo = FakeCalendarRepository();
      final container = _container(session: _session(), repo: repo);
      addTearDown(container.dispose);

      await _boot(container);

      await container
          .read(calendarControllerProvider.notifier)
          .selectDate(DateTime(2026, 7, 20));
      await _waitForIdle(container);

      repo.rangeResult = sampleRangeSummary(
        tenantLocalToday: DateTime(2026, 7, 15),
      );
      await container.read(calendarControllerProvider.notifier).refresh();
      await _waitForIdle(container);

      final state = container.read(calendarControllerProvider);
      expect(state.hasExplicitSelectedDate, isTrue);
      expect(state.selectedDate, DateTime(2026, 7, 20));
      expect(state.tenantLocalToday, DateTime(2026, 7, 15));
    },
  );

  test(
    'refresh preserves hasExplicitSelectedDate; identity change resets',
    () async {
      final auth = _TestAuthController(_session());
      final repo = FakeCalendarRepository();
      final container = _container(session: _session(), repo: repo, auth: auth);
      addTearDown(container.dispose);

      await _boot(container);

      await container
          .read(calendarControllerProvider.notifier)
          .setFilters(CalendarFilters(unassignedOnly: true));
      await container
          .read(calendarControllerProvider.notifier)
          .selectDate(DateTime(2026, 7, 18));
      await _waitForIdle(container);

      expect(
        container.read(calendarControllerProvider).hasExplicitSelectedDate,
        isTrue,
      );
      expect(
        container.read(calendarControllerProvider).filters.unassignedOnly,
        isTrue,
      );

      // Refresh reloads cursors from the server but keeps selection/filters.
      repo.listResult = sampleEventList(
        hasMoreInRange: true,
        nextCursorInRange: 'keep-check',
        overdueRows: const [],
      );
      await container.read(calendarControllerProvider.notifier).refresh();
      await _waitForIdle(container);

      var state = container.read(calendarControllerProvider);
      expect(state.hasExplicitSelectedDate, isTrue);
      expect(state.selectedDate, DateTime(2026, 7, 18));
      expect(state.filters.unassignedOnly, isTrue);
      expect(state.nextCursorInRange, 'keep-check');

      repo.listResult = sampleEventList(overdueRows: const []);
      auth.setSession(_session(userId: 'user-2', tenantId: 'tenant-2'));
      await _waitForIdle(container);

      state = container.read(calendarControllerProvider);
      expect(state.hasExplicitSelectedDate, isFalse);
      expect(state.filters.unassignedOnly, isFalse);
      expect(state.selectedDate, DateTime(2026, 7, 14));
      expect(state.nextCursorInRange, isNull);
      expect(state.nextCursorOverdue, isNull);
    },
  );

  test(
    'initial overdue failure sets overdueErrorCode; refresh recovers',
    () async {
      final repo = FakeCalendarRepository(
        listErrorWhenIncludeOverdue: const CalendarException(
          code: CalendarException.notAvailable,
        ),
      );
      final container = _container(session: _session(), repo: repo);
      addTearDown(container.dispose);

      await _boot(container);
      var state = container.read(calendarControllerProvider);
      expect(state.overdueErrorCode, CalendarException.notAvailable);
      expect(state.overdueEvents, isEmpty);
      expect(state.agendaEvents, isNotEmpty);
      expect(state.summaryErrorCode, isNull);

      repo.listErrorWhenIncludeOverdue = null;
      repo.listResult = sampleEventList(
        overdueRows: [
          sampleCalendarEvent(
            id: 'recovered-od',
            scheduledDate: DateTime(2026, 6, 2),
          ),
        ],
      );
      await container.read(calendarControllerProvider.notifier).refresh();
      await _waitForIdle(container);

      state = container.read(calendarControllerProvider);
      expect(state.overdueErrorCode, isNull);
      expect(state.overdueEvents.map((e) => e.id), contains('recovered-od'));
    },
  );

  test('stale overdue failure does not overwrite newer success', () async {
    final holdOverdue = Completer<void>();
    final repo = FakeCalendarRepository(
      listErrorWhenIncludeOverdue: const CalendarException(
        code: CalendarException.validationFailed,
      ),
    );
    repo.holdOverdueUntil = holdOverdue;
    final container = _container(session: _session(), repo: repo);
    addTearDown(container.dispose);

    final bootFuture = container
        .read(calendarControllerProvider.notifier)
        .ensureWeekStart(0);
    await Future<void>.delayed(Duration.zero);
    // First overdue call is gated; clear error path before completing it.
    repo.listErrorWhenIncludeOverdue = null;
    repo.listResult = sampleEventList(
      overdueRows: [
        sampleCalendarEvent(
          id: 'fresh-od',
          scheduledDate: DateTime(2026, 5, 1),
        ),
      ],
    );
    // Invalidate by triggering a new overdue generation via refresh.
    repo.holdOverdueUntil = null;
    await container.read(calendarControllerProvider.notifier).refresh();
    await _waitForIdle(container);

    holdOverdue.complete();
    await bootFuture;
    await Future<void>.delayed(Duration.zero);
    await _waitForIdle(container);

    final state = container.read(calendarControllerProvider);
    expect(state.overdueErrorCode, isNull);
    expect(state.overdueEvents.map((e) => e.id), contains('fresh-od'));
  });
}
