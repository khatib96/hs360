/// RPC JSON fixtures for Phase 7 M10 Route View / directions RPCs
/// (migration 102): `get_calendar_route_day`, `list_calendar_route_employees`,
/// `get_calendar_event_directions`.
library;

import 'calendar_read_fixtures.dart';

Map<String, dynamic> sampleRouteDayRpc({
  String date = '2026-07-14',
  String employeeId = 'emp-1',
  bool hasMore = false,
}) {
  return {
    'date': date,
    'employee_id': employeeId,
    'points': [
      {
        'event': validCalendarEventRpc(scheduledDate: date),
        'location_state': 'mapped',
        'latitude': 29.3759,
        'longitude': 47.9774,
      },
    ],
    'has_more': hasMore,
  };
}

Map<String, dynamic> sampleRouteEmployeesRpc({bool hasMore = false}) {
  return {
    'rows': [
      {
        'employee_id': 'emp-1',
        'name_ar': 'موظف',
        'name_en': 'Employee',
        'is_active': true,
      },
    ],
    'has_more': hasMore,
  };
}

Map<String, dynamic> sampleDirectionsRpc({
  String eventId = 'event-42',
  String state = 'mapped',
}) {
  if (state == 'url_only') {
    return {
      'event_id': eventId,
      'location_state': 'url_only',
      'maps_url':
          'https://www.google.com/maps/dir/?api=1&destination=Main+Street',
    };
  }
  return {
    'event_id': eventId,
    'location_state': 'mapped',
    'latitude': 29.3759,
    'longitude': 47.9774,
    'maps_url':
        'https://www.google.com/maps/dir/?api=1&destination=29.3759,47.9774',
  };
}
