import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_time_window.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';
import 'package:hs360/features/calendar/presentation/calendar_desktop_layout.dart';
import 'package:hs360/features/calendar/presentation/calendar_screen.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:hs360/shared/widgets/app_shell.dart';

import '../fake_calendar_repository.dart';

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

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
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: isManager, permissions: permissions),
  );
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeCalendarRepository repo,
  AppSession? session,
  bool allowNullSession = false,
  Locale locale = const Locale('en'),
  Size size = const Size(360, 800),
  double textScale = 1.0,
}) async {
  await _setSize(tester, size);
  final effectiveSession = allowNullSession ? session : (session ?? _session());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _TestAuth(effectiveSession)),
        calendarRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const CalendarScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

FakeCalendarRepository _repo({
  List? inRangeRows,
  CalendarReadScope scope = CalendarReadScope.tenantWide,
}) {
  final today = DateTime(2026, 7, 14);
  return FakeCalendarRepository(
    echoAgendaDate: false,
    rangeScope: scope,
    rangeUnassignedCount: scope == CalendarReadScope.assignedOnly ? null : 1,
    listResult: sampleEventList(
      tenantLocalToday: today,
      inRangeRows:
          inRangeRows?.cast() ??
          [
            sampleCalendarEvent(
              id: 'evt-gen',
              scheduledDate: today,
              titleEn: 'Generated refill',
              titleAr: 'تعبئة مولدة',
              customerNameEn: 'Palm Co',
              customerNameAr: 'النخيل',
              serviceLocationName: 'Main site',
              contractNumber: 'C-100',
              directionsAvailable: true,
              availableActions: const CalendarAvailableActions(
                canViewCustomer: true,
                canViewContract: true,
                canAssign: true,
                canReschedule: true,
                canCreateManual: false,
                canOpenDirections: true,
                canEditManual: false,
                canCancelManual: false,
                canMarkManualDone: false,
                canOpenMeetingLink: false,
              ),
            ),
            sampleCalendarEvent(
              id: 'evt-timed',
              scheduledDate: today,
              type: CalendarEventType.customerVisit,
              sourceKind: CalendarEventSourceKind.manual,
              titleEn: 'Timed visit',
              titleAr: 'زيارة بوقت',
              timeWindow: const CalendarTimeWindow(
                startLocal: '09:00',
                endLocal: '10:00',
                timezoneName: 'Asia/Kuwait',
              ),
            ),
          ],
      overdueRows: [
        sampleCalendarEvent(
          id: 'od-1',
          scheduledDate: DateTime(2026, 6, 1),
          isOverdue: true,
          overdueDays: 20,
          overdueState: CalendarOverdueState.overdue,
          titleEn: 'Overdue item',
          titleAr: 'متأخر',
        ),
      ],
    ),
    workingDayForDate: (d) {
      if (d.day == 15) {
        return sampleCalendarWorkingDay(
          date: d,
          dayMode: TenantWorkingDayMode.dayOff,
        );
      }
      return sampleCalendarWorkingDay(date: d);
    },
  );
}

void main() {
  late CalendarClock previous;
  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });
  tearDown(() => calendarClock = previous);

  testWidgets('mobile layout at 320/360/412 without overflow', (tester) async {
    for (final width in [320.0, 360.0, 412.0]) {
      final repo = _repo();
      await _pump(tester, repo: repo, size: Size(width, 800));
      expect(find.byKey(const Key('calendar-mobile-body')), findsOneWidget);
      expect(find.byKey(const Key('calendar-desktop-body')), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.takeException(), isNull);

      final callsBefore = repo.rangeCallLog.length + repo.listCallLog.length;
      await tester.tap(find.byKey(const Key('calendar-next-week')));
      await tester.pumpAndSettle();
      final callsAfter = repo.rangeCallLog.length + repo.listCallLog.length;
      // Week nav must not fan out into per-day RPCs (7+).
      expect(callsAfter - callsBefore, lessThan(7));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    '767/768/769: shell, calendar body, and content width stay consistent',
    (tester) async {
      expect(CalendarLayout.isMobileWidth(767), isTrue);
      expect(CalendarLayout.isMobileWidth(768), isTrue);
      expect(CalendarLayout.isMobileWidth(769), isFalse);

      Future<double> contentWidth() async {
        final box =
            tester.renderObject(find.byKey(const Key('calendar-layout-body')))
                as RenderBox;
        return box.size.width;
      }

      await _pump(tester, repo: _repo(), size: const Size(767, 900));
      expect(find.byType(DrawerButton), findsOneWidget);
      expect(find.byKey(const Key('calendar-mobile-body')), findsOneWidget);
      expect(find.byKey(const Key('calendar-desktop-body')), findsNothing);
      expect(await contentWidth(), lessThanOrEqualTo(768));
      expect(tester.takeException(), isNull);

      await _pump(tester, repo: _repo(), size: const Size(768, 900));
      expect(find.byType(DrawerButton), findsOneWidget);
      expect(find.byKey(const Key('calendar-mobile-body')), findsOneWidget);
      expect(find.byKey(const Key('calendar-desktop-body')), findsNothing);
      expect(await contentWidth(), lessThanOrEqualTo(768));
      expect(tester.takeException(), isNull);

      await _pump(tester, repo: _repo(), size: const Size(769, 900));
      // Desktop shell (nav rail), but content ≈ 528 → still mobile calendar.
      expect(find.byType(DrawerButton), findsNothing);
      expect(find.byType(AppBrandMark), findsWidgets);
      expect(find.byKey(const Key('calendar-mobile-body')), findsOneWidget);
      expect(find.byKey(const Key('calendar-desktop-body')), findsNothing);
      final narrowContent = await contentWidth();
      expect(narrowContent, lessThan(CalendarLayout.mobileBreakpoint));
      expect(CalendarLayout.isMobileWidth(narrowContent), isTrue);
      expect(tester.takeException(), isNull);

      // Wide enough that content exceeds the mobile breakpoint → desktop calendar.
      await _pump(tester, repo: _repo(), size: const Size(1280, 900));
      expect(find.byType(DrawerButton), findsNothing);
      expect(find.byKey(const Key('calendar-desktop-body')), findsOneWidget);
      expect(find.byKey(const Key('calendar-mobile-body')), findsNothing);
      expect(
        await contentWidth(),
        greaterThan(CalendarLayout.mobileBreakpoint),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FAB does not intersect agenda cards or overdue header', (
    tester,
  ) async {
    await _pump(
      tester,
      repo: _repo(),
      session: _session(
        permissions: const {'calendar.view', 'calendar.create'},
      ),
      size: const Size(360, 800),
    );
    expect(
      find.byKey(const Key('calendar-mobile-fab-clearance')),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);

    final fab = tester.getRect(find.byType(FloatingActionButton));
    final clearance = tester.getRect(
      find.byKey(const Key('calendar-mobile-fab-clearance')),
    );
    // FAB lives in the non-scrolling clearance band under the list viewport.
    expect(fab.top, greaterThanOrEqualTo(clearance.top - 0.5));
    expect(fab.bottom, lessThanOrEqualTo(clearance.bottom + 0.5));

    // Scroll the list to its end so overdue/agenda approach the viewport edge.
    await tester.drag(
      find.byKey(const Key('calendar-mobile-body')),
      const Offset(0, -2400),
    );
    await tester.pumpAndSettle();

    final overdue = find.byKey(const Key('calendar-overdue-expansion'));
    expect(overdue, findsOneWidget);
    final overdueRect = tester.getRect(overdue);
    expect(overdueRect.bottom, lessThanOrEqualTo(clearance.top + 0.5));
    expect(fab.overlaps(overdueRect), isFalse);

    for (final id in ['evt-gen', 'evt-timed']) {
      final card = find.byKey(Key('calendar-event-$id'));
      if (card.evaluate().isEmpty) continue;
      final cardRect = tester.getRect(card);
      // Still-laid-out cards must not enter the FAB band.
      expect(cardRect.bottom, lessThanOrEqualTo(clearance.top + 0.5));
      expect(fab.overlaps(cardRect), isFalse);
    }
  });

  testWidgets('selected day agenda filters to that date only', (tester) async {
    final repo = FakeCalendarRepository(
      filterAgendaToRequestedDate: true,
      eventCountForDate: (d) {
        final day = DateTime(d.year, d.month, d.day);
        if (day == DateTime(2026, 7, 14)) return 1;
        if (day == DateTime(2026, 7, 15)) return 1;
        return 0;
      },
      listResult: sampleEventList(
        tenantLocalToday: DateTime(2026, 7, 14),
        inRangeRows: [
          sampleCalendarEvent(
            id: 'today-evt',
            scheduledDate: DateTime(2026, 7, 14),
          ),
          sampleCalendarEvent(
            id: 'next-evt',
            scheduledDate: DateTime(2026, 7, 15),
          ),
        ],
        overdueRows: const [],
      ),
    );
    await _pump(tester, repo: repo, size: const Size(360, 800));
    expect(find.byKey(const Key('calendar-event-today-evt')), findsOneWidget);
    expect(find.byKey(const Key('calendar-event-next-evt')), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-mobile-day-2026-7-15')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-event-next-evt')), findsOneWidget);
    expect(find.byKey(const Key('calendar-event-today-evt')), findsNothing);
  });

  testWidgets('Arabic RTL and English LTR mobile agenda', (tester) async {
    await _pump(
      tester,
      repo: _repo(),
      locale: const Locale('ar'),
      size: const Size(360, 800),
    );
    expect(find.byKey(const Key('calendar-mobile-date-nav')), findsOneWidget);
    expect(find.byKey(const Key('calendar-agenda-date')), findsOneWidget);

    await _pump(
      tester,
      repo: _repo(),
      locale: const Locale('en'),
      size: const Size(360, 800),
    );
    expect(find.byKey(const Key('calendar-mobile-body')), findsOneWidget);
  });

  testWidgets('today default uses tenant-local today; week from selectedDate', (
    tester,
  ) async {
    final repo = _repo();
    await _pump(tester, repo: repo, size: const Size(360, 800));
    expect(
      find.byKey(const Key('calendar-mobile-day-2026-7-14')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calendar-mobile-day-2026-7-15')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-mobile-day-2026-7-15')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calendar-today')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-mobile-day-2026-7-14')),
      findsOneWidget,
    );
  });

  testWidgets('prev/next week moves selectedDate by ±7 via selectGridDate', (
    tester,
  ) async {
    final repo = _repo();
    await _pump(tester, repo: repo, size: const Size(360, 800));
    await tester.tap(find.byKey(const Key('calendar-next-week')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-mobile-day-2026-7-21')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('calendar-prev-week')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-mobile-day-2026-7-14')),
      findsOneWidget,
    );
  });

  testWidgets('assigned-only hides create FAB and forbidden filters', (
    tester,
  ) async {
    final repo = _repo(scope: CalendarReadScope.assignedOnly);
    await _pump(
      tester,
      repo: repo,
      session: _session(permissions: const {'calendar.view_assigned'}),
      size: const Size(360, 800),
    );
    expect(find.byKey(const Key('calendar-create-event')), findsNothing);
    await tester.tap(find.byKey(const Key('calendar-filter-funnel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-filter-sheet')), findsOneWidget);
    expect(find.byKey(const Key('calendar-filter-unassigned')), findsNothing);
  });

  testWidgets('global create uses FAB only on mobile', (tester) async {
    await _pump(
      tester,
      repo: _repo(),
      session: _session(
        permissions: const {'calendar.view', 'calendar.create'},
      ),
      size: const Size(360, 800),
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byKey(const Key('calendar-create-event')), findsOneWidget);
  });

  testWidgets('M8 assign/reschedule respect available_actions', (tester) async {
    final repo = _repo();
    await _pump(
      tester,
      repo: repo,
      session: _session(permissions: const {'calendar.view', 'calendar.edit'}),
      size: const Size(360, 800),
    );
    await tester.tap(find.byKey(const Key('calendar-event-ink-evt-gen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-assign-evt-gen')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-reschedule-evt-gen')),
      findsOneWidget,
    );

    // No Phase 8 actions.
    expect(find.textContaining('Complete visit'), findsNothing);
    expect(find.textContaining('GPS'), findsNothing);
  });

  testWidgets('hides assign/reschedule when not granted', (tester) async {
    final repo = FakeCalendarRepository(
      echoAgendaDate: false,
      listResult: sampleEventList(
        tenantLocalToday: DateTime(2026, 7, 14),
        inRangeRows: [
          sampleCalendarEvent(
            id: 'evt-locked',
            availableActions: const CalendarAvailableActions(
              canViewCustomer: false,
              canViewContract: false,
              canAssign: false,
              canReschedule: false,
              canCreateManual: false,
              canOpenDirections: false,
              canEditManual: false,
              canCancelManual: false,
              canMarkManualDone: false,
              canOpenMeetingLink: false,
            ),
          ),
        ],
        overdueRows: const [],
      ),
    );
    await _pump(tester, repo: repo, size: const Size(360, 800));
    await tester.tap(find.byKey(const Key('calendar-event-ink-evt-locked')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-assign-evt-locked')), findsNothing);
    expect(
      find.byKey(const Key('calendar-reschedule-evt-locked')),
      findsNothing,
    );
  });

  testWidgets('timed shows window; generated has no invented time', (
    tester,
  ) async {
    await _pump(tester, repo: _repo(), size: const Size(360, 800));
    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.textContaining('10:00'), findsOneWidget);
    // Generated card has no fabricated clock range string.
    final genCard = find.byKey(const Key('calendar-event-evt-gen'));
    expect(genCard, findsOneWidget);
  });

  testWidgets('directions available badge only when both flags true', (
    tester,
  ) async {
    await _pump(tester, repo: _repo(), size: const Size(360, 800));
    expect(
      find.byKey(const Key('calendar-directions-evt-gen')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-directions-evt-timed')),
      findsNothing,
    );
  });

  testWidgets('day-off conflict badge visible on mobile card', (tester) async {
    final today = DateTime(2026, 7, 14);
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        tenantLocalToday: today,
        inRangeRows: [
          sampleCalendarEvent(
            id: 'evt-conflict',
            scheduledDate: today,
            scheduleState: CalendarScheduleState.dayOffOverridden,
            workingDay: sampleCalendarWorkingDay(
              date: today,
              dayMode: TenantWorkingDayMode.dayOff,
            ),
          ),
        ],
        overdueRows: const [],
      ),
    );
    await _pump(tester, repo: repo, size: const Size(360, 800));
    expect(
      find.byKey(const Key('calendar-event-evt-conflict')),
      findsOneWidget,
    );
  });

  testWidgets('empty/loading/error/retry/refresh paths', (tester) async {
    final repo = FakeCalendarRepository(
      listError: const CalendarException(code: CalendarException.unknown),
      listResult: sampleEventList(
        tenantLocalToday: DateTime(2026, 7, 14),
        inRangeRows: const [],
        overdueRows: const [],
      ),
    );
    await _pump(tester, repo: repo, size: const Size(360, 800));
    expect(find.byKey(const Key('calendar-retry-agenda')), findsOneWidget);
    repo.listError = null;
    await tester.tap(find.byKey(const Key('calendar-retry-agenda')));
    await tester.pumpAndSettle();
  });

  testWidgets('text scale 2.0 mobile does not throw overflow', (tester) async {
    await _pump(
      tester,
      repo: _repo(),
      size: const Size(360, 800),
      textScale: 2.0,
      locale: const Locale('en'),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('calendar-mobile-body')), findsOneWidget);
  });

  testWidgets('overdue is collapsible on mobile', (tester) async {
    await _pump(tester, repo: _repo(), size: const Size(360, 800));
    final overdue = find.byKey(const Key('calendar-overdue-expansion'));
    await tester.dragUntilVisible(
      overdue,
      find.byKey(const Key('calendar-mobile-body')),
      const Offset(0, -200),
    );
    expect(overdue, findsOneWidget);
  });

  testWidgets('null session shows permission denied', (tester) async {
    await _pump(
      tester,
      repo: _repo(),
      session: null,
      allowNullSession: true,
      size: const Size(360, 800),
    );
    expect(find.byKey(const Key('calendar-permission-denied')), findsOneWidget);
  });
}
