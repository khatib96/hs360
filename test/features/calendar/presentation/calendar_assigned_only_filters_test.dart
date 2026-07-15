import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
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
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
  await tester.dragUntilVisible(find.byKey(key), list, const Offset(0, -80));
  await tester.pumpAndSettle();
}

Future<void> _assertFilterKeyAbsent(WidgetTester tester, Key key) async {
  final list = find.descendant(
    of: find.byKey(const Key('calendar-filter-popover')),
    matching: find.byType(Scrollable),
  );
  // Scroll through the panel; assigned-only must never materialize the key.
  for (var i = 0; i < 20; i++) {
    if (find.byKey(key).evaluate().isNotEmpty) break;
    await tester.drag(list, const Offset(0, -120));
    await tester.pump();
  }
  expect(find.byKey(key), findsNothing);
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required AppSession session,
  required FakeCalendarRepository repo,
  Size size = const Size(1280, 900),
}) async {
  await _setDesktopSurface(tester, size: size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _TestAuthController(session)),
        calendarRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CalendarScreen(),
      ),
    ),
  );
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

  testWidgets(
    'assigned-only never shows unassigned in funnel while summary delayed',
    (tester) async {
      final holdSummary = Completer<void>();
      final repo = FakeCalendarRepository(
        listResult: sampleEventList(overdueRows: const []),
        rangeScope: CalendarReadScope.assignedOnly,
        rangeUnassignedCount: null,
      )..holdSummaryUntil = holdSummary;

      await _setDesktopSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _TestAuthController(
                _session(permissions: {'calendar.view_assigned'}),
              ),
            ),
            calendarRepositoryProvider.overrideWith((ref) => repo),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CalendarScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      await _openFilterPopover(tester, settle: false);
      await _assertFilterKeyAbsent(
        tester,
        const Key('calendar-filter-unassigned'),
      );
      expect(find.byKey(const Key('calendar-filter-agent')), findsNothing);

      // Dismiss so we can settle after summary completes.
      await tester.tapAt(const Offset(8, 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      holdSummary.complete();
      await tester.pumpAndSettle();

      await _openFilterPopover(tester);
      await _assertFilterKeyAbsent(
        tester,
        const Key('calendar-filter-unassigned'),
      );
      expect(find.byKey(const Key('calendar-filter-agent')), findsNothing);
    },
  );

  testWidgets('tenant calendar.view shows unassigned in funnel, never agent', (
    tester,
  ) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    await _pumpCalendar(
      tester,
      session: _session(permissions: {'calendar.view', 'warehouses.view'}),
      repo: repo,
    );

    await _openFilterPopover(tester);
    await _ensureFilterKeyVisible(
      tester,
      const Key('calendar-filter-unassigned'),
    );
    expect(find.byKey(const Key('calendar-filter-unassigned')), findsOneWidget);
    expect(find.byKey(const Key('calendar-filter-agent')), findsNothing);
  });

  testWidgets(
    'calendar.view without warehouses.view still shows unassigned in funnel',
    (tester) async {
      final repo = FakeCalendarRepository(
        listResult: sampleEventList(overdueRows: const []),
      );
      await _pumpCalendar(
        tester,
        session: _session(permissions: {'calendar.view'}),
        repo: repo,
      );

      await _openFilterPopover(tester);
      await _ensureFilterKeyVisible(
        tester,
        const Key('calendar-filter-unassigned'),
      );
      expect(
        find.byKey(const Key('calendar-filter-unassigned')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('calendar-filter-agent')), findsNothing);
    },
  );
}
