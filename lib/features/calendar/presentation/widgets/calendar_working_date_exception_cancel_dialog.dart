import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_working_date_exception.dart';
import '../../domain/calendar_working_date_exception_validators.dart';
import '../calendar_labels.dart';
import '../calendar_working_date_exceptions_controller.dart';

/// Collects a mandatory cancellation reason and cancels [exception] directly
/// against the controller. Returns true when the cancellation succeeded.
Future<bool> showCalendarWorkingDateExceptionCancelDialog({
  required BuildContext context,
  required WorkingDateException exception,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _CancelDialogBody(exception: exception),
  );
  return result ?? false;
}

class _CancelDialogBody extends ConsumerStatefulWidget {
  const _CancelDialogBody({required this.exception});

  final WorkingDateException exception;

  @override
  ConsumerState<_CancelDialogBody> createState() => _CancelDialogBodyState();
}

class _CancelDialogBodyState extends ConsumerState<_CancelDialogBody> {
  final _controller = TextEditingController();
  String? _fieldErrorCode;
  String? _mutationErrorCode;
  var _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final validation = CalendarWorkingDateExceptionValidators
        .validateCancelReason(_controller.text);
    if (!validation.isValid) {
      setState(() => _fieldErrorCode = validation.codes.first);
      return;
    }

    setState(() {
      _submitting = true;
      _fieldErrorCode = null;
      _mutationErrorCode = null;
    });

    final ok = await ref
        .read(calendarWorkingDateExceptionsControllerProvider.notifier)
        .cancelException(widget.exception, reason: _controller.text.trim());

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _mutationErrorCode = ref
          .read(calendarWorkingDateExceptionsControllerProvider)
          .mutationErrorCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('calendar-wde-cancel-dialog'),
      title: Text(l10n.calendarWorkingDateExceptionCancelTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.calendarWorkingDateExceptionCancelBody),
            const SizedBox(height: 12),
            TextField(
              key: const Key('calendar-wde-cancel-reason-field'),
              controller: _controller,
              enabled: !_submitting,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.calendarCancelReasonLabel,
                errorText: _fieldErrorCode == null
                    ? null
                    : l10n.calendarCancelReasonRequired,
              ),
              onChanged: (_) {
                if (_fieldErrorCode != null) {
                  setState(() => _fieldErrorCode = null);
                }
              },
            ),
            if (_mutationErrorCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  calendarErrorMessage(l10n, _mutationErrorCode!),
                  key: const Key('calendar-wde-cancel-mutation-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.financeActionCancel),
        ),
        FilledButton(
          key: const Key('calendar-wde-cancel-submit'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _submitting ? null : _submit,
          child: Text(l10n.calendarWorkingDateExceptionCancelConfirm),
        ),
      ],
    );
  }
}
