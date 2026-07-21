import 'dart:async';

import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_directions_target.dart';
import 'package:hs360/features/calendar/domain/calendar_route_employee.dart';
import 'package:hs360/features/calendar/domain/calendar_route_location_state.dart';
import 'package:hs360/features/calendar/domain/calendar_route_point.dart';
import 'package:hs360/features/calendar/domain/calendar_route_result.dart';

import 'fake_calendar_repository.dart' show sampleCalendarEvent;

/// Phase 7 M10 Route View sample builders + [FakeCalendarRepository] mixin.
///
/// Kept in its own file (rather than growing `fake_calendar_repository.dart`
/// further) per the engineering file-size guideline.
CalendarRoutePoint sampleRoutePoint({
  String eventId = 'route-event-1',
  CalendarRouteLocationState locationState = CalendarRouteLocationState.mapped,
  double? latitude = 29.3759,
  double? longitude = 47.9774,
  bool directionsAvailable = true,
}) {
  return CalendarRoutePoint(
    event: sampleCalendarEvent(
      id: eventId,
      directionsAvailable: directionsAvailable,
      availableActions: const CalendarAvailableActions(
        canViewCustomer: true,
        canViewContract: true,
        canAssign: false,
        canReschedule: false,
        canCreateManual: false,
        canOpenDirections: true,
        canEditManual: false,
        canCancelManual: false,
        canMarkManualDone: false,
        canOpenMeetingLink: false,
      ),
    ),
    locationState: locationState,
    latitude: locationState == CalendarRouteLocationState.mapped
        ? latitude
        : null,
    longitude: locationState == CalendarRouteLocationState.mapped
        ? longitude
        : null,
  );
}

CalendarRouteResult sampleRouteResult({
  DateTime? date,
  String employeeId = 'emp-1',
  List<CalendarRoutePoint>? points,
  bool hasMore = false,
}) {
  return CalendarRouteResult(
    date: date ?? DateTime(2026, 7, 14),
    employeeId: employeeId,
    points: points ?? [sampleRoutePoint()],
    hasMore: hasMore,
  );
}

CalendarDirectionsTarget sampleDirectionsTarget({
  String eventId = 'route-event-1',
  CalendarRouteLocationState locationState = CalendarRouteLocationState.mapped,
  double? latitude = 29.3759,
  double? longitude = 47.9774,
  String? mapsUrl =
      'https://www.google.com/maps/dir/?api=1&destination=29.3759,47.9774',
}) {
  return CalendarDirectionsTarget(
    eventId: eventId,
    locationState: locationState,
    latitude: locationState == CalendarRouteLocationState.mapped
        ? latitude
        : null,
    longitude: locationState == CalendarRouteLocationState.mapped
        ? longitude
        : null,
    mapsUrl: mapsUrl,
  );
}

/// Adds M10 Route View RPC behavior to `FakeCalendarRepository`.
mixin FakeCalendarRouteRepositoryMixin on CalendarRepository {
  CalendarRouteResult routeDayResult = sampleRouteResult();
  CalendarRouteEmployeeListResult routeEmployeesResult =
      const CalendarRouteEmployeeListResult(employees: [], hasMore: false);
  CalendarDirectionsTarget? directionsResult;
  Object? routeDayError;
  Object? routeEmployeesError;
  Object? directionsError;

  /// When set, `getRouteDay` awaits this before returning (lets tests race
  /// a slow first request against a faster later one).
  Completer<void>? holdRouteDayUntil;

  int getRouteDayCount = 0;
  int listRouteEmployeesCount = 0;
  int getEventDirectionsCount = 0;

  DateTime? lastRouteDayDate;
  String? lastRouteDayEmployeeId;
  String? lastRouteEmployeesSearch;
  String? lastDirectionsEventId;

  @override
  Future<CalendarRouteResult> getRouteDay(
    AppSession session, {
    required DateTime date,
    String? employeeId,
  }) async {
    getRouteDayCount++;
    lastRouteDayDate = date;
    lastRouteDayEmployeeId = employeeId;
    final gate = holdRouteDayUntil;
    if (gate != null) await gate.future;
    _maybeThrowRoute(routeDayError);
    return routeDayResult;
  }

  @override
  Future<CalendarRouteEmployeeListResult> listRouteEmployees(
    AppSession session, {
    String? search,
    int? limit,
  }) async {
    listRouteEmployeesCount++;
    lastRouteEmployeesSearch = search;
    _maybeThrowRoute(routeEmployeesError);
    return routeEmployeesResult;
  }

  @override
  Future<CalendarDirectionsTarget> getEventDirections(
    AppSession session,
    String eventId,
  ) async {
    getEventDirectionsCount++;
    lastDirectionsEventId = eventId;
    _maybeThrowRoute(directionsError);
    return directionsResult ?? sampleDirectionsTarget(eventId: eventId);
  }

  void _maybeThrowRoute(Object? error) {
    if (error == null) return;
    if (error is CalendarException) throw error;
    throw CalendarException(
      code: CalendarException.unknown,
      technicalDetail: error.toString(),
    );
  }
}
