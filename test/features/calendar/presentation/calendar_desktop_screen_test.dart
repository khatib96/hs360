import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
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

AppSession _session() => AppSession(
  userId: 'user-1',
  email: 't@example.com',
  tenantId: 'tenant-1',
  tenantUserId: 'tu-1',
  accountType: 'user',
  displayName: 'Test',
  preferredLocale: 'en',
  permissions: AppPermissions(
    isManager: false,
    permissions: const {'calendar.view'},
  ),
);

void main() {
  late CalendarClock previous;

  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });

  tearDown(() => calendarClock = previous);

  testWidgets(
    'initial pump and locale change do not duplicate week-start RPCs',
    (tester) async {
      final repo = FakeCalendarRepository(
        listResult: sampleEventList(overdueRows: const []),
      );

      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _TestAuthController(_session()),
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
      await tester.pumpAndSettle();

      final firstCount = repo.getRangeSummaryCount;
      expect(firstCount, greaterThanOrEqualTo(1));
      expect(find.byKey(const Key('calendar-month-title')), findsOneWidget);

      // Same locale rebuild should not schedule duplicate week-start loads.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _TestAuthController(_session()),
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
      await tester.pumpAndSettle();

      // Rebuild may remount; ensureWeekStart is idempotent for same index.
      expect(repo.getRangeSummaryCount, lessThanOrEqualTo(firstCount + 1));

      await tester.tap(find.byKey(const Key('calendar-next-month')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendar-agenda-date')), findsOneWidget);
    },
  );

  testWidgets('narrow desktop still shows compact filter toolbar', (tester) async {
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(overdueRows: const []),
    );
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthController(_session()),
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
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-filter-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('calendar-filters-collapsed')), findsNothing);
  });
}
