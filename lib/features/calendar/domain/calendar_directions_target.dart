import 'calendar_route_location_state.dart';

/// Result of `get_calendar_event_directions`: the resolved directions
/// target for one event, used by the directions launcher.
///
/// The RPC only ever resolves for [CalendarRouteLocationState.mapped] or
/// [CalendarRouteLocationState.urlOnly]; other states raise a
/// `validation_failed` RPC error instead of returning a payload.
class CalendarDirectionsTarget {
  const CalendarDirectionsTarget({
    required this.eventId,
    required this.locationState,
    this.latitude,
    this.longitude,
    this.mapsUrl,
  });

  final String eventId;
  final CalendarRouteLocationState locationState;
  final double? latitude;
  final double? longitude;
  final String? mapsUrl;

  bool get hasCoordinates => latitude != null && longitude != null;
}
