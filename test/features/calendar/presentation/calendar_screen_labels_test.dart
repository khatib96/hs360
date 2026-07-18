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

AppSession _session() {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: const {'calendar.view'},
    ),
  );
}

Widget _buildApp({
  required FakeCalendarRepository repo,
  required Locale locale,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => _TestAuthController(_session()),
      ),
      calendarRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CalendarScreen(),
    ),
  );
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

  testWidgets('EN shows localized type label, not raw refill_due', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        inRangeRows: [sampleCalendarEvent(id: 'ev-1')],
        overdueRows: const [],
      ),
    );

    // Tall desktop surface so Month+Agenda builds the event card (not only
    // the grid above the fold on the default 800×600 viewport).
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp(repo: repo, locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.textContaining(l10n.calendarEventTypeRefillDue), findsWidgets);
    expect(find.textContaining('refill_due'), findsNothing);
  });

  testWidgets('AR shows localized type label, not raw refill_due', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final repo = FakeCalendarRepository(
      listResult: sampleEventList(
        inRangeRows: [sampleCalendarEvent(id: 'ev-1')],
        overdueRows: const [],
      ),
    );

    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp(repo: repo, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.textContaining(l10n.calendarEventTypeRefillDue), findsWidgets);
    expect(find.textContaining('refill_due'), findsNothing);
  });
}
