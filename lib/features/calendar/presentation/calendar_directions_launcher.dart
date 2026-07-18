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
      final ok = await _launcher(
        option.uri,
        mode: LaunchMode.externalApplication,
      );
      return ok
          ? CalendarDirectionsResult.opened
          : CalendarDirectionsResult.launchFailed;
    } catch (_) {
      return CalendarDirectionsResult.launchFailed;
    }
  }
}

Future<bool> _defaultLaunch(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
}) {
  return launchUrl(uri, mode: mode);
}
