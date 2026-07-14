import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../calendar_labels.dart';

class CalendarMonthToolbar extends StatelessWidget {
  const CalendarMonthToolbar({
    required this.focusedMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onMonthSelected,
    super.key,
  });

  static const int firstSelectableYear = 2000;
  static const int lastSelectableYear = 2100;

  final DateTime focusedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final firstYear = focusedMonth.year < firstSelectableYear
        ? focusedMonth.year
        : firstSelectableYear;
    final lastYear = focusedMonth.year > lastSelectableYear
        ? focusedMonth.year
        : lastSelectableYear;

    return Row(
      children: [
        IconButton(
          key: const Key('calendar-prev-month'),
          tooltip: l10n.calendarPreviousMonth,
          onPressed: onPrevious,
          icon: Icon(
            rtl ? LucideIcons.chevron_right : LucideIcons.chevron_left,
          ),
        ),
        Expanded(
          child: Wrap(
            key: const Key('calendar-month-title'),
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            children: [
              PopupMenuButton<int>(
                key: const Key('calendar-month-selector'),
                tooltip: l10n.calendarSelectMonth,
                initialValue: focusedMonth.month,
                constraints: const BoxConstraints(
                  minWidth: 160,
                  maxHeight: 420,
                ),
                onSelected: (month) =>
                    onMonthSelected(DateTime(focusedMonth.year, month)),
                itemBuilder: (context) => [
                  for (var month = 1; month <= 12; month++)
                    CheckedPopupMenuItem<int>(
                      value: month,
                      checked: month == focusedMonth.month,
                      child: Text(calendarMonthName(l10n, month)),
                    ),
                ],
                child: _SelectorLabel(
                  label: calendarMonthName(l10n, focusedMonth.month),
                ),
              ),
              PopupMenuButton<int>(
                key: const Key('calendar-year-selector'),
                tooltip: l10n.calendarSelectYear,
                initialValue: focusedMonth.year,
                constraints: const BoxConstraints(
                  minWidth: 120,
                  maxHeight: 420,
                ),
                onSelected: (year) =>
                    onMonthSelected(DateTime(year, focusedMonth.month)),
                itemBuilder: (context) => [
                  for (var year = firstYear; year <= lastYear; year++)
                    CheckedPopupMenuItem<int>(
                      value: year,
                      checked: year == focusedMonth.year,
                      child: Text('$year'),
                    ),
                ],
                child: _SelectorLabel(label: '${focusedMonth.year}'),
              ),
            ],
          ),
        ),
        TextButton(
          key: const Key('calendar-today'),
          onPressed: onToday,
          child: Text(l10n.calendarToday),
        ),
        IconButton(
          key: const Key('calendar-next-month'),
          tooltip: l10n.calendarNextMonth,
          onPressed: onNext,
          icon: Icon(
            rtl ? LucideIcons.chevron_left : LucideIcons.chevron_right,
          ),
        ),
      ],
    );
  }
}

class _SelectorLabel extends StatelessWidget {
  const _SelectorLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 20, color: style?.color),
        ],
      ),
    );
  }
}
