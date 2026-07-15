import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_mutation_validators.dart';

/// Collects a mandatory cancellation reason for a manual event.
Future<String?> showCalendarCancelEventDialog({required BuildContext context}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => const _CancelEventDialogBody(),
  );
}

class _CancelEventDialogBody extends StatefulWidget {
  const _CancelEventDialogBody();

  @override
  State<_CancelEventDialogBody> createState() => _CancelEventDialogBodyState();
}

class _CancelEventDialogBodyState extends State<_CancelEventDialogBody> {
  final _controller = TextEditingController();
  String? _error;
  var _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting) return;
    final validation = CalendarMutationValidators.validateCancelReason(
      _controller.text,
    );
    if (!validation.isValid) {
      setState(() => _error = validation.codes.first);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('calendar-cancel-event-dialog'),
      title: Text(l10n.calendarCancelEventTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.calendarCancelEventBody),
            const SizedBox(height: 12),
            TextField(
              key: const Key('calendar-cancel-reason-field'),
              controller: _controller,
              enabled: !_submitting,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.calendarCancelReasonLabel,
                errorText: _error == null
                    ? null
                    : l10n.calendarCancelReasonRequired,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
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
          key: const Key('calendar-cancel-event-submit'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _submitting ? null : _submit,
          child: Text(l10n.calendarCancelEventConfirm),
        ),
      ],
    );
  }
}
