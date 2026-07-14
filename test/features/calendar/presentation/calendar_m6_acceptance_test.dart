import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';
import 'package:hs360/features/calendar/presentation/calendar_screen.dart';
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

Future<void> _setDesktopSurface(
  WidgetTester tester, {
  Size size = const Size(1280, 1800),
}) async {
  tester.view.physicalSize = size;
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

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FakeCalendarRepository repo,
  AppSession? session,
  Locale locale = const Locale('en'),
  Size size = const Size(1280, 1800),
  double textScale = 1.0,
  List<Override> extraOverrides = const [],
  bool withRouter = false,
}) async {
  await _setDesktopSurface(tester, size: size);
  final overrides = <Override>[
    authControllerProvider.overrideWith(
      () => _TestAuthController(session ?? _session()),
    ),
    calendarRepositoryProvider.overrideWith((ref) => repo),
    ...extraOverrides,
  ];

  final child = withRouter
      ? MaterialApp.router(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
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
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
          home: const CalendarScreen(),
        );

  await tester.pumpWidget(ProviderScope(overrides: overrides, child: child));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  late CalendarClock previous;

  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });

  tearDown(() => calendarClock = previous);

  testWidgets('day selection updates agenda in place', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
      echoAgendaDate: true,
    );
    await _pumpScreen(tester, repo: repo);
    await _revealAgenda(tester);

    expect(
      find.byKey(const Key('calendar-event-event-2026-7-14')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calendar-day-2026-7-15')));
    await tester.pumpAndSettle();
    await _revealAgenda(tester);

    expect(
      find.byKey(const Key('calendar-event-event-2026-7-14')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('calendar-event-event-2026-7-15')),
      findsOneWidget,
    );
    expect(repo.lastListFrom, DateTime(2026, 7, 15));
  });

  testWidgets('Previous/Next/Today and adjacent-month cell', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
      echoAgendaDate: true,
    );
    await _pumpScreen(tester, repo: repo);

    expect(find.byKey(const Key('calendar-month-title')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-next-month')));
    await tester.pumpAndSettle();
    expect(repo.getRangeSummaryCount, greaterThan(1));

    await tester.tap(find.byKey(const Key('calendar-prev-month')));
    await tester.pumpAndSettle();

    // Adjacent June cell inside July padded grid.
    expect(find.byKey(const Key('calendar-day-2026-6-28')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-day-2026-6-28')));
    await tester.pumpAndSettle();
    await _revealAgenda(tester);
    expect(
      find.byKey(const Key('calendar-event-event-2026-6-28')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calendar-today')));
    await tester.pumpAndSettle();
    await _revealAgenda(tester);
    expect(
      find.byKey(const Key('calendar-event-event-2026-7-14')),
      findsOneWidget,
    );
  });

  testWidgets('filters preserved across month navigation', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    await _pumpScreen(tester, repo: repo);

    await tester.enterText(
      find.byKey(const Key('calendar-filter-search')),
      'refill',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.lastRangeFilters?.search, 'refill');

    await tester.tap(find.byKey(const Key('calendar-next-month')));
    await tester.pumpAndSettle();
    expect(repo.lastRangeFilters?.search, 'refill');
  });

  testWidgets('search/popover Apply/Clear and RPC failure', (tester) async {
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

    await tester.enterText(
      find.byKey(const Key('calendar-filter-search')),
      'ok',
    );
    repo.rangeError = const CalendarException(
      code: CalendarException.notAvailable,
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-retry-summary')), findsOneWidget);

    repo.rangeError = null;
    await tester.tap(find.byKey(const Key('calendar-filter-clear')));
    await tester.pumpAndSettle();
    expect(repo.lastRangeFilters, CalendarFilters.empty);

    await tester.tap(find.byKey(const Key('calendar-filter-funnel')));
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(const Key('calendar-filter-popover')),
      matching: find.byType(Scrollable),
    );
    await tester.dragUntilVisible(
      find.byKey(const Key('calendar-filter-overdue')),
      list,
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-filter-overdue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('calendar-filter-apply')));
    await tester.pumpAndSettle();
    expect(repo.lastRangeFilters?.overdueOnly, isTrue);
  });

  testWidgets('assigned-only hides unassigned count and funnel option', (
    tester,
  ) async {
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

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.calendarDayUnassignedCount(0)), findsNothing);
    expect(find.text(l10n.calendarDayUnassignedCount(1)), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-filter-funnel')));
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(const Key('calendar-filter-popover')),
      matching: find.byType(Scrollable),
    );
    // Scroll through; unassigned must not appear for assigned-only.
    for (var i = 0; i < 20; i++) {
      if (find
          .byKey(const Key('calendar-filter-unassigned'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.drag(list, const Offset(0, -120));
      await tester.pump();
    }
    expect(find.byKey(const Key('calendar-filter-unassigned')), findsNothing);
  });

  testWidgets('working day labels: day off / unreviewed / limited / 24h', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
      workingDayForDate: (date) {
        if (date == DateTime(2026, 7, 14)) {
          return sampleCalendarWorkingDay(
            date: date,
            dayMode: TenantWorkingDayMode.dayOff,
          );
        }
        if (date == DateTime(2026, 7, 15)) {
          return sampleCalendarWorkingDay(
            date: date,
            dayMode: TenantWorkingDayMode.unreviewed,
            scheduleConfigured: false,
          );
        }
        if (date == DateTime(2026, 7, 16)) {
          return sampleCalendarWorkingDay(
            date: date,
            dayMode: TenantWorkingDayMode.workingHours,
            workStart: '09:00',
            workEnd: '13:00',
          );
        }
        if (date == DateTime(2026, 7, 17)) {
          return sampleCalendarWorkingDay(
            date: date,
            dayMode: TenantWorkingDayMode.hours24,
          );
        }
        return sampleCalendarWorkingDay(date: date);
      },
    );
    await _pumpScreen(tester, repo: repo);
    await _revealAgenda(tester);

    expect(find.text(l10n.calendarDayModeDayOff), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-day-2026-7-15')));
    await tester.pumpAndSettle();
    await _revealAgenda(tester);
    expect(find.text(l10n.calendarDayModeUnreviewed), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-day-2026-7-16')));
    await tester.pumpAndSettle();
    await _revealAgenda(tester);
    expect(
      find.text(l10n.calendarWorkingWindow('09:00', '13:00')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calendar-day-2026-7-17')));
    await tester.pumpAndSettle();
    await _revealAgenda(tester);
    expect(find.text(l10n.calendarDayMode24Hours), findsOneWidget);
  });

  testWidgets('agenda card never shows colon appointment time pattern', (
    tester,
  ) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        inRangeRows: [
          sampleCalendarEvent(
            id: 'no-time',
            titleEn: 'Refill visit',
            titleAr: 'تعبئة',
          ),
        ],
        overdueRows: const [],
      ),
    );
    await _pumpScreen(tester, repo: repo);
    await _revealAgenda(tester);

    final cardTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('calendar-event-no-time')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join('\n');
    expect(RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(cardTexts), isFalse);
  });

  testWidgets(
    'overdue unavailable banner is shown when schedule unconfigured',
    (tester) async {
      final unavailable = FakeCalendarRepository(
        rangeResult: sampleRangeSummary(
          overdueState: CalendarOverdueOutsideRangeState.scheduleUnconfigured,
        ),
        listResult: sampleEventList(overdueRows: const []),
      );
      await _pumpScreen(tester, repo: unavailable);
      await _revealAgenda(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('calendar-overdue-unavailable')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('calendar-overdue-unavailable')),
        findsOneWidget,
      );
    },
  );

  testWidgets('overdue retry recovers and exposes load-more', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        overdueRows: const [],
        hasMoreInRange: true,
        nextCursorInRange: 'in-1',
        hasMoreOverdue: true,
        nextCursorOverdue: 'od-1',
      ),
      listErrorWhenIncludeOverdue: const CalendarException(
        code: CalendarException.notAvailable,
      ),
    );
    late ProviderContainer container;
    await _setDesktopSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthController(_session()),
          ),
          calendarRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CalendarScreen(),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final state = container.read(calendarControllerProvider);
    expect(state.hasMoreInRange, isTrue);
    expect(state.overdueErrorCode, CalendarException.notAvailable);

    await _revealAgenda(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('calendar-retry-overdue')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('calendar-retry-overdue')), findsOneWidget);

    repo.listErrorWhenIncludeOverdue = null;
    repo.listResult = sampleEventList(
      overdueRows: [sampleCalendarEvent(id: 'od-1')],
      hasMoreOverdue: true,
      nextCursorOverdue: 'od-1',
    );
    await tester.tap(find.byKey(const Key('calendar-retry-overdue')));
    await tester.pumpAndSettle();
    expect(container.read(calendarControllerProvider).hasMoreOverdue, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const Key('calendar-load-more-overdue')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('calendar-load-more-overdue')), findsOneWidget);
  });

  testWidgets('partial summary / agenda / overdue failures surface retries', (
    tester,
  ) async {
    final repo = FakeCalendarRepository(
      rangeError: const CalendarException(code: CalendarException.notAvailable),
      listError: const CalendarException(
        code: CalendarException.malformedResponse,
      ),
    );
    await _pumpScreen(tester, repo: repo);
    expect(find.byKey(const Key('calendar-retry-summary')), findsOneWidget);
    await _revealAgenda(tester);
    expect(find.byKey(const Key('calendar-retry-agenda')), findsOneWidget);
  });

  testWidgets(
    'event menu shows view keys; assign/reschedule absent; directions badge',
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
              directionsAvailable: true,
              availableActions: const CalendarAvailableActions(
                canViewCustomer: true,
                canViewContract: true,
                canAssign: false,
                canReschedule: false,
                canCreateManual: false,
                canOpenDirections: true,
              ),
            ),
            sampleCalendarEvent(
              id: 'no-dir',
              directionsAvailable: true,
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

      // Actions live in the menu, not inline on the card.
      expect(
        find.byKey(const Key('calendar-view-customer-nav-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('calendar-directions-nav-1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('calendar-directions-no-dir')), findsNothing);

      // Directions indicator is never a Button.
      expect(
        find.descendant(
          of: find.byKey(const Key('calendar-directions-nav-1')),
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
      );

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

      expect(find.textContaining('Assign'), findsNothing);
      // Status enum label "Rescheduled" may appear; mutation action buttons must not.
      expect(find.widgetWithText(TextButton, 'Reschedule'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Reschedule'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Assign'), findsNothing);
    },
  );

  testWidgets('1280 and narrow widths both paint compact toolbar', (
    tester,
  ) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    await _pumpScreen(tester, repo: repo, size: const Size(1280, 1800));
    expect(find.byKey(const Key('calendar-month-title')), findsOneWidget);
    expect(find.byKey(const Key('calendar-filter-toolbar')), findsOneWidget);

    await _pumpScreen(tester, repo: repo, size: const Size(1000, 1800));
    expect(find.byKey(const Key('calendar-filter-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('calendar-filters-collapsed')), findsNothing);
  });

  testWidgets('textScale 1.5 with long EN and AR titles does not overflow', (
    tester,
  ) async {
    final longEn =
        'Very long calendar refill title that should wrap carefully without '
        'overflowing the agenda card layout under large text scale';
    final longAr =
        'عنوان تعبئة طويل جداً يجب أن يلتف بشكل آمن دون تجاوز حدود البطاقة '
        'عند تكبير النص';

    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        inRangeRows: [
          sampleCalendarEvent(id: 'long-en', titleEn: longEn, titleAr: longAr),
        ],
        overdueRows: const [],
      ),
      eventCountForDate: (d) => d.day == 14 ? 9999 : 0,
    );

    await _pumpScreen(
      tester,
      repo: repo,
      textScale: 1.5,
      size: const Size(1280, 1800),
    );
    expect(tester.takeException(), isNull);

    await _pumpScreen(
      tester,
      repo: repo,
      locale: const Locale('ar'),
      textScale: 1.5,
      size: const Size(1280, 1800),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large agenda lists render without overflow exceptions', (
    tester,
  ) async {
    final many = List.generate(
      40,
      (i) => sampleCalendarEvent(
        id: 'row-$i',
        titleEn: 'Event $i with a reasonably long English label',
        titleAr: 'حدث رقم $i بعنوان طويل نسبياً للتحقق من التخطيط',
      ),
    );
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(inRangeRows: many, overdueRows: const []),
      eventCountForDate: (_) => 2500,
    );
    await _pumpScreen(tester, repo: repo, size: const Size(1280, 2400));
    await _revealAgenda(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('calendar-event-row-0')), findsOneWidget);
  });
}
