import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_date.dart';
import '../../domain/calendar_working_date_exception.dart';
import '../calendar_labels.dart';
import '../calendar_working_date_exceptions_controller.dart';
import 'calendar_working_date_exception_form_body.dart';
import 'calendar_working_date_exception_form_controller.dart';

/// Shows the create/edit dialog and performs the mutation itself (so a hard
/// failure like an overlap can redisplay inline without losing form state).
/// Returns true when the mutation succeeded.
Future<bool> showCalendarWorkingDateExceptionDialog({
  required BuildContext context,
  WorkingDateException? existing,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CalendarWorkingDateExceptionDialog(existing: existing),
  );
  return result ?? false;
}

class CalendarWorkingDateExceptionDialog extends ConsumerStatefulWidget {
  const CalendarWorkingDateExceptionDialog({this.existing, super.key});

  final WorkingDateException? existing;

  @override
  ConsumerState<CalendarWorkingDateExceptionDialog> createState() =>
      _CalendarWorkingDateExceptionDialogState();
}

class _CalendarWorkingDateExceptionDialogState
    extends ConsumerState<CalendarWorkingDateExceptionDialog> {
  late final CalendarWorkingDateExceptionFormController _form;
  String? _mutationErrorCode;

  @override
  void initState() {
    super.initState();
    _form = CalendarWorkingDateExceptionFormController(
      existing: widget.existing,
    )..init();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial =
        (isStart ? _form.startDate : _form.endDate) ?? calendarDateOnly(now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _form.startDate = calendarDateOnly(picked);
        if (_form.endDate != null && _form.endDate!.isBefore(picked)) {
          _form.endDate = calendarDateOnly(picked);
        }
      } else {
        _form.endDate = calendarDateOnly(picked);
      }
    });
  }

  Future<void> _submit() async {
    if (_form.submitting) return;
    final data = _form.buildData();
    if (data == null) {
      setState(() {});
      return;
    }

    setState(() {
      _form.submitting = true;
      _form.errorCode = null;
      _mutationErrorCode = null;
    });

    final notifier = ref.read(
      calendarWorkingDateExceptionsControllerProvider.notifier,
    );
    final existing = widget.existing;
    final ok = existing == null
        ? await notifier.createException(data)
        : await notifier.updateException(existing, data);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _form.submitting = false;
      _mutationErrorCode = ref
          .read(calendarWorkingDateExceptionsControllerProvider)
          .mutationErrorCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      key: Key(
        _form.isEdit
            ? 'calendar-wde-edit-dialog'
            : 'calendar-wde-create-dialog',
      ),
      title: Text(
        _form.isEdit
            ? l10n.calendarWorkingDateExceptionEditTitle
            : l10n.calendarWorkingDateExceptionCreateTitle,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_form.errorCode != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    calendarWorkingDateExceptionValidationMessage(
                      l10n,
                      _form.errorCode!,
                    ),
                    key: const Key('calendar-wde-form-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_mutationErrorCode != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    calendarErrorMessage(l10n, _mutationErrorCode!),
                    key: const Key('calendar-wde-mutation-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              CalendarWorkingDateExceptionFormBody(
                kind: _form.kind,
                startDate: _form.startDate,
                endDate: _form.endDate,
                titleAr: _form.titleAr,
                titleEn: _form.titleEn,
                notes: _form.notes,
                dayMode: _form.dayMode,
                workStart: _form.workStart,
                workEnd: _form.workEnd,
                onKindChanged: (k) => setState(() => _form.onKindChanged(k)),
                onPickStartDate: () => _pickDate(isStart: true),
                onPickEndDate: () => _pickDate(isStart: false),
                onDayModeChanged: (m) =>
                    setState(() => _form.onDayModeChanged(m)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _form.submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l10n.financeActionCancel),
        ),
        FilledButton(
          key: const Key('calendar-wde-submit'),
          onPressed: _form.submitting ? null : _submit,
          child: _form.submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _form.isEdit
                      ? l10n.calendarWorkingDateExceptionSaveConfirm
                      : l10n.calendarWorkingDateExceptionCreateConfirm,
                ),
        ),
      ],
    );
  }
}
