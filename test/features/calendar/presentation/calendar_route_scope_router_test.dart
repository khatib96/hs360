import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/core/routing/app_routes.dart';
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
}) {
  return AppSession(
    userId: userId,
    email: 'test@example.com',
    tenantId: tenantId,
    tenantUserId: tenantUserId,
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: {'calendar.view'},
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

  testWidgets(
    'tenant switch strips scoped calendar URL and clears route scope',
    (tester) async {
      final auth = _TestAuthController(_session());
      final holdSummary = Completer<void>();
      final holdAgenda = Completer<void>();
      final holdOverdue = Completer<void>();
      final repo =
          FakeCalendarRepository(
              listResult: sampleEventList(
                inRangeRows: [sampleCalendarEvent(id: 'tenant-a-event')],
              ),
            )
            ..holdSummaryUntil = holdSummary
            ..holdAgendaUntil = holdAgenda
            ..holdOverdueUntil = holdOverdue;

      final customerId = '11111111-1111-4111-8111-111111111111';
      final router = GoRouter(
        initialLocation: AppRoutes.calendarPath(customerId: customerId),
        routes: [
          GoRoute(
            path: AppRoutes.calendar,
            builder: (context, state) => CalendarScreen(
              customerIdQueryParam: state.uri.queryParameters['customerId'],
              contractIdQueryParam: state.uri.queryParameters['contractId'],
              dateQueryParam: state.uri.queryParameters['date'],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => auth),
            calendarRepositoryProvider.overrideWith((ref) => repo),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(router.state.uri.queryParameters['customerId'], customerId);
      expect(
        find.byKey(const Key('calendar-route-scope-banner')),
        findsOneWidget,
      );

      // Release initial loads so the controller settles before the switch.
      holdSummary.complete();
      holdAgenda.complete();
      holdOverdue.complete();
      await tester.pumpAndSettle();

      final beforeList = repo.listEventsCount;
      auth.setSession(_session(tenantId: 'tenant-b', userId: 'user-b'));
      await tester.pumpAndSettle();

      expect(
        router.state.uri.queryParameters.containsKey('customerId'),
        isFalse,
      );
      expect(router.state.uri.path, AppRoutes.calendar);
      expect(
        find.byKey(const Key('calendar-route-scope-banner')),
        findsNothing,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CalendarScreen)),
      );
      expect(
        container.read(calendarControllerProvider).routeScope.isEmpty,
        isTrue,
      );
      // Stale scoped responses must not keep driving reads for the old scope.
      expect(repo.listEventsCount >= beforeList, isTrue);
    },
  );

  testWidgets('date-only query focuses without showing the scope banner', (
    tester,
  ) async {
    final repo = FakeCalendarRepository();
    final router = GoRouter(
      initialLocation: AppRoutes.calendarPath(date: DateTime(2026, 8, 20)),
      routes: [
        GoRoute(
          path: AppRoutes.calendar,
          builder: (context, state) => CalendarScreen(
            customerIdQueryParam: state.uri.queryParameters['customerId'],
            contractIdQueryParam: state.uri.queryParameters['contractId'],
            dateQueryParam: state.uri.queryParameters['date'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthController(_session()),
          ),
          calendarRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-route-scope-banner')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CalendarScreen)),
    );
    final state = container.read(calendarControllerProvider);
    expect(state.selectedDate, DateTime(2026, 8, 20));
    expect(state.routeScope.showsBanner, isFalse);
  });
}
