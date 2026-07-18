import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_directions_target.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_route_employee.dart';
import '../domain/calendar_route_result.dart';
import 'calendar_route_rpc_mappers.dart';

/// Testable RPC invoker shared with [CalendarRepository]:
/// `(functionName, params) => raw JSON`.
typedef CalendarRouteRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);

/// Phase 7 M10 Route View / directions RPC calls.
///
/// Extracted from `CalendarRepository` (which delegates to this class) to
/// keep that file under the engineering file-size guideline.
class CalendarRouteRepository {
  CalendarRouteRepository(this._invokeRpc);

  final CalendarRouteRpcInvoker _invokeRpc;

  void _assertCanAccess(AppSession session) {
    if (!canAccessCalendar(session)) {
      throw const CalendarException(code: CalendarException.permissionDenied);
    }
  }

  Future<CalendarRouteResult> getRouteDay(
    AppSession session, {
    required DateTime date,
    String? employeeId,
  }) async {
    _assertCanAccess(session);
    try {
      final result = await _invokeRpc('get_calendar_route_day', {
        'p_date': formatCalendarDateOnly(date),
        'p_employee_id': employeeId,
      });
      return mapRouteDayResult(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  Future<CalendarRouteEmployeeListResult> listRouteEmployees(
    AppSession session, {
    String? search,
    int? limit,
  }) async {
    _assertCanAccess(session);
    if (!canViewTenantCalendar(session)) {
      throw const CalendarException(code: CalendarException.permissionDenied);
    }
    try {
      final result = await _invokeRpc('list_calendar_route_employees', {
        'p_search': search,
        'p_limit': limit,
      });
      return mapRouteEmployeesResult(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  Future<CalendarDirectionsTarget> getEventDirections(
    AppSession session,
    String eventId,
  ) async {
    _assertCanAccess(session);
    try {
      final result = await _invokeRpc('get_calendar_event_directions', {
        'p_event_id': eventId,
      });
      return mapDirectionsTarget(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }
}
