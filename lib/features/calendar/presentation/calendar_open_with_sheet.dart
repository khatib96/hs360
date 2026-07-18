import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import 'calendar_map_app_option.dart';

/// In-app "Open with" / "فتح باستخدام" chooser. Returns null on cancel.
Future<CalendarMapAppOption?> showCalendarOpenWithSheet({
  required BuildContext context,
  required List<CalendarMapAppOption> options,
}) {
  assert(options.isNotEmpty, 'Open-with sheet requires at least one option');
  return showModalBottomSheet<CalendarMapAppOption>(
    context: context,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    l10n.calendarOpenWithTitle,
                    key: const Key('calendar-open-with-title'),
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                for (final option in options)
                  ListTile(
                    key: Key('calendar-open-with-${option.kind.name}'),
                    leading: Icon(_iconFor(option.kind)),
                    title: Text(_labelFor(l10n, option.kind)),
                    onTap: () => Navigator.of(sheetContext).pop(option),
                  ),
                ListTile(
                  key: const Key('calendar-open-with-cancel'),
                  leading: const Icon(Icons.close),
                  title: Text(l10n.calendarOpenWithCancel),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

IconData _iconFor(CalendarMapAppKind kind) {
  switch (kind) {
    case CalendarMapAppKind.appleMaps:
      return Icons.map_outlined;
    case CalendarMapAppKind.googleMaps:
      return Icons.map;
    case CalendarMapAppKind.waze:
      return Icons.navigation_outlined;
    case CalendarMapAppKind.systemMaps:
      return Icons.explore_outlined;
    case CalendarMapAppKind.browser:
      return Icons.public;
  }
}

String _labelFor(AppLocalizations l10n, CalendarMapAppKind kind) {
  switch (kind) {
    case CalendarMapAppKind.appleMaps:
      return l10n.calendarOpenWithAppleMaps;
    case CalendarMapAppKind.googleMaps:
      return l10n.calendarOpenWithGoogleMaps;
    case CalendarMapAppKind.waze:
      return l10n.calendarOpenWithWaze;
    case CalendarMapAppKind.systemMaps:
      return l10n.calendarOpenWithSystemMaps;
    case CalendarMapAppKind.browser:
      return l10n.calendarOpenWithBrowser;
  }
}
