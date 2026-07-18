import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:url_launcher/url_launcher.dart';

import '../domain/calendar_directions_target.dart';
import '../domain/calendar_mutation_validators.dart';
import '../domain/calendar_route_location_state.dart';
import 'calendar_map_app_option.dart';

typedef CanLaunchUri = Future<bool> Function(Uri uri);

/// Builds compatible map-app options for a directions target without launching.
class CalendarMapAppResolver {
  const CalendarMapAppResolver({this.canLaunch = _defaultCanLaunch});

  final CanLaunchUri canLaunch;

  Future<List<CalendarMapAppOption>> resolve(
    CalendarDirectionsTarget target, {
    TargetPlatform? platform,
  }) async {
    final p = platform ?? defaultTargetPlatform;
    if (target.locationState == CalendarRouteLocationState.mapped &&
        target.latitude != null &&
        target.longitude != null) {
      return _resolveMapped(target.latitude!, target.longitude!, p);
    }
    if (target.locationState == CalendarRouteLocationState.urlOnly) {
      return _resolveUrlOnly(target, p);
    }
    return const [];
  }

  Future<List<CalendarMapAppOption>> _resolveMapped(
    double lat,
    double lng,
    TargetPlatform platform,
  ) async {
    final options = <CalendarMapAppOption>[];
    final browserUri = httpsDirectionsFromCoords(lat, lng);

    switch (platform) {
      case TargetPlatform.iOS:
        // Apple Maps is always available on iOS; use the official HTTPS URL
        // (no undocumented `maps:` scheme probe).
        options.add(
          CalendarMapAppOption(
            kind: CalendarMapAppKind.appleMaps,
            uri: appleMapsUri(lat, lng),
            platform: platform,
          ),
        );
        await _addIfLaunchable(
          options,
          CalendarMapAppOption(
            kind: CalendarMapAppKind.googleMaps,
            uri: googleMapsIosUri(lat, lng),
            platform: platform,
          ),
        );
        await _addIfLaunchable(
          options,
          CalendarMapAppOption(
            kind: CalendarMapAppKind.waze,
            uri: wazeUri(lat, lng),
            platform: platform,
          ),
        );
        options.add(
          CalendarMapAppOption(
            kind: CalendarMapAppKind.browser,
            uri: browserUri,
            platform: platform,
          ),
        );
      case TargetPlatform.android:
        await _addIfLaunchable(
          options,
          CalendarMapAppOption(
            kind: CalendarMapAppKind.systemMaps,
            uri: androidGeoUri(lat, lng),
            platform: platform,
          ),
        );
        await _addIfLaunchable(
          options,
          CalendarMapAppOption(
            kind: CalendarMapAppKind.googleMaps,
            uri: googleMapsAndroidUri(lat, lng),
            platform: platform,
          ),
        );
        await _addIfLaunchable(
          options,
          CalendarMapAppOption(
            kind: CalendarMapAppKind.waze,
            uri: wazeUri(lat, lng),
            platform: platform,
          ),
        );
        options.add(
          CalendarMapAppOption(
            kind: CalendarMapAppKind.browser,
            uri: browserUri,
            platform: platform,
          ),
        );
      default:
        options.add(
          CalendarMapAppOption(
            kind: CalendarMapAppKind.browser,
            uri: browserUri,
            platform: platform,
          ),
        );
    }
    return List.unmodifiable(options);
  }

  Future<List<CalendarMapAppOption>> _resolveUrlOnly(
    CalendarDirectionsTarget target,
    TargetPlatform platform,
  ) async {
    final url = target.mapsUrl?.trim() ?? '';
    if (url.isEmpty || !isAllowlistedMapsUrl(url)) return const [];
    final httpsUri = Uri.tryParse(url);
    if (httpsUri == null) return const [];

    // Do not invent coordinates. Do not offer a "Google Maps" row that only
    // opens the same HTTPS URL in a browser — Browser is the safe option.
    return List.unmodifiable([
      CalendarMapAppOption(
        kind: CalendarMapAppKind.browser,
        uri: httpsUri,
        platform: platform,
      ),
    ]);
  }

  Future<void> _addIfLaunchable(
    List<CalendarMapAppOption> options,
    CalendarMapAppOption option,
  ) async {
    if (await _safeCanLaunch(option.uri)) {
      options.add(option);
    }
  }

  Future<bool> _safeCanLaunch(Uri uri) async {
    try {
      return await canLaunch(uri);
    } catch (_) {
      return false;
    }
  }

  // --- URI builders (public for unit tests) ---

  static Uri httpsDirectionsFromCoords(double lat, double lng) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
    });
  }

  /// Official Apple Maps HTTPS directions URL (`maps.apple.com`).
  static Uri appleMapsUri(double lat, double lng) {
    return Uri.https('maps.apple.com', '/', {'daddr': '$lat,$lng'});
  }

  static Uri googleMapsIosUri(double lat, double lng) {
    return Uri(
      scheme: 'comgooglemaps',
      queryParameters: {'daddr': '$lat,$lng'},
    );
  }

  static Uri googleMapsAndroidUri(double lat, double lng) {
    return Uri.parse('google.navigation:q=$lat,$lng');
  }

  static Uri androidGeoUri(double lat, double lng) {
    return Uri.parse('geo:$lat,$lng?q=$lat,$lng');
  }

  static Uri wazeUri(double lat, double lng) {
    return Uri(
      scheme: 'waze',
      queryParameters: {'ll': '$lat,$lng', 'navigate': 'yes'},
    );
  }

  static const allowlistedMapsHosts = {
    'google.com',
    'www.google.com',
    'maps.google.com',
    'www.maps.google.com',
    'maps.app.goo.gl',
  };

  static bool isAllowlistedMapsUrl(String url) {
    if (!CalendarMutationValidators.isSafeHttpsUrl(url)) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    return allowlistedMapsHosts.contains(uri.host.toLowerCase());
  }

  static Future<bool> _defaultCanLaunch(Uri uri) => canLaunchUrl(uri);
}
