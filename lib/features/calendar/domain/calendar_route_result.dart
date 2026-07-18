import 'calendar_route_point.dart';

/// Result of `get_calendar_route_day`: one employee's events for one day.
class CalendarRouteResult {
  const CalendarRouteResult({
    required this.date,
    required this.employeeId,
    required this.points,
    required this.hasMore,
  });

  final DateTime date;
  final String employeeId;
  final List<CalendarRoutePoint> points;

  /// True when the day has more events than `calendar_route_day_limit()`.
  final bool hasMore;

  List<CalendarRoutePoint> get mappedPoints =>
      points.where((p) => p.isMapped).toList(growable: false);
}
