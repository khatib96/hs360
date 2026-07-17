import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_settings.dart';
import '../../domain/calendar_working_date_exception.dart';
import '../calendar_labels.dart';

/// Renders the create/edit field set; state lives in the dialog.
class CalendarWorkingDateExceptionFormBody extends StatelessWidget {
  const CalendarWorkingDateExceptionFormBody({
    required this.kind,
    required this.startDate,
    required this.endDate,
    required this.titleAr,
    required this.titleEn,
    required this.notes,
    required this.dayMode,
    required this.workStart,
    required this.workEnd,
    required this.onKindChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onDayModeChanged,
    super.key,
  });

  final CalendarWorkingDateExceptionKind? kind;
  final DateTime? startDate;
  final DateTime? endDate;
  final TextEditingController titleAr;
  final TextEditingController titleEn;
  final TextEditingController notes;
  final TenantWorkingDayMode? dayMode;
  final TextEditingController workStart;
  final TextEditingController workEnd;
  final ValueChanged<CalendarWorkingDateExceptionKind?> onKindChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final ValueChanged<TenantWorkingDayMode?> onDayModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showHours = kind?.allowsWorkingHoursOverride ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<CalendarWorkingDateExceptionKind>(
          key: const Key('calendar-wde-kind'),
          initialValue: kind,
          decoration: InputDecoration(
            labelText: l10n.calendarWorkingDateExceptionKindLabel,
          ),
          items: CalendarWorkingDateExceptionKind.values
              .map(
                (k) => DropdownMenuItem(
                  value: k,
                  child: Text(calendarWorkingDateExceptionKindLabel(l10n, k)),
                ),
              )
              .toList(),
          onChanged: onKindChanged,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DatePickerField(
                keyValue: const Key('calendar-wde-start-date'),
                label: l10n.calendarWorkingDateExceptionStartDate,
                date: startDate,
                onTap: onPickStartDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DatePickerField(
                keyValue: const Key('calendar-wde-end-date'),
                label: l10n.calendarWorkingDateExceptionEndDate,
                date: endDate,
                onTap: onPickEndDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('calendar-wde-title-ar'),
          controller: titleAr,
          decoration: InputDecoration(
            labelText: l10n.calendarWorkingDateExceptionTitleAr,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('calendar-wde-title-en'),
          controller: titleEn,
          decoration: InputDecoration(
            labelText: l10n.calendarWorkingDateExceptionTitleEn,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('calendar-wde-notes'),
          controller: notes,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.calendarWorkingDateExceptionNotes,
          ),
        ),
        if (showHours) ...[
          const SizedBox(height: 16),
          Text(
            l10n.calendarWorkingDateExceptionDayModeLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<TenantWorkingDayMode>(
            key: const Key('calendar-wde-day-mode'),
            segments: [
              ButtonSegment(
                value: TenantWorkingDayMode.hours24,
                label: Text(l10n.calendarWorkingDateExceptionDayMode24Hours),
              ),
              ButtonSegment(
                value: TenantWorkingDayMode.workingHours,
                label: Text(
                  l10n.calendarWorkingDateExceptionDayModeLimitedHours,
                ),
              ),
            ],
            selected: dayMode == null ? const {} : {dayMode!},
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) =>
                onDayModeChanged(selection.isEmpty ? null : selection.first),
          ),
          if (dayMode == TenantWorkingDayMode.workingHours) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('calendar-wde-work-start'),
                    controller: workStart,
                    decoration: InputDecoration(
                      labelText: l10n.calendarSettingsWorkStart,
                      hintText: '08:00',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('calendar-wde-work-end'),
                    controller: workEnd,
                    decoration: InputDecoration(
                      labelText: l10n.calendarSettingsWorkEnd,
                      hintText: '17:00',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.keyValue,
    required this.label,
    required this.date,
    required this.onTap,
  });

  final Key keyValue;
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      key: keyValue,
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(date == null ? '—' : calendarLocalizedDate(l10n, date!)),
      ),
    );
  }
}
