import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_event.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_manual_mutation.dart';
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
  String tenantUserId = 'tu-1',
  Set<String> permissions = const {'calendar.view', 'calendar.edit'},
}) {
  return AppSession(
    userId: userId,
    email: 'test@example.com',
    tenantId: tenantId,
    tenantUserId: tenantUserId,
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

CalendarEvent _manualEvent({String id = 'manual-1', int version = 2}) {
  return sampleCalendarEvent(
    id: id,
    scheduleVersion: version,
    sourceKind: CalendarEventSourceKind.manual,
    type: CalendarEventType.internalMeeting,
  );
}

void main() {
  testWidgets(
    'delayed cancel after tenant switch does not snackbar or refresh new identity',
    (tester) async {
      final repo = FakeCalendarRepository()
        ..holdCancelManualUntil = Completer<void>();
      final auth = _TestAuthController(_session());
      final container = await _pumpHost(tester, repo: repo, auth: auth);
      await _boot(tester, container);

      final future = container
          .read(calendarControllerProvider.notifier)
          .cancelManualEvent(_manualEvent(), reason: 'Customer cancelled');
      await tester.pump();

      auth.setSession(_session(tenantId: 'tenant-2'));
      await tester.pump();
      repo.holdCancelManualUntil!.complete();
      final ok = await future;
      await tester.pumpAndSettle();

      expect(ok, isFalse);
      expect(repo.cancelManualCount, 1);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'delayed mark-done after tenantUserId switch discards result silently',
    (tester) async {
      final repo = FakeCalendarRepository()
        ..holdMarkManualDoneUntil = Completer<void>();
      final auth = _TestAuthController(_session());
      final container = await _pumpHost(tester, repo: repo, auth: auth);
      await _boot(tester, container);

      final future = container
          .read(calendarControllerProvider.notifier)
          .markManualDone(_manualEvent());
      await tester.pump();

      auth.setSession(_session(tenantUserId: 'tu-2'));
      await tester.pump();
      repo.holdMarkManualDoneUntil!.complete();
      final ok = await future;
      await tester.pumpAndSettle();

      expect(ok, isFalse);
      expect(repo.markManualDoneCount, 1);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'delayed create after userId switch does not show success snackbar',
    (tester) async {
      final repo = FakeCalendarRepository()
        ..holdCreateManualUntil = Completer<void>();
      final auth = _TestAuthController(_session());
      final container = await _pumpHost(tester, repo: repo, auth: auth);
      await _boot(tester, container);

      final data = CalendarManualEventData(
        type: CalendarEventType.internalMeeting,
        scheduledDate: DateTime(2026, 7, 14),
        titleAr: 'يدوي',
        titleEn: 'Manual',
      );
      final future = container
          .read(calendarControllerProvider.notifier)
          .createManualEvent(_hostContext, data);
      await tester.pump();

      auth.setSession(_session(userId: 'user-2'));
      await tester.pump();
      repo.holdCreateManualUntil!.complete();
      final ok = await future;
      await tester.pumpAndSettle();

      expect(ok, isFalse);
      expect(repo.createManualCount, 1);
      expect(find.byType(SnackBar), findsNothing);
    },
  );
}
