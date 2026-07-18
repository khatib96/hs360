import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_directions_target.dart';
import 'package:hs360/features/calendar/domain/calendar_route_location_state.dart';
import 'package:hs360/features/calendar/presentation/calendar_directions_launcher.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_app_option.dart';
import 'package:hs360/features/calendar/presentation/calendar_map_app_resolver.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

const _mappedTarget = CalendarDirectionsTarget(
  eventId: 'event-1',
  locationState: CalendarRouteLocationState.mapped,
  latitude: 29.3759,
  longitude: 47.9774,
  mapsUrl: 'https://www.google.com/maps/dir/?api=1&destination=29.3759,47.9774',
);

const _urlOnlyTarget = CalendarDirectionsTarget(
  eventId: 'event-2',
  locationState: CalendarRouteLocationState.urlOnly,
  mapsUrl: 'https://maps.app.goo.gl/abc123',
);

void main() {
  group('CalendarMapAppResolver', () {
    test('iOS mapped offers Apple HTTPS + Google/Waze when launchable + browser',
        () async {
      final resolver = CalendarMapAppResolver(canLaunch: (_) async => true);
      final options = await resolver.resolve(
        _mappedTarget,
        platform: TargetPlatform.iOS,
      );
      expect(
        options.map((o) => o.kind).toList(),
        [
          CalendarMapAppKind.appleMaps,
          CalendarMapAppKind.googleMaps,
          CalendarMapAppKind.waze,
          CalendarMapAppKind.browser,
        ],
      );
      final apple = options.firstWhere((o) => o.kind == CalendarMapAppKind.appleMaps);
      expect(apple.uri.scheme, 'https');
      expect(apple.uri.host, 'maps.apple.com');
      expect(apple.uri.queryParameters['daddr'], '29.3759,47.9774');
      expect(options.last.uri.scheme, 'https');
    });

    test('Apple Maps HTTPS URI is built with Uri.https (no maps: scheme)', () {
      final uri = CalendarMapAppResolver.appleMapsUri(29.3759, 47.9774);
      expect(uri, Uri.https('maps.apple.com', '/', {'daddr': '29.3759,47.9774'}));
      expect(uri.scheme, isNot(equals('maps')));
    });

    test('Android mapped offers system/Google/Waze when launchable + browser', () async {
      final resolver = CalendarMapAppResolver(canLaunch: (_) async => true);
      final options = await resolver.resolve(
        _mappedTarget,
        platform: TargetPlatform.android,
      );
      expect(options.map((o) => o.kind).toList(), [
        CalendarMapAppKind.systemMaps,
        CalendarMapAppKind.googleMaps,
        CalendarMapAppKind.waze,
        CalendarMapAppKind.browser,
      ]);
      expect(options.first.uri.scheme, 'geo');
    });

    test('desktop mapped offers browser only', () async {
      final resolver = CalendarMapAppResolver(canLaunch: (_) async => true);
      final options = await resolver.resolve(
        _mappedTarget,
        platform: TargetPlatform.macOS,
      );
      expect(options.map((o) => o.kind).toList(), [CalendarMapAppKind.browser]);
    });

    test('hides probed apps that cannot launch; Apple Maps still offered on iOS',
        () async {
      final resolver = CalendarMapAppResolver(
        canLaunch: (_) async => false,
      );
      final options = await resolver.resolve(
        _mappedTarget,
        platform: TargetPlatform.iOS,
      );
      expect(options.map((o) => o.kind).toList(), [
        CalendarMapAppKind.appleMaps,
        CalendarMapAppKind.browser,
      ]);
    });

    test('url_only offers Browser only; never invents coords or fake Google Maps',
        () async {
      final resolver = CalendarMapAppResolver(canLaunch: (_) async => true);
      final options = await resolver.resolve(
        _urlOnlyTarget,
        platform: TargetPlatform.iOS,
      );
      expect(options.map((o) => o.kind).toList(), [CalendarMapAppKind.browser]);
      expect(options.single.uri.toString(), _urlOnlyTarget.mapsUrl);
      expect(
        options.any((o) => o.kind == CalendarMapAppKind.googleMaps),
        isFalse,
      );
      expect(
        options.any((o) => o.kind == CalendarMapAppKind.appleMaps),
        isFalse,
      );
      expect(options.any((o) => o.kind == CalendarMapAppKind.waze), isFalse);
    });

    test('invalid/missing targets yield no options', () async {
      final resolver = CalendarMapAppResolver(canLaunch: (_) async => true);
      expect(
        await resolver.resolve(
          const CalendarDirectionsTarget(
            eventId: 'x',
            locationState: CalendarRouteLocationState.invalid,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('CalendarDirectionsLauncher', () {
    test('does not launch when option is null (cancel)', () async {
      var launched = false;
      final launcher = CalendarDirectionsLauncher(
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          launched = true;
          return true;
        },
      );
      final result = await launcher.launch(null);
      expect(result, CalendarDirectionsResult.cancelled);
      expect(launched, isFalse);
    });

    test('launches selected option URI', () async {
      Uri? launched;
      final launcher = CalendarDirectionsLauncher(
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          launched = uri;
          return true;
        },
      );
      final option = CalendarMapAppOption(
        kind: CalendarMapAppKind.browser,
        uri: CalendarMapAppResolver.httpsDirectionsFromCoords(29.3, 48.0),
        platform: TargetPlatform.macOS,
      );
      final result = await launcher.launch(option);
      expect(result, CalendarDirectionsResult.opened);
      expect(launched!.scheme, 'https');
    });

    test('reports launchFailed when launcher returns false', () async {
      final launcher = CalendarDirectionsLauncher(
        launcher: (uri, {mode = LaunchMode.platformDefault}) async => false,
      );
      final option = CalendarMapAppOption(
        kind: CalendarMapAppKind.browser,
        uri: Uri.parse('https://www.google.com/maps'),
        platform: TargetPlatform.android,
      );
      expect(await launcher.launch(option), CalendarDirectionsResult.launchFailed);
    });
  });
}
