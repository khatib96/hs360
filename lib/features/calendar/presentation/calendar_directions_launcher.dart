import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:url_launcher/url_launcher.dart';

import 'calendar_map_app_option.dart';

/// Result of launching a user-selected map option (never auto-picked).
enum CalendarDirectionsResult { opened, invalidTarget, launchFailed, cancelled }

typedef UriLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Launches a [CalendarMapAppOption] the user explicitly chose.
///
/// Does **not** pick an app or open maps automatically — that belongs to
/// [CalendarMapAppResolver] + the Open-with sheet.
class CalendarDirectionsLauncher {
  const CalendarDirectionsLauncher({UriLauncher? launcher})
    : _launcher = launcher ?? _defaultLaunch;

  final UriLauncher _launcher;

  Future<CalendarDirectionsResult> launch(CalendarMapAppOption? option) async {
    if (option == null) return CalendarDirectionsResult.cancelled;
    try {
      final uri = _uriForOption(option);
      final ok = await _launcher(uri, mode: LaunchMode.externalApplication);
      return ok
          ? CalendarDirectionsResult.opened
          : CalendarDirectionsResult.launchFailed;
    } catch (_) {
      return CalendarDirectionsResult.launchFailed;
    }
  }
}

/// Browser choice must open a browser — not an App Link handler (Maps).
Uri _uriForOption(CalendarMapAppOption option) {
  final uri = option.uri;
  if (option.kind != CalendarMapAppKind.browser) return uri;
  if (option.platform != TargetPlatform.android) return uri;
  if (!(uri.isScheme('https') || uri.isScheme('http'))) return uri;
  return Uri.parse(
    'googlechrome://navigate?url=${Uri.encodeComponent(uri.toString())}',
  );
}

Future<bool> _defaultLaunch(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
}) {
  return launchUrl(uri, mode: mode);
}
