import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/calendar_range_summary.dart';
import '../../domain/calendar_working_day.dart';
import '../calendar_labels.dart';

class CalendarAgendaHeader extends StatelessWidget {
  const CalendarAgendaHeader({
    required this.selectedDate,
    required this.workingDay,
    required this.daySummary,
    super.key,
  });

  final DateTime selectedDate;
  final CalendarWorkingDay? workingDay;
  final CalendarDaySummary? daySummary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final status = workingDay == null
        ? l10n.calendarDayModeUnreviewed
        : calendarWorkingStatusText(l10n, workingDay!);
    final dateException = workingDay?.dateException;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          calendarLocalizedDate(l10n, selectedDate),
          key: const Key('calendar-agenda-date'),
          style: theme.textTheme.titleMedium,
        ),
        if (dateException != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.calendarAgendaExceptionLabel(
              calendarDateExceptionKindTitleText(
                l10n,
                kind: dateException.kind,
                title: dateException.titleFallback(
                  Localizations.localeOf(context).languageCode,
                ),
              ),
            ),
            key: const Key('calendar-agenda-exception-title'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.goldDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          status,
          key: const Key('calendar-agenda-working-status'),
          style: theme.textTheme.bodyMedium,
        ),
        if (daySummary != null) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              Text(l10n.calendarDayEventCount(daySummary!.eventCount)),
              if (daySummary!.unassignedCount != null)
                Text(
                  l10n.calendarDayUnassignedCount(daySummary!.unassignedCount!),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
