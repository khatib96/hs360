import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_manual_mutation.dart';

/// Asks the user to explicitly acknowledge soft schedule/overlap conflicts.
Future<CalendarManualAcknowledgements?> showCalendarConflictConfirmDialog({
  required BuildContext context,
  required CalendarManualConflictInfo conflicts,
  CalendarManualAcknowledgements initial =
      const CalendarManualAcknowledgements(),
}) {
  return showDialog<CalendarManualAcknowledgements>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _ConflictConfirmBody(conflicts: conflicts, initial: initial);
    },
  );
}

class _ConflictConfirmBody extends StatefulWidget {
  const _ConflictConfirmBody({required this.conflicts, required this.initial});

  final CalendarManualConflictInfo conflicts;
  final CalendarManualAcknowledgements initial;

  @override
  State<_ConflictConfirmBody> createState() => _ConflictConfirmBodyState();
}

class _ConflictConfirmBodyState extends State<_ConflictConfirmBody> {
  late CalendarManualAcknowledgements _acks;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _acks = widget.initial;
    _reasonController.text = widget.initial.dayOffOverrideReason ?? '';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _needsNonWorkingAck => widget.conflicts.scheduleWarnings.any(
    (w) => w['code'] == 'non_working_day',
  );

  bool get _needsUnconfiguredAck => widget.conflicts.scheduleWarnings.any(
    (w) => w['code'] == 'schedule_unconfigured',
  );

  bool get _needsOutsideWindowAck => widget.conflicts.scheduleWarnings.any(
    (w) => w['code'] == 'outside_working_window',
  );

  bool get _needsOverlapAck => widget.conflicts.overlapTotalCount > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('calendar-conflict-confirm-dialog'),
      title: Text(l10n.calendarConflictConfirmTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.calendarConflictConfirmBody),
              if (_needsOverlapAck) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const Key('calendar-ack-overlap'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.calendarConflictAckOverlap(
                      widget.conflicts.overlapTotalCount,
                    ),
                  ),
                  value: _acks.acknowledgeOverlap,
                  onChanged: (v) => setState(() {
                    _acks = _acks.copyWith(acknowledgeOverlap: v ?? false);
                  }),
                ),
              ],
              if (_needsNonWorkingAck) ...[
                CheckboxListTile(
                  key: const Key('calendar-ack-non-working'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.calendarConflictAckNonWorkingDay),
                  value: _acks.acknowledgeNonWorkingDay,
                  onChanged: (v) => setState(() {
                    _acks = _acks.copyWith(
                      acknowledgeNonWorkingDay: v ?? false,
                    );
                  }),
                ),
                TextField(
                  key: const Key('calendar-day-off-override-reason'),
                  controller: _reasonController,
                  decoration: InputDecoration(
                    labelText: l10n.calendarConflictDayOffReason,
                  ),
                  maxLines: 2,
                  onChanged: (v) => setState(() {
                    _acks = _acks.copyWith(dayOffOverrideReason: v);
                  }),
                ),
              ],
              if (_needsUnconfiguredAck)
                CheckboxListTile(
                  key: const Key('calendar-ack-unconfigured'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.calendarConflictAckUnconfigured),
                  value: _acks.acknowledgeScheduleUnconfigured,
                  onChanged: (v) => setState(() {
                    _acks = _acks.copyWith(
                      acknowledgeScheduleUnconfigured: v ?? false,
                    );
                  }),
                ),
              if (_needsOutsideWindowAck)
                CheckboxListTile(
                  key: const Key('calendar-ack-outside-window'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.calendarConflictAckOutsideWindow),
                  value: _acks.acknowledgeOutsideWorkingWindow,
                  onChanged: (v) => setState(() {
                    _acks = _acks.copyWith(
                      acknowledgeOutsideWorkingWindow: v ?? false,
                    );
                  }),
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
          key: const Key('calendar-conflict-confirm-submit'),
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(_acks)
              : null,
          child: Text(l10n.calendarConflictConfirmContinue),
        ),
      ],
    );
  }

  bool get _canConfirm {
    if (_needsOverlapAck && !_acks.acknowledgeOverlap) return false;
    if (_needsNonWorkingAck && !_acks.acknowledgeNonWorkingDay) return false;
    if (_needsNonWorkingAck &&
        (_acks.dayOffOverrideReason?.trim().isEmpty ?? true)) {
      return false;
    }
    if (_needsUnconfiguredAck && !_acks.acknowledgeScheduleUnconfigured) {
      return false;
    }
    if (_needsOutsideWindowAck && !_acks.acknowledgeOutsideWorkingWindow) {
      return false;
    }
    return true;
  }
}
