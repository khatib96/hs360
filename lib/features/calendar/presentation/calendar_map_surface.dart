import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/calendar_route_point.dart';

/// Route View map widget interface.
abstract class CalendarMapSurface extends StatelessWidget {
  const CalendarMapSurface({
    required this.points,
    this.selectedEventId,
    required this.onSelectEvent,
    this.groupSameCoordinates = false,
    super.key,
  });

  final List<CalendarRoutePoint> points;
  final String? selectedEventId;
  final ValueChanged<String> onSelectEvent;
  final bool groupSameCoordinates;

  List<CalendarRoutePoint> get mappedPoints =>
      points.where((p) => p.isMapped).toList(growable: false);
}

/// Deterministic, network-free map-like surface for tests/screenshots.
///
/// Draws a local neutral road/block backdrop and selectable pins. This is
/// **not** a real tile provider.
class FakeCalendarMapSurface extends CalendarMapSurface {
  const FakeCalendarMapSurface({
    required super.points,
    super.selectedEventId,
    required super.onSelectEvent,
    super.groupSameCoordinates = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final mapped = mappedPoints;
    if (mapped.isEmpty) {
      return const SizedBox.expand(key: Key('calendar-map-fake-empty'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final positions = _pinPositions(mapped, size);
        return Stack(
          key: const Key('calendar-map-fake'),
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _FakeMapBackdropPainter(
                colorScheme: Theme.of(context).colorScheme,
              ),
              size: size,
            ),
            for (final entry in positions.entries)
              Positioned(
                left: entry.value.dx - 14,
                top: entry.value.dy - 28,
                child: _FakeMapPin(
                  eventId: entry.key.event.id,
                  selected: entry.key.event.id == selectedEventId,
                  count: groupSameCoordinates
                      ? mapped
                            .where(
                              (p) =>
                                  p.latitude == entry.key.latitude &&
                                  p.longitude == entry.key.longitude,
                            )
                            .length
                      : 1,
                  onTap: () => onSelectEvent(entry.key.event.id),
                ),
              ),
          ],
        );
      },
    );
  }

  Map<CalendarRoutePoint, Offset> _pinPositions(
    List<CalendarRoutePoint> mapped,
    Size size,
  ) {
    final lats = mapped.map((p) => p.latitude!).toList();
    final lngs = mapped.map((p) => p.longitude!).toList();
    var minLat = lats.reduce(math.min);
    var maxLat = lats.reduce(math.max);
    var minLng = lngs.reduce(math.min);
    var maxLng = lngs.reduce(math.max);
    if (minLat == maxLat) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if (minLng == maxLng) {
      minLng -= 0.01;
      maxLng += 0.01;
    }

    final pad = 36.0;
    final w = math.max(1.0, size.width - pad * 2);
    final h = math.max(1.0, size.height - pad * 2);
    final result = <CalendarRoutePoint, Offset>{};

    if (groupSameCoordinates) {
      final seen = <String>{};
      for (final p in mapped) {
        final key = '${p.latitude},${p.longitude}';
        if (!seen.add(key)) continue;
        final x = pad + ((p.longitude! - minLng) / (maxLng - minLng)) * w;
        final y = pad + (1 - (p.latitude! - minLat) / (maxLat - minLat)) * h;
        result[p] = Offset(x, y);
      }
    } else {
      for (final p in mapped) {
        final x = pad + ((p.longitude! - minLng) / (maxLng - minLng)) * w;
        final y = pad + (1 - (p.latitude! - minLat) / (maxLat - minLat)) * h;
        result[p] = Offset(x, y);
      }
    }
    return result;
  }
}

class _FakeMapPin extends StatelessWidget {
  const _FakeMapPin({
    required this.eventId,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final String eventId;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: Key('calendar-map-marker-$eventId'),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? scheme.error : scheme.primary,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: count > 1
                ? Text(
                    '$count',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Icon(Icons.location_on, size: 16, color: scheme.onPrimary),
          ),
          CustomPaint(
            size: const Size(10, 8),
            painter: _PinStemPainter(
              color: selected ? scheme.error : scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinStemPainter extends CustomPainter {
  _PinStemPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinStemPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _FakeMapBackdropPainter extends CustomPainter {
  _FakeMapBackdropPainter({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = const Color(0xFFE8E4DA);
    canvas.drawRect(Offset.zero & size, land);

    final block = Paint()..color = const Color(0xFFD9D3C5);
    const blockW = 56.0;
    const blockH = 40.0;
    for (var y = 8.0; y < size.height; y += blockH + 18) {
      for (var x = 8.0; x < size.width; x += blockW + 18) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, blockW, blockH),
            const Radius.circular(2),
          ),
          block,
        );
      }
    }

    final road = Paint()
      ..color = const Color(0xFFF5F2EA)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final arterial = Paint()
      ..color = const Color(0xFFE6E0D2)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width, size.height * 0.38),
      arterial,
    );
    canvas.drawLine(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.42, size.height),
      arterial,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.62),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.65, 0),
      Offset(size.width * 0.55, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant _FakeMapBackdropPainter oldDelegate) => false;
}
