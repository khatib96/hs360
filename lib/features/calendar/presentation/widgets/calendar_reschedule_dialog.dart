import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_date.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_mutation_validators.dart';
import '../calendar_labels.dart';

/// Validated reschedule request from the dialog (date + mandatory reason).
class CalendarRescheduleInput {
  const CalendarRescheduleInput({
    required this.targetDate,
    required this.reason,
  });

  final DateTime targetDate;
  final String reason;
}

/// Picks a new scheduled date with a mandatory audited reason. Returns null
/// when dismissed; submitting is disabled while the date is unchanged or the
/// reason is invalid. Soft-conflict confirmation happens after submit via the
/// shared conflict dialog.
Future<CalendarRescheduleInput?> showCalendarRescheduleDialog({
  required BuildContext context,
  required CalendarEvent event,
}) {
  return showDialog<CalendarRescheduleInput>(
    context: context,
    builder: (_) => _RescheduleDialogBody(event: event),
  );
}

class _RescheduleDialogBody extends StatefulWidget {
  const _RescheduleDialogBody({required this.event});

  final CalendarEvent event;

  @override
  State<_RescheduleDialogBody> createState() => _RescheduleDialogBodyState();
}

class _RescheduleDialogBodyState extends State<_RescheduleDialogBody> {
  final _reasonController = TextEditingController();
  late DateTime _targetDate;

  @override
  void initState() {
    super.initState();
    _targetDate = calendarDateOnly(widget.event.scheduledDate);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _isDateUnchanged =>
      _targetDate == calendarDateOnly(widget.event.scheduledDate);

  bool get _isReasonValid =>
      CalendarMutationValidators.validateRescheduleReason(
        _reasonController.text,
      ).isValid;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(_targetDate.year - 2),
      lastDate: DateTime(_targetDate.year + 3, 12, 31),
    );
    if (picked == null) return;
    setState(() => _targetDate = calendarDateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final event = widget.event;
    final timeWindow = event.timeWindow;
    final canSubmit = !_isDateUnchanged && _isReasonValid;

    return AlertDialog(
      key: const Key('calendar-reschedule-dialog'),
      title: Text(l10n.calendarRescheduleDialogTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.calendarRescheduleCurrentDate(
                  calendarLocalizedDate(l10n, event.scheduledDate),
                ),
                key: const Key('calendar-reschedule-current-date'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (timeWindow != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.calendarRescheduleTimedWindow(
                    timeWindow.startLocal,
                    timeWindow.endLocal,
                  ),
                  key: const Key('calendar-reschedule-time-window'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('calendar-reschedule-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  l10n.calendarRescheduleTargetDate(
                    calendarLocalizedDate(l10n, _targetDate),
                  ),
                ),
              ),
              if (_isDateUnchanged)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.calendarRescheduleDateUnchanged,
                    key: const Key('calendar-reschedule-unchanged'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('calendar-reschedule-reason'),
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: l10n.calendarRescheduleReasonLabel,
                  helperText: l10n.calendarRescheduleReasonRequired,
                ),
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.financeActionCancel),
        ),
        FilledButton(
          key: const Key('calendar-reschedule-submit'),
          onPressed: canSubmit
              ? () => Navigator.of(context).pop(
                  CalendarRescheduleInput(
                    targetDate: _targetDate,
                    reason: _reasonController.text.trim(),
                  ),
                )
              : null,
          child: Text(l10n.calendarRescheduleSubmit),
        ),
      ],
    );
  }
}
