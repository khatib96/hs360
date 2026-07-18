import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_date.dart';
import '../calendar_labels.dart';

/// Prev/next day navigation for Route View, independent of the month grid
/// used by the main Calendar screen (Route View is a single-day tool).
///
/// Uses Material chevrons with [matchTextDirection] so glyphs remain visible
/// and correctly oriented under RTL (unlike some custom icon fonts).
class CalendarRouteDateBar extends StatelessWidget {
  const CalendarRouteDateBar({
    required this.selectedDate,
    required this.onSelectDate,
    super.key,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      key: const Key('calendar-route-date-bar'),
      children: [
        IconButton(
          key: const Key('calendar-route-prev-day'),
          tooltip: l10n.calendarPreviousDay,
          onPressed: () => onSelectDate(addCalendarDays(selectedDate, -1)),
          icon: const Icon(
            Icons.chevron_left,
            key: Key('calendar-route-prev-day-icon'),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              calendarLocalizedDate(l10n, selectedDate),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        IconButton(
          key: const Key('calendar-route-next-day'),
          tooltip: l10n.calendarNextDay,
          onPressed: () => onSelectDate(addCalendarDays(selectedDate, 1)),
          icon: const Icon(
            Icons.chevron_right,
            key: Key('calendar-route-next-day-icon'),
          ),
        ),
      ],
    );
  }
}
