import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../domain/calendar_route_point.dart';
import 'calendar_map_surface.dart';
import 'calendar_map_tile_config.dart';

/// Production Route View map surface backed by `flutter_map`.
class FlutterMapCalendarMapSurface extends CalendarMapSurface {
  const FlutterMapCalendarMapSurface({
    required super.points,
    super.selectedEventId,
    required super.onSelectEvent,
    super.groupSameCoordinates = false,
    this.tileConfig,
    this.onTileFailure,
    super.key,
  });

  final CalendarMapTileConfig? tileConfig;
  final VoidCallback? onTileFailure;

  @override
  Widget build(BuildContext context) {
    return _FlutterMapCalendarMapSurfaceBody(
      points: points,
      selectedEventId: selectedEventId,
      onSelectEvent: onSelectEvent,
      groupSameCoordinates: groupSameCoordinates,
      tileConfig: tileConfig,
      onTileFailure: onTileFailure,
    );
  }
}

class _FlutterMapCalendarMapSurfaceBody extends StatefulWidget {
  const _FlutterMapCalendarMapSurfaceBody({
    required this.points,
    required this.selectedEventId,
    required this.onSelectEvent,
    required this.groupSameCoordinates,
    required this.tileConfig,
    required this.onTileFailure,
  });

  final List<CalendarRoutePoint> points;
  final String? selectedEventId;
  final ValueChanged<String> onSelectEvent;
  final bool groupSameCoordinates;
  final CalendarMapTileConfig? tileConfig;
  final VoidCallback? onTileFailure;

  @override
  State<_FlutterMapCalendarMapSurfaceBody> createState() =>
      _FlutterMapCalendarMapSurfaceBodyState();
}

class _FlutterMapCalendarMapSurfaceBodyState
    extends State<_FlutterMapCalendarMapSurfaceBody> {
  bool _failureReported = false;

  void _reportFailure() {
    if (_failureReported) return;
    _failureReported = true;
    widget.onTileFailure?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mapped = widget.points
        .where((p) => p.isMapped)
        .toList(growable: false);
    if (mapped.isEmpty) {
      return _MapPlaceholder(
        placeholderKey: const Key('calendar-map-empty'),
        message: l10n.calendarRouteEmptyDay,
      );
    }

    final config = widget.tileConfig ?? CalendarMapTileConfig.fromEnvironment();
    if (!config.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportFailure());
      return _MapPlaceholder(
        placeholderKey: const Key('calendar-map-tiles-unavailable'),
        message: l10n.calendarRouteMapTilesUnavailable,
      );
    }

    final groups = _groupPoints(
      mapped,
      groupByCoordinates: widget.groupSameCoordinates,
    );
    final bounds = LatLngBounds.fromPoints([for (final g in groups) g.point]);
    final url = config.resolvedUrlTemplate!;
    final attribution = config.attribution!.trim();

    return ClipRect(
      key: const Key('calendar-map-flutter'),
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(40),
            maxZoom: 16,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: url,
            userAgentPackageName: config.userAgentPackageName,
            errorTileCallback: (tile, error, stackTrace) => _reportFailure(),
          ),
          MarkerLayer(
            markers: [
              for (final group in groups)
                Marker(
                  key: Key('calendar-map-marker-${group.eventIds.first}'),
                  point: group.point,
                  width: 40,
                  height: 40,
                  child: _RouteMarker(
                    count: group.eventIds.length,
                    selected: group.eventIds.contains(widget.selectedEventId),
                    onTap: () => widget.onSelectEvent(group.eventIds.first),
                    groupTooltip: group.eventIds.length > 1
                        ? l10n.calendarRouteMarkerGroupCount(
                            group.eventIds.length,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          SimpleAttributionWidget(source: Text(attribution)),
        ],
      ),
    );
  }
}

class _RouteMarkerGroup {
  _RouteMarkerGroup(this.point) : eventIds = [];
  final LatLng point;
  final List<String> eventIds;
}

List<_RouteMarkerGroup> _groupPoints(
  List<CalendarRoutePoint> points, {
  required bool groupByCoordinates,
}) {
  if (!groupByCoordinates) {
    return [
      for (final p in points)
        _RouteMarkerGroup(LatLng(p.latitude!, p.longitude!))
          ..eventIds.add(p.event.id),
    ];
  }
  final byCoordinate = <String, _RouteMarkerGroup>{};
  for (final p in points) {
    final coordinateKey = '${p.latitude},${p.longitude}';
    byCoordinate
        .putIfAbsent(
          coordinateKey,
          () => _RouteMarkerGroup(LatLng(p.latitude!, p.longitude!)),
        )
        .eventIds
        .add(p.event.id);
  }
  return byCoordinate.values.toList(growable: false);
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker({
    required this.count,
    required this.selected,
    required this.onTap,
    this.groupTooltip,
  });

  final int count;
  final bool selected;
  final VoidCallback onTap;
  final String? groupTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marker = GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.error : scheme.primary,
          border: Border.all(color: scheme.surface, width: 2),
        ),
        alignment: Alignment.center,
        child: count > 1
            ? Text(
                '$count',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Icon(Icons.location_pin, color: scheme.onPrimary, size: 18),
      ),
    );
    final tooltip = groupTooltip;
    return tooltip == null ? marker : Tooltip(message: tooltip, child: marker);
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required Key placeholderKey, required this.message})
    : super(key: placeholderKey);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
