import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_event.dart';
import 'package:hs360/features/calendar/domain/calendar_manual_mutation.dart';
import 'package:hs360/features/calendar/domain/calendar_schedule_mutation.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';
import 'package:hs360/l10n/app_localizations.dart';

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
  String userId = 'user-1',
  String tenantId = 'tenant-1',
  Set<String> permissions = const {'calendar.view', 'calendar.edit'},
}) {
  return AppSession(
    userId: userId,
    email: 'test@example.com',
    tenantId: tenantId,
    tenantUserId: 'tu-1',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

late BuildContext _hostContext;

Future<ProviderContainer> _pumpHost(
  WidgetTester tester, {
  required FakeCalendarRepository repo,
  required _TestAuthController auth,
}) async {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => auth),
      calendarRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              _hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  return container;
}

Future<void> _boot(WidgetTester tester, ProviderContainer container) async {
  container.read(calendarControllerProvider);
  final future = container
      .read(calendarControllerProvider.notifier)
      .ensureWeekStart(0);
  await tester.pumpAndSettle();
  await future;
}

CalendarEvent _pendingEvent({String id = 'event-1', int version = 3}) {
  return sampleCalendarEvent(id: id, scheduleVersion: version);
}

const _overlapOnlyConflict = CalendarManualConflictInfo(
  scheduleWarnings: [],
  overlapWarnings: [
    {'employee_id': 'emp-1'},
  ],
  overlapTotalCount: 1,
);

void main() {
  late CalendarClock previousClock;

  setUp(() {
    previousClock = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });

  tearDown(() {
    calendarClock = previousClock;
  });

  testWidgets('assign success sends contract, refreshes, and confirms', (
    tester,
  ) async {
    final repo = FakeCalendarRepository();
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final refreshesBefore = repo.getRangeSummaryCount;
    final ok = await container
        .read(calendarControllerProvider.notifier)
        .assignCalendarEvent(
          _hostContext,
          _pendingEvent(),
          assignedAgentId: '11111111-1111-1111-1111-111111111111',
        );
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    expect(repo.assignCount, 1);
    expect(repo.lastAssignEventId, 'event-1');
    expect(repo.lastAssignExpectedVersion, 3);
    expect(
      repo.lastAssignData!.assignedAgentId,
      '11111111-1111-1111-1111-111111111111',
    );
    expect(repo.lastAssignIdempotencyKey, isNotEmpty);
    expect(repo.getRangeSummaryCount, greaterThan(refreshesBefore));
    expect(find.text('Assignment saved.'), findsOneWidget);
  });

  testWidgets('assign unassign passes a null agent', (tester) async {
    final repo = FakeCalendarRepository();
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final ok = await container
        .read(calendarControllerProvider.notifier)
        .assignCalendarEvent(
          _hostContext,
          _pendingEvent(),
          assignedAgentId: null,
        );
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    expect(repo.lastAssignData!.assignedAgentId, isNull);
  });

  testWidgets('assign requires calendar.edit', (tester) async {
    final repo = FakeCalendarRepository();
    final auth = _TestAuthController(
      _session(permissions: const {'calendar.view'}),
    );
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final ok = await container
        .read(calendarControllerProvider.notifier)
        .assignCalendarEvent(
          _hostContext,
          _pendingEvent(),
          assignedAgentId: null,
        );

    expect(ok, isFalse);
    expect(repo.assignCount, 0);
  });

  testWidgets('assign stale_version refreshes and surfaces error', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..assignError = const CalendarException(
        code: CalendarException.staleVersion,
      );
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final refreshesBefore = repo.getRangeSummaryCount;
    final ok = await container
        .read(calendarControllerProvider.notifier)
        .assignCalendarEvent(
          _hostContext,
          _pendingEvent(),
          assignedAgentId: null,
        );
    await tester.pumpAndSettle();

    expect(ok, isFalse);
    expect(repo.getRangeSummaryCount, greaterThan(refreshesBefore));
    expect(
      find.text('This event changed on another screen. Refresh and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('assign surfaces calendar_assignment_not_applicable', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..assignError = const CalendarException(
        code: CalendarException.assignmentNotApplicable,
      );
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final ok = await container
        .read(calendarControllerProvider.notifier)
        .assignCalendarEvent(
          _hostContext,
          _pendingEvent(),
          assignedAgentId: null,
        );
    await tester.pumpAndSettle();

    expect(ok, isFalse);
    expect(find.text('This event cannot be assigned.'), findsOneWidget);
  });

  testWidgets('assign result after tenant switch is discarded silently', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()..holdAssignUntil = Completer<void>();
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final future = container
        .read(calendarControllerProvider.notifier)
        .assignCalendarEvent(
          _hostContext,
          _pendingEvent(),
          assignedAgentId: null,
        );
    await tester.pump();

    auth.setSession(_session(tenantId: 'tenant-2'));
    await tester.pump();
    repo.holdAssignUntil!.complete();
    final ok = await future;
    await tester.pumpAndSettle();

    expect(ok, isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('assign result after logout is discarded silently', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()..holdAssignUntil = Completer<void>();
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final future = container
        .read(calendarControllerProvider.notifier)
        .assignCalendarEvent(
          _hostContext,
          _pendingEvent(),
          assignedAgentId: null,
        );
    await tester.pump();

    auth.setSession(null);
    await tester.pump();
    repo.holdAssignUntil!.complete();
    final ok = await future;
    await tester.pumpAndSettle();

    expect(ok, isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('assigned-only disappearance keeps selected date and explains', (
    tester,
  ) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        inRangeRows: [sampleCalendarEvent(id: 'event-1')],
        overdueRows: const [],
      ),
      rangeUnassignedCount: 1,
    );
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);
    expect(
      container.read(calendarControllerProvider).agendaEvents.map((e) => e.id),
      contains('event-1'),
    );
    final selectedBefore = container
        .read(calendarControllerProvider)
        .selectedDate;
    final summaryCallsBefore = repo.getRangeSummaryCount;
    final listCallsBefore = repo.listEventsCount;

    // Reassigning away from the current assigned-only scope: BOTH read
    // contracts stop returning the event — the agenda list is empty and the
    // range summary reports zero event/unassigned counts.
    repo.listResult = sampleEventList(
      inRangeRows: const [],
      overdueRows: const [],
    );
    repo.eventCountForDate = (_) => 0;
    repo.rangeUnassignedCount = 0;

    final ok = await container
        .read(calendarControllerProvider.notifier)
        .assignCalendarEvent(
          _hostContext,
          _pendingEvent(),
          assignedAgentId: '11111111-1111-1111-1111-111111111111',
        );
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    final state = container.read(calendarControllerProvider);

    // Selected date preserved.
    expect(state.selectedDate, selectedBefore);

    // The event is gone from both the agenda and overdue collections.
    expect(state.agendaEvents.map((e) => e.id), isNot(contains('event-1')));
    expect(state.overdueEvents.map((e) => e.id), isNot(contains('event-1')));

    // The selected-day summary was re-read: zero events and no stale
    // unassigned count.
    final daySummary = state.selectedDaySummary;
    expect(daySummary, isNotNull);
    expect(daySummary!.eventCount, 0);
    expect(daySummary.unassignedCount, 0);

    // Both the range summary and the agenda list were refreshed.
    expect(repo.getRangeSummaryCount, greaterThan(summaryCallsBefore));
    expect(repo.listEventsCount, greaterThan(listCallsBefore));

    // The visibility-loss message is shown instead of a false error.
    expect(
      find.text(
        'Assignment saved. This event is no longer visible in your view.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reschedule success sends contract and confirms', (tester) async {
    final repo = FakeCalendarRepository();
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final ok = await container
        .read(calendarControllerProvider.notifier)
        .rescheduleCalendarEvent(
          _hostContext,
          _pendingEvent(),
          targetDate: DateTime(2026, 8, 3),
          reason: 'customer request',
        );
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    expect(repo.rescheduleCount, 1);
    expect(repo.lastRescheduleEventId, 'event-1');
    expect(repo.lastRescheduleExpectedVersion, 3);
    expect(repo.lastRescheduleData!.reason, 'customer request');
    expect(find.text('Event rescheduled.'), findsOneWidget);
  });

  testWidgets('reschedule confirmation loop preserves the idempotency key', (
    tester,
  ) async {
    final repo = FakeCalendarRepository();
    repo.rescheduleResultsQueue.addAll([
      const CalendarScheduleMutationConfirmationRequired(_overlapOnlyConflict),
      CalendarScheduleMutationOk(
        sampleCalendarEvent(id: 'event-1'),
        changed: true,
      ),
    ]);
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final future = container
        .read(calendarControllerProvider.notifier)
        .rescheduleCalendarEvent(
          _hostContext,
          _pendingEvent(),
          targetDate: DateTime(2026, 8, 3),
          reason: 'move',
        );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-conflict-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('calendar-ack-overlap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-conflict-confirm-submit')));
    await tester.pumpAndSettle();

    final ok = await future;
    expect(ok, isTrue);
    expect(repo.rescheduleCount, 2);
    expect(repo.rescheduleKeyLog.toSet(), hasLength(1));
    expect(
      repo.lastRescheduleData!.acknowledgements.acknowledgeOverlap,
      isTrue,
    );
  });

  testWidgets('reschedule conflict cancel aborts without retry', (
    tester,
  ) async {
    final repo = FakeCalendarRepository();
    repo.rescheduleResultsQueue.add(
      const CalendarScheduleMutationConfirmationRequired(_overlapOnlyConflict),
    );
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final future = container
        .read(calendarControllerProvider.notifier)
        .rescheduleCalendarEvent(
          _hostContext,
          _pendingEvent(),
          targetDate: DateTime(2026, 8, 3),
          reason: 'move',
        );
    await tester.pumpAndSettle();

    // Dismiss without confirming.
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    final ok = await future;
    expect(ok, isFalse);
    expect(repo.rescheduleCount, 1);
  });

  testWidgets('reschedule result after tenant switch is discarded', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..holdRescheduleUntil = Completer<void>();
    final auth = _TestAuthController(_session());
    final container = await _pumpHost(tester, repo: repo, auth: auth);
    await _boot(tester, container);

    final future = container
        .read(calendarControllerProvider.notifier)
        .rescheduleCalendarEvent(
          _hostContext,
          _pendingEvent(),
          targetDate: DateTime(2026, 8, 3),
          reason: 'move',
        );
    await tester.pump();

    auth.setSession(_session(tenantId: 'tenant-2'));
    await tester.pump();
    repo.holdRescheduleUntil!.complete();
    final ok = await future;
    await tester.pumpAndSettle();

    expect(ok, isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });
}
