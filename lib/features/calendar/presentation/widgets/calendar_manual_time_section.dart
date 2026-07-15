import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

/// Optional local time window toggle and start/end pickers.
class CalendarManualTimeSection extends StatelessWidget {
  const CalendarManualTimeSection({
    required this.setTime,
    required this.startTime,
    required this.endTime,
    required this.onSetTimeChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.formatTimeOfDay,
    super.key,
  });

  final bool setTime;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final ValueChanged<bool> onSetTimeChanged;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<TimeOfDay> onEndTimeChanged;
  final String Function(TimeOfDay) formatTimeOfDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('calendar-manual-set-time'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.calendarManualSetTime),
          value: setTime,
          onChanged: onSetTimeChanged,
        ),
        if (setTime)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('calendar-manual-start-time'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          startTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (picked != null) onStartTimeChanged(picked);
                  },
                  child: Text(
                    '${l10n.calendarManualStartTime}: '
                    '${startTime == null ? '—' : formatTimeOfDay(startTime!)}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('calendar-manual-end-time'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          endTime ?? const TimeOfDay(hour: 10, minute: 0),
                    );
                    if (picked != null) onEndTimeChanged(picked);
                  },
                  child: Text(
                    '${l10n.calendarManualEndTime}: '
                    '${endTime == null ? '—' : formatTimeOfDay(endTime!)}',
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
