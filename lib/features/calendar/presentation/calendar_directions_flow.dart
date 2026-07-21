import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../domain/calendar_directions_target.dart';
import 'calendar_directions_launcher.dart';
import 'calendar_map_app_resolver.dart';
import 'calendar_open_with_sheet.dart';

/// Fetches nothing — presents Open-with for an already-loaded [target].
///
/// Never auto-launches. Cancel leaves the list/dialog data intact.
Future<CalendarDirectionsResult> presentCalendarDirectionsChooser({
  required BuildContext context,
  required CalendarDirectionsTarget target,
  CalendarMapAppResolver resolver = const CalendarMapAppResolver(),
  CalendarDirectionsLauncher launcher = const CalendarDirectionsLauncher(),
  TargetPlatform? platform,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final options = await resolver.resolve(
    target,
    platform: platform ?? defaultTargetPlatform,
  );
  if (!context.mounted) return CalendarDirectionsResult.cancelled;
  if (options.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.calendarDirectionsFailed)));
    return CalendarDirectionsResult.invalidTarget;
  }

  final selected = await showCalendarOpenWithSheet(
    context: context,
    options: options,
  );
  if (!context.mounted) return CalendarDirectionsResult.cancelled;
  if (selected == null) return CalendarDirectionsResult.cancelled;

  final result = await launcher.launch(selected);
  if (result == CalendarDirectionsResult.launchFailed && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.calendarDirectionsFailed)));
  }
  return result;
}
