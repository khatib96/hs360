import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/calendar_settings.dart';
import '../../domain/calendar_working_date_exception.dart';
import '../calendar_labels.dart';

/// A single working-date exception row inside the settings section list.
class CalendarWorkingDateExceptionListTile extends StatelessWidget {
  const CalendarWorkingDateExceptionListTile({
    required this.exception,
    required this.canEdit,
    required this.onEdit,
    required this.onCancel,
    super.key,
  });

  final WorkingDateException exception;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final isCancelled =
        exception.status == CalendarWorkingDateExceptionStatus.cancelled;

    final title = exception.titleFallback(locale);
    final range = exception.startDate == exception.endDate
        ? calendarLocalizedDate(l10n, exception.startDate)
        : l10n.calendarWorkingDateExceptionDateRange(
            calendarLocalizedDate(l10n, exception.startDate),
            calendarLocalizedDate(l10n, exception.endDate),
          );

    return Card(
      key: ValueKey('calendar-wde-tile-${exception.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _kindIcon(exception.kind),
              color: isCancelled ? AppColors.neutral400 : AppColors.gold,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty
                        ? calendarWorkingDateExceptionKindLabel(
                            l10n,
                            exception.kind,
                          )
                        : title,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(range, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _tag(
                        context,
                        calendarWorkingDateExceptionKindLabel(
                          l10n,
                          exception.kind,
                        ),
                      ),
                      _tag(
                        context,
                        calendarWorkingDateExceptionStatusLabel(
                          l10n,
                          exception.status,
                        ),
                        emphasize: isCancelled,
                      ),
                      if (exception.kind ==
                              CalendarWorkingDateExceptionKind
                                  .exceptionalWorkingDay &&
                          exception.dayMode != null)
                        _tag(
                          context,
                          exception.dayMode == TenantWorkingDayMode.hours24
                              ? l10n.calendarWorkingDateExceptionDayMode24Hours
                              : l10n.calendarWorkingWindow(
                                  exception.workStart ?? '',
                                  exception.workEnd ?? '',
                                ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (canEdit && !isCancelled)
              Row(
                children: [
                  IconButton(
                    key: ValueKey('calendar-wde-edit-${exception.id}'),
                    tooltip: l10n.calendarWorkingDateExceptionEditAction,
                    icon: const Icon(LucideIcons.pencil, size: 18),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    key: ValueKey('calendar-wde-cancel-${exception.id}'),
                    tooltip: l10n.calendarWorkingDateExceptionCancelAction,
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: onCancel,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String label, {bool emphasize = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasize
            ? AppColors.neutral200
            : AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  IconData _kindIcon(CalendarWorkingDateExceptionKind kind) {
    return switch (kind) {
      CalendarWorkingDateExceptionKind.officialHoliday =>
        LucideIcons.calendar_off,
      CalendarWorkingDateExceptionKind.companyClosure =>
        LucideIcons.calendar_off,
      CalendarWorkingDateExceptionKind.exceptionalWorkingDay =>
        LucideIcons.calendar_clock,
    };
  }
}
