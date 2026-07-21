import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_route_rpc_mappers.dart';
import 'package:hs360/features/calendar/domain/calendar_route_location_state.dart';

import 'calendar_read_fixtures.dart';

Map<String, dynamic> _routePointRpc({
  String state = 'mapped',
  double? latitude = 29.3759,
  double? longitude = 47.9774,
  bool includeLatKey = true,
  bool includeLngKey = true,
}) {
  final map = <String, dynamic>{
    'event': validCalendarEventRpc(),
    'location_state': state,
  };
  if (includeLatKey) map['latitude'] = latitude;
  if (includeLngKey) map['longitude'] = longitude;
  return map;
}

Map<String, dynamic> _routeDayRpc({
  String date = '2026-07-14',
  String employeeId = 'emp-1',
  List<Map<String, dynamic>>? points,
  bool hasMore = false,
}) {
  return {
    'date': date,
    'employee_id': employeeId,
    'points': points ?? [_routePointRpc()],
    'has_more': hasMore,
  };
}

Map<String, dynamic> _directionsRpc({
  String eventId = 'event-1',
  String state = 'mapped',
  double? latitude = 29.3759,
  double? longitude = 47.9774,
  String? mapsUrl =
      'https://www.google.com/maps/dir/?api=1&destination=29.3759,47.9774',
  bool includeLatKey = true,
  bool includeLngKey = true,
  bool includeUrlKey = true,
}) {
  final map = <String, dynamic>{'event_id': eventId, 'location_state': state};
  if (includeLatKey) map['latitude'] = latitude;
  if (includeLngKey) map['longitude'] = longitude;
  if (includeUrlKey) map['maps_url'] = mapsUrl;
  return map;
}

Matcher _malformed() => isA<CalendarException>().having(
  (e) => e.code,
  'code',
  CalendarException.malformedResponse,
);

void main() {
  group('mapRouteDayResult', () {
    test('maps a valid day with mapped and non-mapped points', () {
      final result = mapRouteDayResult(
        _routeDayRpc(
          points: [
            _routePointRpc(),
            _routePointRpc(
              state: 'missing',
              includeLatKey: false,
              includeLngKey: false,
            ),
          ],
          hasMore: true,
        ),
      );

      expect(result.employeeId, 'emp-1');
      expect(result.points, hasLength(2));
      expect(result.hasMore, isTrue);
      expect(result.points.first.isMapped, isTrue);
      expect(result.points.last.isMapped, isFalse);
      expect(result.mappedPoints, hasLength(1));
    });

    test('live-shaped pending event with execution_summary JSON null maps', () {
      final event = validCalendarEventRpc(executionSummary: null);
      expect(event.containsKey('execution_summary'), isTrue);
      expect(event['execution_summary'], isNull);

      final result = mapRouteDayResult(
        _routeDayRpc(
          points: [
            {'event': event, 'location_state': 'missing'},
            _routePointRpc(),
          ],
        ),
      );

      expect(result.points, hasLength(2));
      expect(
        result.points.first.locationState,
        CalendarRouteLocationState.missing,
      );
      expect(result.points.first.event.executionSummary, isNull);
      expect(result.points.first.isMapped, isFalse);
      expect(result.mappedPoints, hasLength(1));
    });

    test('throws malformed when points is not a list', () {
      final raw = _routeDayRpc();
      raw['points'] = 'not-a-list';
      expect(() => mapRouteDayResult(raw), throwsA(_malformed()));
    });
  });

  group('mapRoutePoint', () {
    test('mapped state requires both latitude and longitude', () {
      expect(
        () => mapRoutePoint(
          _routePointRpc(state: 'mapped', includeLngKey: false),
        ),
        throwsA(_malformed()),
      );
      expect(
        () => mapRoutePoint(
          _routePointRpc(state: 'mapped', includeLatKey: false),
        ),
        throwsA(_malformed()),
      );
    });

    test('mapped state with valid coordinates parses successfully', () {
      final point = mapRoutePoint(_routePointRpc(state: 'mapped'));
      expect(point.locationState, CalendarRouteLocationState.mapped);
      expect(point.latitude, 29.3759);
      expect(point.longitude, 47.9774);
      expect(point.isMapped, isTrue);
    });

    for (final state in ['url_only', 'invalid', 'missing']) {
      test('$state state rejects a present latitude', () {
        expect(
          () =>
              mapRoutePoint(_routePointRpc(state: state, includeLngKey: false)),
          throwsA(_malformed()),
        );
      });

      test('$state state with no coordinates parses successfully', () {
        final point = mapRoutePoint(
          _routePointRpc(
            state: state,
            includeLatKey: false,
            includeLngKey: false,
          ),
        );
        expect(point.locationState.rpcValue, state);
        expect(point.latitude, isNull);
        expect(point.longitude, isNull);
        expect(point.isMapped, isFalse);
      });
    }

    test('unknown location_state is malformed', () {
      expect(
        () => mapRoutePoint(
          _routePointRpc(
            state: 'nonsense',
            includeLatKey: false,
            includeLngKey: false,
          ),
        ),
        throwsA(_malformed()),
      );
    });
  });

  group('mapDirectionsTarget', () {
    test('mapped state requires latitude, longitude, and maps_url', () {
      expect(
        () => mapDirectionsTarget(_directionsRpc(includeUrlKey: false)),
        throwsA(_malformed()),
      );
      expect(
        () => mapDirectionsTarget(_directionsRpc(includeLatKey: false)),
        throwsA(_malformed()),
      );
    });

    test('mapped state with full data parses successfully', () {
      final target = mapDirectionsTarget(_directionsRpc());
      expect(target.locationState, CalendarRouteLocationState.mapped);
      expect(target.latitude, 29.3759);
      expect(target.longitude, 47.9774);
      expect(target.mapsUrl, isNotNull);
      expect(target.hasCoordinates, isTrue);
    });

    test('url_only state rejects coordinates', () {
      expect(
        () => mapDirectionsTarget(
          _directionsRpc(state: 'url_only', includeLngKey: false),
        ),
        throwsA(_malformed()),
      );
    });

    test('url_only state requires maps_url', () {
      expect(
        () => mapDirectionsTarget(
          _directionsRpc(
            state: 'url_only',
            includeLatKey: false,
            includeLngKey: false,
            includeUrlKey: false,
          ),
        ),
        throwsA(_malformed()),
      );
    });

    test('url_only state with only maps_url parses successfully', () {
      final target = mapDirectionsTarget(
        _directionsRpc(
          state: 'url_only',
          includeLatKey: false,
          includeLngKey: false,
        ),
      );
      expect(target.locationState, CalendarRouteLocationState.urlOnly);
      expect(target.hasCoordinates, isFalse);
      expect(target.mapsUrl, isNotNull);
    });

    for (final state in ['invalid', 'missing']) {
      test('$state state should never resolve a directions target', () {
        expect(
          () => mapDirectionsTarget(
            _directionsRpc(
              state: state,
              includeLatKey: false,
              includeLngKey: false,
              includeUrlKey: false,
            ),
          ),
          throwsA(_malformed()),
        );
      });
    }
  });

  group('mapRouteEmployeesResult', () {
    test('maps rows and has_more', () {
      final result = mapRouteEmployeesResult({
        'rows': [
          {
            'employee_id': 'emp-1',
            'name_ar': 'موظف',
            'name_en': 'Employee',
            'is_active': true,
          },
        ],
        'has_more': true,
      });

      expect(result.employees, hasLength(1));
      expect(result.employees.first.employeeId, 'emp-1');
      expect(result.hasMore, isTrue);
    });

    test('throws malformed when a row is missing employee_id', () {
      expect(
        () => mapRouteEmployeesResult({
          'rows': [
            {'name_ar': 'موظف', 'is_active': true},
          ],
          'has_more': false,
        }),
        throwsA(_malformed()),
      );
    });
  });
}
