import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_route_employee.dart';
import 'package:hs360/features/calendar/domain/calendar_route_location_state.dart';
import 'package:hs360/features/calendar/domain/calendar_route_point.dart';
import 'package:hs360/features/calendar/domain/calendar_route_result.dart';
import 'package:hs360/features/calendar/presentation/calendar_directions_providers.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_app_resolver.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_surface.dart';
import 'package:hs360/features/calendar/presentation/calendar_route_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_calendar_repository.dart';
import '../fake_calendar_route_repository.dart';

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _assignedSession() {
  return AppSession(
    userId: 'user-1',
    email: 't@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: const {'calendar.view_assigned'},
    ),
  );
}

CalendarMapSurface _fakeMapSurfaceBuilder({
  required List<CalendarRoutePoint> points,
  required String? selectedEventId,
  required ValueChanged<String> onSelectEvent,
  required VoidCallback onTileFailure,
  required int tileSessionId,
}) {
  return FakeCalendarMapSurface(
    points: points,
    selectedEventId: selectedEventId,
    onSelectEvent: onSelectEvent,
    groupSameCoordinates: true,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeCalendarRepository repo,
  AppSession? session,
  String? dateQueryParam,
}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuth(session ?? _assignedSession()),
        ),
        calendarRepositoryProvider.overrideWith((ref) => repo),
        calendarMapAppResolverProvider.overrideWithValue(
          CalendarMapAppResolver(canLaunch: (_) async => true),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CalendarRouteScreen(
          dateQueryParam: dateQueryParam,
          mapSurfaceBuilder: _fakeMapSurfaceBuilder,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Color? _markerColor(WidgetTester tester, String eventId) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(Key('calendar-map-marker-$eventId')),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('tapping a list row selects it and highlights its marker', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..routeDayResult = CalendarRouteResult(
        date: DateTime(2026, 7, 14),
        employeeId: 'tu-1',
        points: [
          sampleRoutePoint(eventId: 'a', latitude: 1, longitude: 1),
          sampleRoutePoint(eventId: 'b', latitude: 2, longitude: 2),
        ],
        hasMore: false,
      );

    await _pump(tester, repo: repo, dateQueryParam: '2026-07-14');

    final beforeA = _markerColor(tester, 'a');
    final beforeB = _markerColor(tester, 'b');
    expect(beforeA, beforeB); // neither selected yet

    await tester.tap(find.byKey(const Key('calendar-route-point-ink-b')));
    await tester.pumpAndSettle();

    expect(_markerColor(tester, 'b'), isNot(beforeB));
    expect(_markerColor(tester, 'a'), beforeA);
  });

  testWidgets('tapping a marker selects the matching list row', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..routeDayResult = CalendarRouteResult(
        date: DateTime(2026, 7, 14),
        employeeId: 'tu-1',
        points: [
          sampleRoutePoint(eventId: 'a', latitude: 1, longitude: 1),
          sampleRoutePoint(eventId: 'b', latitude: 2, longitude: 2),
        ],
        hasMore: false,
      );

    await _pump(tester, repo: repo, dateQueryParam: '2026-07-14');

    await tester.tap(find.byKey(const Key('calendar-map-marker-a')));
    await tester.pumpAndSettle();

    final tile = tester.widget<Card>(
      find.byKey(const Key('calendar-route-point-a')),
    );
    expect(tile.color, isNotNull);
  });

  testWidgets('location-unavailable rows show the unavailable message', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..routeDayResult = CalendarRouteResult(
        date: DateTime(2026, 7, 14),
        employeeId: 'tu-1',
        points: [
          sampleRoutePoint(
            eventId: 'missing-1',
            locationState: CalendarRouteLocationState.missing,
            directionsAvailable: false,
          ),
        ],
        hasMore: false,
      );

    await _pump(tester, repo: repo, dateQueryParam: '2026-07-14');

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.calendarRouteLocationUnavailable), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-route-directions-missing-1')),
      findsNothing,
    );
  });

  testWidgets('overflow button opens the full event actions dialog', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()..routeDayResult = sampleRouteResult();

    await _pump(tester, repo: repo, dateQueryParam: '2026-07-14');

    await tester.tap(
      find.byKey(const Key('calendar-route-point-actions-route-event-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-actions-route-event-1')),
      findsOneWidget,
    );
  });

  testWidgets('truncated warning shows when hasMore is true', (tester) async {
    final repo = FakeCalendarRepository()
      ..routeDayResult = sampleRouteResult(hasMore: true);

    await _pump(tester, repo: repo, dateQueryParam: '2026-07-14');

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.calendarRouteTruncatedWarning), findsOneWidget);
  });

  testWidgets('malformed ?date= shows the invalid-date error state', (
    tester,
  ) async {
    final repo = FakeCalendarRepository();
    await _pump(tester, repo: repo, dateQueryParam: 'nope');

    expect(
      find.byKey(const Key('calendar-route-invalid-date')),
      findsOneWidget,
    );
    expect(repo.getRouteDayCount, 0);
  });

  testWidgets('runtime tile failure banner + Retry remounts map; list stays', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..routeDayResult = CalendarRouteResult(
        date: DateTime(2026, 7, 14),
        employeeId: 'tu-1',
        points: [
          sampleRoutePoint(eventId: 'a', latitude: 1, longitude: 1),
        ],
        hasMore: false,
      );

    final sessions = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(_assignedSession()),
          ),
          calendarRepositoryProvider.overrideWith((ref) => repo),
          calendarMapAppResolverProvider.overrideWithValue(
            CalendarMapAppResolver(canLaunch: (_) async => true),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CalendarRouteScreen(
            dateQueryParam: '2026-07-14',
            mapSurfaceBuilder:
                ({
                  required points,
                  required selectedEventId,
                  required onSelectEvent,
                  required onTileFailure,
                  required tileSessionId,
                }) {
              sessions.add(tileSessionId);
              return _RuntimeFailMapSurface(
                points: points,
                selectedEventId: selectedEventId,
                onSelectEvent: onSelectEvent,
                onTileFailure: onTileFailure,
                tileSessionId: tileSessionId,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.byKey(const Key('calendar-route-tile-failure')), findsOneWidget);
    expect(find.text(l10n.calendarRouteMapTilesUnavailable), findsOneWidget);
    expect(find.byKey(const Key('calendar-route-point-a')), findsOneWidget);

    final scheme = Theme.of(
      tester.element(find.byKey(const Key('calendar-route-tile-failure'))),
    ).colorScheme;
    final retryText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('calendar-route-tile-retry')),
        matching: find.byType(Text),
      ),
    );
    expect(retryText.style?.color, scheme.onErrorContainer);

    await tester.tap(find.byKey(const Key('calendar-route-tile-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-route-tile-failure')), findsNothing);
    expect(sessions, containsAll([0, 1]));
    expect(find.byKey(const Key('calendar-route-point-a')), findsOneWidget);
  });

  testWidgets('day-load error shows Retry and recovers on success', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..routeDayError = const CalendarException(code: CalendarException.unknown)
      ..routeDayResult = sampleRouteResult();

    await _pump(tester, repo: repo, dateQueryParam: '2026-07-14');

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.byKey(const Key('calendar-route-day-error')), findsOneWidget);
    expect(find.text(l10n.calendarRouteDayLoadFailed), findsOneWidget);

    repo.routeDayError = null;
    await tester.tap(find.byKey(const Key('calendar-route-day-error-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-route-day-error')), findsNothing);
    expect(find.byKey(const Key('calendar-route-point-route-event-1')), findsOneWidget);
  });

  testWidgets('employees error shows Retry and recovers on success', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..routeEmployeesError =
          const CalendarException(code: CalendarException.unknown)
      ..routeEmployeesResult = const CalendarRouteEmployeeListResult(
        employees: [
          CalendarRouteEmployee(
            employeeId: 'emp-1',
            nameAr: 'أ',
            nameEn: 'A',
            isActive: true,
          ),
        ],
        hasMore: false,
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(_officeSession()),
          ),
          calendarRepositoryProvider.overrideWith((ref) => repo),
          calendarMapAppResolverProvider.overrideWithValue(
            CalendarMapAppResolver(canLaunch: (_) async => true),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalendarRouteScreen(
            dateQueryParam: '2026-07-14',
            mapSurfaceBuilder: _fakeMapSurfaceBuilder,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      find.byKey(const Key('calendar-route-employees-error')),
      findsOneWidget,
    );
    expect(find.text(l10n.calendarRouteEmployeesLoadFailed), findsOneWidget);

    repo.routeEmployeesError = null;
    await tester.tap(find.byKey(const Key('calendar-route-employees-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-route-employees-error')), findsNothing);
    expect(find.byKey(const Key('calendar-route-employee-emp-1')), findsOneWidget);
  });

  testWidgets('Directions opens Open-with sheet without auto-launch', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..routeDayResult = sampleRouteResult()
      ..directionsResult = sampleDirectionsTarget();

    await _pump(tester, repo: repo, dateQueryParam: '2026-07-14');

    final button = find.byKey(
      const Key('calendar-route-directions-route-event-1'),
    );
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(); // start the async load
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(repo.getEventDirectionsCount, 1);
    expect(find.byKey(const Key('calendar-open-with-title')), findsOneWidget);
  });
}

AppSession _officeSession() {
  return AppSession(
    userId: 'user-1',
    email: 't@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'manager',
    displayName: 'Office',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: true, permissions: const {}),
  );
}

/// Calls [onTileFailure] once for session 0; later sessions stay healthy.
class _RuntimeFailMapSurface extends CalendarMapSurface {
  const _RuntimeFailMapSurface({
    required super.points,
    super.selectedEventId,
    required super.onSelectEvent,
    required this.onTileFailure,
    required this.tileSessionId,
  });

  final VoidCallback onTileFailure;
  final int tileSessionId;

  @override
  Widget build(BuildContext context) {
    if (tileSessionId == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onTileFailure());
    }
    return FakeCalendarMapSurface(
      points: points,
      selectedEventId: selectedEventId,
      onSelectEvent: onSelectEvent,
      groupSameCoordinates: true,
    );
  }
}
