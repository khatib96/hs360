import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';
import 'package:hs360/features/calendar/presentation/calendar_screen.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_filter_bar.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_calendar_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  final AppSession _session;

  @override
  FutureOr<AppSession?> build() => _session;
}

AppSession _session({Set<String> permissions = const {'calendar.view'}}) {
  return AppSession(
    userId: 'user-1',
    email: 't@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollCalendarBody(WidgetTester tester, double dy) async {
  final list = find.byType(Scrollable).first;
  await tester.drag(list, Offset(0, dy));
  await tester.pumpAndSettle();
}

Future<void> _revealAgenda(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    if (find.byKey(const Key('calendar-agenda-date')).evaluate().isNotEmpty) {
      return;
    }
    await _scrollCalendarBody(tester, -500);
  }
}

Future<void> _openFilterPopover(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tester.tap(find.byKey(const Key('calendar-filter-funnel')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(find.byKey(const Key('calendar-filter-popover')), findsOneWidget);
}

Future<void> _ensureFilterKeyVisible(WidgetTester tester, Key key) async {
  final list = find.descendant(
    of: find.byKey(const Key('calendar-filter-popover')),
    matching: find.byType(Scrollable),
  );
  await tester.dragUntilVisible(
    find.byKey(key),
    list,
    const Offset(0, -80),
  );
  await tester.pumpAndSettle();
}

Future<void> _assertFilterKeyAbsent(WidgetTester tester, Key key) async {
  final list = find.descendant(
    of: find.byKey(const Key('calendar-filter-popover')),
    matching: find.byType(Scrollable),
  );
  for (var i = 0; i < 20; i++) {
    if (find.byKey(key).evaluate().isNotEmpty) break;
    await tester.drag(list, const Offset(0, -120));
    await tester.pump();
  }
  expect(find.byKey(key), findsNothing);
}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  required FakeCalendarRepository repo,
  AppSession? session,
  bool withRouter = false,
}) async {
  await _setDesktopSurface(tester);
  late ProviderContainer container;
  final overrides = <Override>[
    authControllerProvider.overrideWith(
      () => _TestAuthController(session ?? _session()),
    ),
    calendarRepositoryProvider.overrideWith((ref) => repo),
  ];

  final child = withRouter
      ? MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const CalendarScreen(),
              ),
              GoRoute(
                path: '/customers/:id',
                builder: (context, state) =>
                    const Scaffold(body: Text('customer-detail')),
              ),
              GoRoute(
                path: '/contracts/:id',
                builder: (context, state) =>
                    const Scaffold(body: Text('contract-detail')),
              ),
            ],
          ),
        )
      : MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalendarScreen(),
        );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return child;
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  return container;
}

void main() {
  late CalendarClock previous;

  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });

  tearDown(() => calendarClock = previous);

  testWidgets('search debounce applies after ~450ms', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    await _pumpScreen(tester, repo: repo);

    await tester.enterText(
      find.byKey(const Key('calendar-filter-search')),
      'refill',
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.lastRangeFilters?.search, isNull);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(repo.lastRangeFilters?.search, 'refill');
  });

  testWidgets('Enter applies search immediately', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    await _pumpScreen(tester, repo: repo);

    await tester.enterText(
      find.byKey(const Key('calendar-filter-search')),
      'ok',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.lastRangeFilters?.search, 'ok');
  });

  testWidgets('short search under 2 chars is ignored', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    await _pumpScreen(tester, repo: repo);

    await tester.enterText(
      find.byKey(const Key('calendar-filter-search')),
      'x',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.lastRangeFilters?.search, isNull);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repo.lastRangeFilters?.search, isNull);
  });

  testWidgets('clear resets search and filters', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    final container = await _pumpScreen(tester, repo: repo);

    await tester.enterText(
      find.byKey(const Key('calendar-filter-search')),
      'ok',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await _openFilterPopover(tester);
    await _ensureFilterKeyVisible(
      tester,
      const Key('calendar-filter-overdue'),
    );
    await tester.tap(find.byKey(const Key('calendar-filter-overdue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('calendar-filter-apply')));
    await tester.pumpAndSettle();
    expect(
      container.read(calendarControllerProvider).filters.overdueOnly,
      isTrue,
    );
    expect(container.read(calendarControllerProvider).filters.search, 'ok');

    await tester.tap(find.byKey(const Key('calendar-filter-clear')));
    await tester.pumpAndSettle();
    expect(
      container.read(calendarControllerProvider).filters,
      CalendarFilters.empty,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('calendar-filter-search')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('badge shows activePopoverGroupCount not search', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    final container = await _pumpScreen(tester, repo: repo);

    await tester.enterText(
      find.byKey(const Key('calendar-filter-search')),
      'ok',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('calendar-filter-toolbar')),
        matching: find.text('1'),
      ),
      findsNothing,
    );

    await _openFilterPopover(tester);
    await _ensureFilterKeyVisible(
      tester,
      const Key('calendar-filter-overdue'),
    );
    await tester.tap(find.byKey(const Key('calendar-filter-overdue')));
    await tester.pump();
    await _ensureFilterKeyVisible(
      tester,
      const Key('calendar-filter-unassigned'),
    );
    await tester.tap(find.byKey(const Key('calendar-filter-unassigned')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('calendar-filter-apply')));
    await tester.pumpAndSettle();

    expect(
      container.read(calendarControllerProvider).filters.activePopoverGroupCount,
      2,
    );
    expect(
      find.descendant(
        of: find.byType(Badge),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('draft popover changes are discarded until Apply', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    final container = await _pumpScreen(tester, repo: repo);

    await _openFilterPopover(tester);
    await _ensureFilterKeyVisible(
      tester,
      const Key('calendar-filter-overdue'),
    );
    await tester.tap(find.byKey(const Key('calendar-filter-overdue')));
    await tester.pump();
    // Dismiss without Apply.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(
      container.read(calendarControllerProvider).filters.overdueOnly,
      isFalse,
    );
    expect(find.byKey(const Key('calendar-filter-popover')), findsNothing);

    await _openFilterPopover(tester);
    await _ensureFilterKeyVisible(
      tester,
      const Key('calendar-filter-overdue'),
    );
    await tester.tap(find.byKey(const Key('calendar-filter-overdue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('calendar-filter-apply')));
    await tester.pumpAndSettle();
    expect(
      container.read(calendarControllerProvider).filters.overdueOnly,
      isTrue,
    );
  });

  testWidgets('Reset in popover clears draft facets then Apply commits', (
    tester,
  ) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    final container = await _pumpScreen(tester, repo: repo);

    await _openFilterPopover(tester);
    await _ensureFilterKeyVisible(
      tester,
      const Key('calendar-filter-overdue'),
    );
    await tester.tap(find.byKey(const Key('calendar-filter-overdue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('calendar-filter-apply')));
    await tester.pumpAndSettle();
    expect(
      container.read(calendarControllerProvider).filters.overdueOnly,
      isTrue,
    );

    await _openFilterPopover(tester);
    await tester.tap(find.byKey(const Key('calendar-filter-reset')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('calendar-filter-apply')));
    await tester.pumpAndSettle();
    expect(
      container.read(calendarControllerProvider).filters.overdueOnly,
      isFalse,
    );
  });

  testWidgets('assigned-only never shows unassigned in funnel', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
      rangeScope: CalendarReadScope.assignedOnly,
      rangeUnassignedCount: null,
    );
    await _pumpScreen(
      tester,
      repo: repo,
      session: _session(permissions: {'calendar.view_assigned'}),
    );

    await _openFilterPopover(tester);
    await _assertFilterKeyAbsent(
      tester,
      const Key('calendar-filter-unassigned'),
    );
  });

  testWidgets('setFilters with customerId sanitizes exact IDs', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    final container = await _pumpScreen(tester, repo: repo);

    await container
        .read(calendarControllerProvider.notifier)
        .setFilters(
          CalendarFilters(
            customerId: 'cust-1',
            contractId: 'ct-1',
            search: 'ok',
            overdueOnly: true,
          ),
        );
    await tester.pumpAndSettle();

    final filters = container.read(calendarControllerProvider).filters;
    expect(filters.customerId, isNull);
    expect(filters.contractId, isNull);
    expect(filters.search, 'ok');
    expect(filters.overdueOnly, isTrue);
  });

  testWidgets(
    'event card tap/Enter opens action menu; actions respect available_actions',
    (tester) async {
      final repo = FakeCalendarRepository(
        listResult: sampleEventList(
          inRangeRows: [
            sampleCalendarEvent(
              id: 'nav-1',
              customerId: 'cust-1',
              customerNameEn: 'Acme',
              contractId: 'ct-1',
              contractNumber: 'C-1',
              availableActions: const CalendarAvailableActions(
                canViewCustomer: true,
                canViewContract: true,
                canAssign: false,
                canReschedule: false,
                canCreateManual: false,
                canOpenDirections: false,
              ),
            ),
            sampleCalendarEvent(
              id: 'no-actions',
              availableActions: const CalendarAvailableActions(
                canViewCustomer: false,
                canViewContract: false,
                canAssign: false,
                canReschedule: false,
                canCreateManual: false,
                canOpenDirections: false,
              ),
            ),
          ],
          overdueRows: const [],
        ),
      );
      await _pumpScreen(tester, repo: repo, withRouter: true);
      await _revealAgenda(tester);

      // No inline Phase 8 / navigation buttons on the card itself.
      expect(
        find.byKey(const Key('calendar-view-customer-nav-1')),
        findsNothing,
      );
      expect(find.widgetWithText(TextButton, 'Assign'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Reschedule'), findsNothing);

      await tester.tap(find.byKey(const Key('calendar-event-ink-nav-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('calendar-event-actions-nav-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calendar-view-customer-nav-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calendar-view-contract-nav-1')),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Assign'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Reschedule'), findsNothing);

      await tester.tap(find.byKey(const Key('calendar-event-actions-close-nav-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calendar-event-ink-no-actions')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('calendar-event-actions-no-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calendar-view-customer-no-actions')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('calendar-view-contract-no-actions')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const Key('calendar-event-actions-close-no-actions')),
      );
      await tester.pumpAndSettle();

      final ink = find.byKey(const Key('calendar-event-ink-nav-1'));
      await tester.ensureVisible(ink);
      Focus.of(tester.element(ink)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('calendar-event-actions-nav-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets('CalendarFilterBar clear still works when seeded with ids', (
    tester,
  ) async {
    var applied = CalendarFilters(
      customerId: 'cust-1',
      overdueOnly: true,
      search: 'ab',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthController(_session()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CalendarFilterBar(
                  applied: applied,
                  scope: CalendarReadScope.tenantWide,
                  dateFrom: DateTime(2026, 6, 28),
                  dateTo: DateTime(2026, 8, 1),
                  onApply: (f) => setState(() => applied = f),
                  onClear: () =>
                      setState(() => applied = CalendarFilters.empty),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calendar-filter-clear')));
    await tester.pumpAndSettle();
    expect(applied, CalendarFilters.empty);
  });
}
