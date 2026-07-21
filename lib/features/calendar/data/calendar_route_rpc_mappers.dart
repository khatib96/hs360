import '../domain/calendar_directions_target.dart';
import '../domain/calendar_route_employee.dart';
import '../domain/calendar_route_location_state.dart';
import '../domain/calendar_route_point.dart';
import '../domain/calendar_route_result.dart';
import 'calendar_read_rpc_parsers.dart';

/// Strict mappers for Phase 7 M10 Route View / directions RPCs.
///
/// These never expect `google_maps_url` on route-day rows: raw coordinate and
/// URL fields stay server-side, and only the derived [CalendarRouteLocationState]
/// plus (for `mapped`) validated coordinates cross the RPC boundary.
CalendarRouteResult mapRouteDayResult(dynamic raw) {
  final map = requireMap(raw, 'route_day root');
  final rowsRaw = requireList(map['points'], 'route_day.points');
  final points = rowsRaw
      .map((item) => mapRoutePoint(requireMap(item, 'route_day.points[]')))
      .toList(growable: false);

  return CalendarRouteResult(
    date: parseRequiredCalendarDate(map['date']),
    employeeId: requireString(map['employee_id'], 'route_day.employee_id'),
    points: points,
    hasMore: requireBool(map['has_more'], 'route_day.has_more'),
  );
}

/// Maps one `points[]` row. For `mapped`, both `latitude`/`longitude` must be
/// present and valid; for `url_only`/`invalid`/`missing`, both keys must be
/// absent. Any other combination is a malformed response.
CalendarRoutePoint mapRoutePoint(Map<String, dynamic> raw) {
  final event = mapCalendarEvent(requireMap(raw['event'], 'route_point.event'));
  final state = requireEnum(
    raw['location_state'],
    CalendarRouteLocationState.fromRpc,
    'route_point.location_state',
  );
  final hasLat = raw.containsKey('latitude') && raw['latitude'] != null;
  final hasLng = raw.containsKey('longitude') && raw['longitude'] != null;

  if (state == CalendarRouteLocationState.mapped) {
    if (!hasLat || !hasLng) {
      return malformedCalendarResponse(
        'route_point.latitude/longitude required for mapped state',
      );
    }
    return CalendarRoutePoint(
      event: event,
      locationState: state,
      latitude: requireDouble(raw['latitude'], 'route_point.latitude'),
      longitude: requireDouble(raw['longitude'], 'route_point.longitude'),
    );
  }

  if (hasLat || hasLng) {
    return malformedCalendarResponse(
      'route_point.latitude/longitude must be absent for state '
      '${state.rpcValue}',
    );
  }
  return CalendarRoutePoint(event: event, locationState: state);
}

/// Maps `get_calendar_event_directions`. The RPC only ever resolves for
/// `mapped` (lat/lng + built `maps_url`) or `url_only` (`maps_url` only);
/// any other state means the server rejected the request before returning
/// a payload, so it is treated as malformed here.
CalendarDirectionsTarget mapDirectionsTarget(dynamic raw) {
  final map = requireMap(raw, 'directions target root');
  final eventId = requireString(map['event_id'], 'directions.event_id');
  final state = requireEnum(
    map['location_state'],
    CalendarRouteLocationState.fromRpc,
    'directions.location_state',
  );
  final hasLat = map.containsKey('latitude') && map['latitude'] != null;
  final hasLng = map.containsKey('longitude') && map['longitude'] != null;
  final hasUrl = map.containsKey('maps_url') && map['maps_url'] != null;

  if (state == CalendarRouteLocationState.mapped) {
    if (!hasLat || !hasLng || !hasUrl) {
      return malformedCalendarResponse(
        'directions.latitude/longitude/maps_url required for mapped state',
      );
    }
    return CalendarDirectionsTarget(
      eventId: eventId,
      locationState: state,
      latitude: requireDouble(map['latitude'], 'directions.latitude'),
      longitude: requireDouble(map['longitude'], 'directions.longitude'),
      mapsUrl: requireString(map['maps_url'], 'directions.maps_url'),
    );
  }

  if (state == CalendarRouteLocationState.urlOnly) {
    if (hasLat || hasLng || !hasUrl) {
      return malformedCalendarResponse(
        'directions.maps_url required (and no coordinates) for url_only state',
      );
    }
    return CalendarDirectionsTarget(
      eventId: eventId,
      locationState: state,
      mapsUrl: requireString(map['maps_url'], 'directions.maps_url'),
    );
  }

  return malformedCalendarResponse(
    'directions target should not resolve for state ${state.rpcValue}',
  );
}

CalendarRouteEmployeeListResult mapRouteEmployeesResult(dynamic raw) {
  final map = requireMap(raw, 'route_employees root');
  final rowsRaw = requireList(map['rows'], 'route_employees.rows');
  final employees = rowsRaw
      .map((item) {
        final row = requireMap(item, 'route_employees.rows[]');
        return CalendarRouteEmployee(
          employeeId: requireString(
            row['employee_id'],
            'route_employees.employee_id',
          ),
          nameAr: requireString(row['name_ar'], 'route_employees.name_ar'),
          nameEn: optionalString(row['name_en']),
          isActive: requireBool(row['is_active'], 'route_employees.is_active'),
        );
      })
      .toList(growable: false);

  return CalendarRouteEmployeeListResult(
    employees: employees,
    hasMore: requireBool(map['has_more'], 'route_employees.has_more'),
  );
}
