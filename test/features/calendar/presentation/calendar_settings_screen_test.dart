import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_settings_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/presentation/calendar_settings_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_calendar_settings_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  final AppSession _session;

  @override
  FutureOr<AppSession?> build() => _session;
}

AppSession _session({Set<String> permissions = const {}}) {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

List<WorkingDayRow> _validDays() {
  return List.generate(
    7,
    (index) =>
        WorkingDayRow(isoWeekday: index + 1, mode: TenantWorkingDayMode.dayOff),
  );
}

Widget _buildApp({
  required AppSession appSession,
  required FakeCalendarSettingsRepository repo,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => _TestAuthController(appSession),
      ),
      calendarSettingsRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CalendarSettingsScreen(),
    ),
  );
}

Finder fieldKey(String name) => find.byKey(Key(name), skipOffstage: false);

Finder get _settingsListView => find.byKey(const Key('calendar-settings-list'));

Future<void> scrollToField(WidgetTester tester, String keyName) async {
  final target = fieldKey(keyName);
  for (var attempt = 0; attempt < 30; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(_settingsListView, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  fail('Could not scroll to $keyName');
}

void main() {
  testWidgets('shows permission denied without calendar permission', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      _buildApp(appSession: _session(), repo: FakeCalendarSettingsRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.calendarSettingsPermissionDenied), findsOneWidget);
  });

  testWidgets('renders setup banner and fields for viewer', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        legacyTimezoneSuggestion: 'Asia/Kuwait',
        workingScheduleConfigured: false,
        canEdit: false,
        days: _validDays(),
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        appSession: _session(permissions: {'settings.calendar.view'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.calendarSettingsSetupRequired), findsOneWidget);
    expect(fieldKey('calendar-settings-timezone'), findsOneWidget);
    await scrollToField(tester, 'calendar-settings-remind-event-day');
    expect(fieldKey('calendar-settings-remind-event-day'), findsOneWidget);
    expect(fieldKey('calendar-settings-save'), findsNothing);
  });

  testWidgets('save button visible for editor and persists', (tester) async {
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        canEdit: true,
        days: _validDays(),
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        appSession: _session(permissions: {'settings.calendar.edit'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await scrollToField(tester, 'calendar-settings-save');
    expect(fieldKey('calendar-settings-save'), findsOneWidget);
    await tester.tap(fieldKey('calendar-settings-save'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repo.updateCount, 1);
  });

  testWidgets('view-only user cannot edit timezone field', (tester) async {
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        canEdit: false,
        days: _validDays(),
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        appSession: _session(permissions: {'settings.calendar.view'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      fieldKey('calendar-settings-timezone'),
    );
    expect(field.enabled, isFalse);
  });

  testWidgets('renders Arabic RTL labels', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        canEdit: true,
        days: _validDays(),
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        appSession: _session(permissions: {'settings.calendar.edit'}),
        repo: repo,
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.calendarSettingsTitle), findsOneWidget);
    expect(find.text(l10n.calendarWeekdayMonday), findsOneWidget);
  });

  testWidgets('fits narrow viewport without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildApp(
        appSession: _session(permissions: {'settings.calendar.view'}),
        repo: FakeCalendarSettingsRepository(
          settings: CalendarSettings(
            timezoneName: 'Asia/Kuwait',
            canEdit: false,
            days: _validDays(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });
}
