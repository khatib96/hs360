import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_working_date_exception_repository.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_working_date_exceptions_section.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_working_date_exception_repository.dart';

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

Widget _buildApp({
  required AppSession session,
  required FakeWorkingDateExceptionRepository repo,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _TestAuthController(session)),
      calendarWorkingDateExceptionRepositoryProvider.overrideWith(
        (ref) => repo,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SingleChildScrollView(
          child: CalendarWorkingDateExceptionsSection(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows permission denied banner without settings.calendar.view', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        session: _session(),
        repo: FakeWorkingDateExceptionRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      find.text(l10n.calendarWorkingDateExceptionsPermissionDenied),
      findsOneWidget,
    );
    expect(find.byKey(const Key('calendar-wde-add')), findsNothing);
  });

  testWidgets('shows empty state for a viewer with no exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        session: _session(permissions: {'settings.calendar.view'}),
        repo: FakeWorkingDateExceptionRepository(
          listResult: sampleWorkingDateExceptionList(items: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-wde-empty')), findsOneWidget);
    expect(find.byKey(const Key('calendar-wde-add')), findsNothing);
  });

  testWidgets('renders a list tile for an editor and allows adding', (
    tester,
  ) async {
    final repo = FakeWorkingDateExceptionRepository(
      listResult: sampleWorkingDateExceptionList(
        items: [sampleWorkingDateException(id: 'wde-1')],
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        session: _session(permissions: {'settings.calendar.edit'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-wde-tile-wde-1')), findsOneWidget);
    expect(find.byKey(const Key('calendar-wde-add')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-wde-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-wde-create-dialog')), findsOneWidget);
  });

  testWidgets('create dialog validates before submitting', (tester) async {
    final repo = FakeWorkingDateExceptionRepository(
      listResult: sampleWorkingDateExceptionList(items: const []),
    );
    await tester.pumpWidget(
      _buildApp(
        session: _session(permissions: {'settings.calendar.edit'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-wde-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-wde-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-wde-form-error')), findsOneWidget);
    expect(repo.createCount, 0);
  });

  testWidgets('create dialog surfaces an overlap error inline and stays open', (
    tester,
  ) async {
    final repo = FakeWorkingDateExceptionRepository(
      listResult: sampleWorkingDateExceptionList(items: const []),
      createError: const CalendarException(
        code: CalendarException.workingDateExceptionOverlap,
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        session: _session(permissions: {'settings.calendar.edit'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-wde-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar-wde-title-ar')),
      'عطلة',
    );
    await tester.tap(find.byKey(const Key('calendar-wde-kind')));
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(
      find.text(l10n.calendarWorkingDateExceptionKindOfficialHoliday).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-wde-start-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-wde-end-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-wde-submit')));
    await tester.pumpAndSettle();

    // A hard failure keeps the dialog open with an inline mutation error so
    // the user doesn't lose their form input.
    expect(find.byKey(const Key('calendar-wde-create-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-wde-mutation-error')),
      findsOneWidget,
    );
    expect(repo.createCount, 1);
  });

  testWidgets('cancel dialog requires a reason then cancels', (tester) async {
    final repo = FakeWorkingDateExceptionRepository(
      listResult: sampleWorkingDateExceptionList(
        items: [sampleWorkingDateException(id: 'wde-1')],
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        session: _session(permissions: {'settings.calendar.edit'}),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-wde-cancel-wde-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-wde-cancel-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-wde-cancel-dialog')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('calendar-wde-cancel-reason-field')),
      'No longer needed',
    );
    await tester.tap(find.byKey(const Key('calendar-wde-cancel-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-wde-cancel-dialog')), findsNothing);
    expect(repo.cancelCount, 1);
    expect(repo.lastReason, 'No longer needed');
  });
}
