import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_settings_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/presentation/calendar_settings_controller.dart';
import 'package:hs360/features/calendar/presentation/calendar_settings_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_calendar_settings_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  final AppSession _session;

  @override
  FutureOr<AppSession?> build() => _session;
}

AppSession _editorSession() {
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
      permissions: {'settings.calendar.edit'},
    ),
  );
}

List<WorkingDayRow> _validDays() {
  return List.generate(
    7,
    (index) =>
        WorkingDayRow(isoWeekday: index + 1, mode: TenantWorkingDayMode.dayOff),
  );
}

void main() {
  testWidgets('dirty settings PopScope sets canPop false and discard leaves', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        canEdit: true,
        days: _validDays(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthController(_editorSession()),
          ),
          calendarSettingsRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CalendarSettingsScreen(),
                        ),
                      );
                    },
                    child: const Text('open-settings'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-settings'));
    await tester.pumpAndSettle();

    PopScope<Object?> readPopScope() {
      return tester.widget<PopScope<Object?>>(
        find.byWidgetPredicate((w) => w is PopScope),
      );
    }

    expect(readPopScope().canPop, isTrue);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CalendarSettingsScreen)),
    );
    container
        .read(calendarSettingsControllerProvider.notifier)
        .updateRemindEventWorkdayStart(false);
    await tester.pumpAndSettle();

    expect(container.read(calendarSettingsControllerProvider).isDirty, isTrue);
    expect(readPopScope().canPop, isFalse);

    final onPop = readPopScope().onPopInvokedWithResult;
    expect(onPop, isNotNull);
    onPop!(false, null);
    await tester.pumpAndSettle();

    expect(find.text(l10n.calendarSettingsUnsavedTitle), findsOneWidget);

    await tester.tap(find.text(l10n.calendarSettingsDiscard));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarSettingsScreen), findsNothing);
    expect(find.text('open-settings'), findsOneWidget);
  });
}
