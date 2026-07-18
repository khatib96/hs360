import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/calendar_date.dart';
import '../../domain/calendar_month_grid.dart';
import '../../domain/calendar_range_summary.dart';
import '../calendar_labels.dart';
import 'calendar_month_toolbar.dart';

/// Fixed 7-day week strip derived from [selectedDate] (no independent week state).
///
/// Prev/Next week call [onSelectDate] with `selectedDate ± 7` via the parent
/// controller (`selectGridDate`). Month navigation is separate.
class CalendarMobileDateNav extends StatelessWidget {
  const CalendarMobileDateNav({
    required this.focusedMonth,
    required this.selectedDate,
    required this.firstDayOfWeekIndex,
    required this.tenantLocalToday,
    required this.daysByDate,
    required this.onSelectDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onMonthSelected,
    super.key,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final int firstDayOfWeekIndex;
  final DateTime? tenantLocalToday;
  final Map<DateTime, CalendarDaySummary> daysByDate;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final weekDays = calendarWeekDaysContaining(
      selectedDate,
      firstDayOfWeekIndex: firstDayOfWeekIndex,
    );
    final today = tenantLocalToday == null
        ? null
        : calendarDateOnly(tenantLocalToday!);

    return Column(
      key: const Key('calendar-mobile-date-nav'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarMonthToolbar(
          focusedMonth: focusedMonth,
          onPrevious: onPreviousMonth,
          onNext: onNextMonth,
          onToday: onToday,
          onMonthSelected: onMonthSelected,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              key: const Key('calendar-prev-week'),
              tooltip: l10n.calendarPreviousWeek,
              onPressed: () => onSelectDate(addCalendarDays(selectedDate, -7)),
              icon: Icon(
                rtl ? LucideIcons.chevron_right : LucideIcons.chevron_left,
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  for (final day in weekDays)
                    Expanded(
                      child: _MobileDayCell(
                        date: day,
                        selected:
                            calendarDateOnly(day) ==
                            calendarDateOnly(selectedDate),
                        isToday:
                            today != null && calendarDateOnly(day) == today,
                        summary: daysByDate[calendarDateOnly(day)],
                        onTap: () => onSelectDate(day),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              key: const Key('calendar-next-week'),
              tooltip: l10n.calendarNextWeek,
              onPressed: () => onSelectDate(addCalendarDays(selectedDate, 7)),
              icon: Icon(
                rtl ? LucideIcons.chevron_left : LucideIcons.chevron_right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileDayCell extends StatelessWidget {
  const _MobileDayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.summary,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final CalendarDaySummary? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eventCount = summary?.eventCount ?? 0;
    final isDayOff = summary?.workingDay.isDayOff == true;
    final weekdayLabels = MaterialLocalizations.of(context).narrowWeekdays;
    // Material narrowWeekdays: index 0 = Sunday.
    final weekdayLabel = weekdayLabels[materialWeekdayIndex(date)];

    final semanticsParts = <String>[
      calendarLocalizedDate(l10n, date),
      if (isToday) l10n.calendarToday,
      if (selected) l10n.calendarMobileDaySelected,
      if (eventCount > 0) l10n.calendarDayEventCount(eventCount),
      if (isDayOff) l10n.calendarDayModeDayOff,
    ];

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsParts.join(', '),
      child: InkWell(
        key: Key('calendar-mobile-day-${date.year}-${date.month}-${date.day}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : isToday
                  ? scheme.surfaceContainerHighest
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: isToday && !selected
                  ? Border.all(color: scheme.primary)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayLabel,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${date.day}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: isDayOff && !selected ? AppColors.neutral600 : null,
                  ),
                ),
                SizedBox(
                  height: 6,
                  child: eventCount > 0
                      ? Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
