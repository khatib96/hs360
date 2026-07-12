import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_settings.dart';

class CalendarWorkingDayEditor extends StatelessWidget {
  const CalendarWorkingDayEditor({
    super.key,
    required this.day,
    required this.canEdit,
    required this.onChanged,
    this.errorCode,
  });

  final WorkingDayRow day;
  final bool canEdit;
  final String? errorCode;
  final ValueChanged<WorkingDayRow> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _weekdayLabel(l10n, day.isoWeekday),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<TenantWorkingDayMode>(
              key: ValueKey('calendar-day-mode-${day.isoWeekday}'),
              initialValue: day.mode,
              decoration: InputDecoration(
                labelText: l10n.calendarSettingsDayMode,
                errorText: errorCode != null
                    ? l10n.calendarSettingsDayValidationError
                    : null,
              ),
              items: TenantWorkingDayMode.values
                  .map(
                    (mode) => DropdownMenuItem(
                      value: mode,
                      child: Text(_modeLabel(l10n, mode)),
                    ),
                  )
                  .toList(),
              onChanged: canEdit
                  ? (mode) {
                      if (mode == null) return;
                      onChanged(
                        day.copyWith(
                          mode: mode,
                          workStart: mode == TenantWorkingDayMode.workingHours
                              ? (day.workStart.isEmpty
                                    ? '08:00'
                                    : day.workStart)
                              : '',
                          workEnd: mode == TenantWorkingDayMode.workingHours
                              ? (day.workEnd.isEmpty ? '17:00' : day.workEnd)
                              : '',
                        ),
                      );
                    }
                  : null,
            ),
            if (day.mode == TenantWorkingDayMode.workingHours) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('calendar-day-start-${day.isoWeekday}'),
                      initialValue: day.workStart,
                      enabled: canEdit,
                      decoration: InputDecoration(
                        labelText: l10n.calendarSettingsWorkStart,
                      ),
                      onChanged: (value) =>
                          onChanged(day.copyWith(workStart: value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('calendar-day-end-${day.isoWeekday}'),
                      initialValue: day.workEnd,
                      enabled: canEdit,
                      decoration: InputDecoration(
                        labelText: l10n.calendarSettingsWorkEnd,
                      ),
                      onChanged: (value) =>
                          onChanged(day.copyWith(workEnd: value)),
                    ),
                  ),
                ],
              ),
              if (day.workStart.isNotEmpty && day.workEnd.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.calendarSettingsDaySummary(day.workStart, day.workEnd),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _weekdayLabel(AppLocalizations l10n, int isoWeekday) {
    return switch (isoWeekday) {
      1 => l10n.calendarWeekdayMonday,
      2 => l10n.calendarWeekdayTuesday,
      3 => l10n.calendarWeekdayWednesday,
      4 => l10n.calendarWeekdayThursday,
      5 => l10n.calendarWeekdayFriday,
      6 => l10n.calendarWeekdaySaturday,
      7 => l10n.calendarWeekdaySunday,
      _ => '$isoWeekday',
    };
  }

  String _modeLabel(AppLocalizations l10n, TenantWorkingDayMode mode) {
    return switch (mode) {
      TenantWorkingDayMode.unreviewed => l10n.calendarDayModeUnreviewed,
      TenantWorkingDayMode.dayOff => l10n.calendarDayModeDayOff,
      TenantWorkingDayMode.workingHours => l10n.calendarDayModeWorkingHours,
      TenantWorkingDayMode.hours24 => l10n.calendarDayMode24Hours,
    };
  }
}
