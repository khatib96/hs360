import 'package:flutter/material.dart';

import '../../domain/calendar_route_point.dart';
import '../calendar_flutter_map_surface.dart';
import '../calendar_map_surface.dart';
import '../calendar_route_state.dart';

/// Builds the Route View map widget for a given points/selection snapshot.
typedef CalendarRouteMapSurfaceBuilder =
    CalendarMapSurface Function({
      required List<CalendarRoutePoint> points,
      required String? selectedEventId,
      required ValueChanged<String> onSelectEvent,
      required VoidCallback onTileFailure,
      required int tileSessionId,
    });

CalendarMapSurface defaultCalendarRouteMapSurfaceBuilder({
  required List<CalendarRoutePoint> points,
  required String? selectedEventId,
  required ValueChanged<String> onSelectEvent,
  required VoidCallback onTileFailure,
  required int tileSessionId,
}) {
  return FlutterMapCalendarMapSurface(
    key: ValueKey('calendar-map-session-$tileSessionId'),
    points: points,
    selectedEventId: selectedEventId,
    onSelectEvent: onSelectEvent,
    groupSameCoordinates: true,
    onTileFailure: onTileFailure,
  );
}

/// Overlay shown when [CalendarRouteMapSurfaceState.tileFailure] is active.
class CalendarRouteTileFailureBanner extends StatelessWidget {
  const CalendarRouteTileFailureBanner({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('calendar-route-tile-failure'),
      color: scheme.errorContainer.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(
              key: const Key('calendar-route-tile-retry'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
              ),
              onPressed: onRetry,
              child: Text(
                retryLabel,
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
