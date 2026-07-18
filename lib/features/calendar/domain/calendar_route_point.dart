import 'calendar_event.dart';
import 'calendar_route_location_state.dart';

/// A single event on a Route View day, with its resolved location state.
///
/// [latitude]/[longitude] are populated only when [locationState] is
/// [CalendarRouteLocationState.mapped].
class CalendarRoutePoint {
  const CalendarRoutePoint({
    required this.event,
    required this.locationState,
    this.latitude,
    this.longitude,
  });

  final CalendarEvent event;
  final CalendarRouteLocationState locationState;
  final double? latitude;
  final double? longitude;

  bool get isMapped =>
      locationState == CalendarRouteLocationState.mapped &&
      latitude != null &&
      longitude != null;
}
