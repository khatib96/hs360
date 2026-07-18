import '../domain/calendar_date.dart';
import '../domain/calendar_route_employee.dart';
import '../domain/calendar_route_point.dart';

/// Route View basemap health, independent of the event-list load state.
enum CalendarRouteMapSurfaceState { ok, tileFailure }

/// UI / orchestration state for the Route View screen (Phase 7 M10).
class CalendarRouteState {
  CalendarRouteState({
    required this.selectedDate,
    this.selectedEmployeeId,
    List<CalendarRoutePoint> points = const [],
    this.hasMore = false,
    this.isTenantWide = false,
    this.isLoadingDay = false,
    this.hasLoadedDayOnce = false,
    this.dayErrorCode,
    this.permissionDenied = false,
    this.dateInvalid = false,
    this.mapSurfaceState = CalendarRouteMapSurfaceState.ok,
    this.tileSessionId = 0,
    this.selectedEventId,
    List<CalendarRouteEmployee> employees = const [],
    this.employeesHasMore = false,
    this.isLoadingEmployees = false,
    this.employeesErrorCode,
    this.employeeSearch = '',
    this.directionsErrorCode,
  }) : points = List.unmodifiable(points),
       employees = List.unmodifiable(employees);

  final DateTime selectedDate;

  /// Locked to the caller's own employee row (server-resolved) for
  /// assigned-only sessions; explicit selection required for tenant-wide.
  final String? selectedEmployeeId;
  final List<CalendarRoutePoint> points;

  /// True when the day has more events than `calendar_route_day_limit()`.
  final bool hasMore;

  /// True when the session can view the tenant-wide calendar (requires an
  /// explicit employee selection before the day RPC is called).
  final bool isTenantWide;

  final bool isLoadingDay;
  final bool hasLoadedDayOnce;
  final String? dayErrorCode;
  final bool permissionDenied;

  /// True when the caller supplied a malformed `?date=` query value.
  final bool dateInvalid;

  final CalendarRouteMapSurfaceState mapSurfaceState;

  /// Bumped by [CalendarRouteController.retryTiles] to remount the map.
  final int tileSessionId;
  final String? selectedEventId;

  final List<CalendarRouteEmployee> employees;
  final bool employeesHasMore;
  final bool isLoadingEmployees;
  final String? employeesErrorCode;
  final String employeeSearch;

  final String? directionsErrorCode;

  /// Tenant-wide with no employee chosen yet: day RPC has not been called.
  bool get awaitingEmployeeSelection =>
      isTenantWide && selectedEmployeeId == null;

  CalendarRouteState copyWith({
    DateTime? selectedDate,
    String? selectedEmployeeId,
    bool clearSelectedEmployeeId = false,
    List<CalendarRoutePoint>? points,
    bool? hasMore,
    bool? isTenantWide,
    bool? isLoadingDay,
    bool? hasLoadedDayOnce,
    String? dayErrorCode,
    bool clearDayError = false,
    bool? permissionDenied,
    bool? dateInvalid,
    CalendarRouteMapSurfaceState? mapSurfaceState,
    int? tileSessionId,
    String? selectedEventId,
    bool clearSelectedEventId = false,
    List<CalendarRouteEmployee>? employees,
    bool? employeesHasMore,
    bool? isLoadingEmployees,
    String? employeesErrorCode,
    bool clearEmployeesError = false,
    String? employeeSearch,
    String? directionsErrorCode,
    bool clearDirectionsError = false,
  }) {
    return CalendarRouteState(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedEmployeeId: clearSelectedEmployeeId
          ? null
          : (selectedEmployeeId ?? this.selectedEmployeeId),
      points: points ?? this.points,
      hasMore: hasMore ?? this.hasMore,
      isTenantWide: isTenantWide ?? this.isTenantWide,
      isLoadingDay: isLoadingDay ?? this.isLoadingDay,
      hasLoadedDayOnce: hasLoadedDayOnce ?? this.hasLoadedDayOnce,
      dayErrorCode: clearDayError ? null : (dayErrorCode ?? this.dayErrorCode),
      permissionDenied: permissionDenied ?? this.permissionDenied,
      dateInvalid: dateInvalid ?? this.dateInvalid,
      mapSurfaceState: mapSurfaceState ?? this.mapSurfaceState,
      tileSessionId: tileSessionId ?? this.tileSessionId,
      selectedEventId: clearSelectedEventId
          ? null
          : (selectedEventId ?? this.selectedEventId),
      employees: employees ?? this.employees,
      employeesHasMore: employeesHasMore ?? this.employeesHasMore,
      isLoadingEmployees: isLoadingEmployees ?? this.isLoadingEmployees,
      employeesErrorCode: clearEmployeesError
          ? null
          : (employeesErrorCode ?? this.employeesErrorCode),
      employeeSearch: employeeSearch ?? this.employeeSearch,
      directionsErrorCode: clearDirectionsError
          ? null
          : (directionsErrorCode ?? this.directionsErrorCode),
    );
  }
}

CalendarRouteState calendarRouteInitialState(DateTime today) =>
    CalendarRouteState(selectedDate: calendarDateOnly(today));
