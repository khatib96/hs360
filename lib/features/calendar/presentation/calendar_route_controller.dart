import 'dart:async' show unawaited;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_directions_target.dart';
import '../domain/calendar_permissions.dart';
import 'calendar_clock.dart';
import 'calendar_route_state.dart';

part 'calendar_route_controller.g.dart';

/// Owns Route View (Phase 7 M10) load state: selected date/employee, mapped
/// points, employee picker, marker/list selection, and directions launch.
@Riverpod(keepAlive: true)
class CalendarRouteController extends _$CalendarRouteController {
  int _dayGeneration = 0;
  int _employeesGeneration = 0;
  bool _hasStartedInitialLoad = false;

  @override
  CalendarRouteState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        _dayGeneration++;
        _employeesGeneration++;
        _hasStartedInitialLoad = false;
        state = calendarRouteInitialState(calendarClock());
        return;
      }
      if (_shouldResetForSession(previousSession, nextSession)) {
        _dayGeneration++;
        _employeesGeneration++;
        state = calendarRouteInitialState(state.selectedDate);
        unawaited(_reloadForCurrentSession());
      }
    });
    return calendarRouteInitialState(calendarClock());
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool _shouldResetForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.userId != next.userId ||
        previous.tenantId != next.tenantId ||
        previous.isManager != next.isManager ||
        previous.permissions != next.permissions;
  }

  Future<void> _reloadForCurrentSession() async {
    if (!_hasStartedInitialLoad) return;
    await refresh();
  }

  /// Idempotent first-load hook: applies an optional `?date=`/employee from
  /// the route and starts the initial fetch. Safe to call every build.
  Future<void> ensureInitialized({DateTime? date, String? employeeId}) async {
    if (_hasStartedInitialLoad) {
      if (date != null && calendarDateOnly(date) != state.selectedDate) {
        await selectDate(date);
      }
      return;
    }
    _hasStartedInitialLoad = true;
    if (date != null) {
      state = state.copyWith(selectedDate: calendarDateOnly(date));
    }
    if (employeeId != null) {
      state = state.copyWith(selectedEmployeeId: employeeId);
    }
    await refresh();
  }

  /// Marks the requested `?date=` as unparseable; the screen shows an error
  /// state instead of falling back silently to today.
  void reportInvalidDate() {
    _hasStartedInitialLoad = true;
    state = state.copyWith(dateInvalid: true);
  }

  Future<void> refresh() async {
    final session = _session;
    if (session != null && canViewTenantCalendar(session)) {
      await Future.wait([_loadDay(), loadEmployees()]);
    } else {
      await _loadDay();
    }
  }

  Future<void> selectDate(DateTime date) async {
    final day = calendarDateOnly(date);
    if (day == state.selectedDate && state.hasLoadedDayOnce) return;
    state = state.copyWith(
      selectedDate: day,
      points: const [],
      hasMore: false,
      clearSelectedEventId: true,
      clearDayError: true,
      dateInvalid: false,
    );
    await _loadDay();
  }

  Future<void> selectEmployee(String? employeeId) async {
    if (employeeId == state.selectedEmployeeId) return;
    state = state.copyWith(
      selectedEmployeeId: employeeId,
      clearSelectedEmployeeId: employeeId == null,
      points: const [],
      hasMore: false,
      clearSelectedEventId: true,
      clearDayError: true,
    );
    await _loadDay();
  }

  Future<void> loadEmployees({String? search}) async {
    final session = _session;
    if (session == null || !canViewTenantCalendar(session)) return;

    final gen = ++_employeesGeneration;
    final query = search ?? state.employeeSearch;
    state = state.copyWith(
      isLoadingEmployees: true,
      clearEmployeesError: true,
      employeeSearch: query,
    );
    try {
      final trimmed = query.trim();
      final result = await ref
          .read(calendarRepositoryProvider)
          .listRouteEmployees(
            session,
            search: trimmed.isEmpty ? null : trimmed,
          );
      if (gen != _employeesGeneration) return;
      state = state.copyWith(
        isLoadingEmployees: false,
        employees: result.employees,
        employeesHasMore: result.hasMore,
        clearEmployeesError: true,
      );
    } on CalendarException catch (e) {
      if (gen != _employeesGeneration) return;
      state = state.copyWith(
        isLoadingEmployees: false,
        employeesErrorCode: e.code,
      );
    } catch (_) {
      if (gen != _employeesGeneration) return;
      state = state.copyWith(
        isLoadingEmployees: false,
        employeesErrorCode: CalendarException.unknown,
      );
    }
  }

  void selectEvent(String eventId) {
    if (state.selectedEventId == eventId) return;
    state = state.copyWith(selectedEventId: eventId);
  }

  /// Alias for map-marker taps; kept distinct from [selectEvent] (list taps)
  /// for call-site clarity even though the effect is identical.
  void selectPoint(String eventId) => selectEvent(eventId);

  void reportTileFailure() {
    if (state.mapSurfaceState == CalendarRouteMapSurfaceState.tileFailure) {
      return;
    }
    state = state.copyWith(
      mapSurfaceState: CalendarRouteMapSurfaceState.tileFailure,
    );
  }

  /// Clears tile failure and remounts the map surface (new [tileSessionId]).
  void retryTiles() {
    state = state.copyWith(
      mapSurfaceState: CalendarRouteMapSurfaceState.ok,
      tileSessionId: state.tileSessionId + 1,
    );
  }

  /// Loads the directions target without launching any map app.
  Future<CalendarDirectionsTarget?> loadDirectionsTarget(String eventId) async {
    final session = _session;
    if (session == null) {
      state = state.copyWith(
        directionsErrorCode: CalendarException.permissionDenied,
      );
      return null;
    }

    // Avoid a no-op state write — it rebuilds the route list and can unmount
    // the Directions button context before the Open-with sheet is presented.
    if (state.directionsErrorCode != null) {
      state = state.copyWith(clearDirectionsError: true);
    }
    try {
      return await ref
          .read(calendarRepositoryProvider)
          .getEventDirections(session, eventId);
    } on CalendarException catch (e) {
      state = state.copyWith(directionsErrorCode: e.code);
      return null;
    } catch (_) {
      state = state.copyWith(directionsErrorCode: CalendarException.unknown);
      return null;
    }
  }

  Future<void> _loadDay() async {
    final session = _session;
    if (session == null || !canAccessCalendar(session)) {
      state = state.copyWith(
        permissionDenied: true,
        points: const [],
        hasMore: false,
        isLoadingDay: false,
      );
      return;
    }

    final tenantWide = canViewTenantCalendar(session);
    if (tenantWide && state.selectedEmployeeId == null) {
      state = state.copyWith(
        isTenantWide: true,
        permissionDenied: false,
        isLoadingDay: false,
        points: const [],
        hasMore: false,
        clearDayError: true,
      );
      return;
    }

    final gen = ++_dayGeneration;
    final requestedDate = state.selectedDate;
    final requestedEmployeeId = tenantWide ? state.selectedEmployeeId : null;
    state = state.copyWith(
      isTenantWide: tenantWide,
      isLoadingDay: true,
      clearDayError: true,
      permissionDenied: false,
    );

    try {
      final result = await ref
          .read(calendarRepositoryProvider)
          .getRouteDay(
            session,
            date: requestedDate,
            employeeId: requestedEmployeeId,
          );
      if (gen != _dayGeneration) return;

      if (calendarDateOnly(result.date) != requestedDate) {
        state = state.copyWith(
          isLoadingDay: false,
          dayErrorCode: CalendarException.malformedResponse,
        );
        return;
      }

      final mappedIds = result.points.map((p) => p.event.id).toSet();
      final keepsSelection =
          state.selectedEventId != null &&
          mappedIds.contains(state.selectedEventId);

      state = state.copyWith(
        isLoadingDay: false,
        hasLoadedDayOnce: true,
        points: result.points,
        hasMore: result.hasMore,
        clearDayError: true,
        clearSelectedEventId: !keepsSelection,
      );
    } on CalendarException catch (e) {
      if (gen != _dayGeneration) return;
      state = state.copyWith(
        isLoadingDay: false,
        dayErrorCode: e.code,
        permissionDenied: e.code == CalendarException.permissionDenied,
        points: const [],
        hasMore: false,
      );
    } catch (_) {
      if (gen != _dayGeneration) return;
      state = state.copyWith(
        isLoadingDay: false,
        dayErrorCode: CalendarException.unknown,
        points: const [],
        hasMore: false,
      );
    }
  }
}
