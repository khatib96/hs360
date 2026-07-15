import 'package:url_launcher/url_launcher.dart';

import '../domain/calendar_mutation_validators.dart';

/// Result of attempting to open an online meeting URL.
enum JoinMeetingResult { opened, invalidUrl, launchFailed }

typedef UriLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Opens a meeting URL only when it is a safe absolute HTTPS URL.
Future<JoinMeetingResult> joinCalendarMeeting(
  String? meetingUrl, {
  UriLauncher? launcher,
}) async {
  final url = meetingUrl?.trim() ?? '';
  if (url.isEmpty || !CalendarMutationValidators.isSafeHttpsUrl(url)) {
    return JoinMeetingResult.invalidUrl;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return JoinMeetingResult.invalidUrl;

  try {
    final launch = launcher ?? _defaultLaunch;
    final ok = await launch(uri, mode: LaunchMode.externalApplication);
    return ok ? JoinMeetingResult.opened : JoinMeetingResult.launchFailed;
  } catch (_) {
    return JoinMeetingResult.launchFailed;
  }
}

Future<bool> _defaultLaunch(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
}) {
  return launchUrl(uri, mode: mode);
}
