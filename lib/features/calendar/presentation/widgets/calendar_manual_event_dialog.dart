import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../../customers/domain/customer_permissions.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_manual_mutation.dart';
import '../calendar_labels.dart';
import 'calendar_manual_event_form.dart';
import 'calendar_manual_event_form_controller.dart';

/// Result returned when the user saves a create/edit form (before RPC).
class CalendarManualEventFormResult {
  const CalendarManualEventFormResult(this.data);

  final CalendarManualEventData data;
}

Future<CalendarManualEventFormResult?> showCalendarManualEventDialog({
  required BuildContext context,
  required DateTime scheduledDate,
  CalendarEvent? existing,
  CalendarManualAcknowledgements acknowledgements =
      const CalendarManualAcknowledgements(),
}) {
  return showDialog<CalendarManualEventFormResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CalendarManualEventDialog(
      scheduledDate: scheduledDate,
      existing: existing,
      acknowledgements: acknowledgements,
    ),
  );
}

class CalendarManualEventDialog extends ConsumerStatefulWidget {
  const CalendarManualEventDialog({
    required this.scheduledDate,
    this.existing,
    this.acknowledgements = const CalendarManualAcknowledgements(),
    super.key,
  });

  final DateTime scheduledDate;
  final CalendarEvent? existing;
  final CalendarManualAcknowledgements acknowledgements;

  @override
  ConsumerState<CalendarManualEventDialog> createState() =>
      _CalendarManualEventDialogState();
}

class _CalendarManualEventDialogState
    extends ConsumerState<CalendarManualEventDialog> {
  late final CalendarManualEventFormController _form;

  @override
  void initState() {
    super.initState();
    _form = CalendarManualEventFormController(
      scheduledDate: widget.scheduledDate,
      existing: widget.existing,
      acknowledgements: widget.acknowledgements,
    )..init();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _form.loadParticipants(ref);
      if (_form.customerId != null) {
        await _form.loadLocationsAndContracts(ref, _form.customerId!);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _runLookup(Future<void> Function() action) async {
    setState(() {});
    await action();
    if (mounted) setState(() {});
  }

  void _submit() {
    if (_form.submitting) return;
    final data = _form.buildData();
    if (data == null) {
      setState(() {});
      return;
    }
    setState(() {
      _form.submitting = true;
      _form.errorCode = null;
    });
    Navigator.of(context).pop(CalendarManualEventFormResult(data));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canPickCustomer =
        session != null &&
        canViewCustomers(session) &&
        _form.type.allowsCustomerLinks;
    final canPickContract =
        session != null &&
        canViewContracts(session) &&
        _form.type.allowsCustomerLinks;

    final scheduledLabel = l10n.calendarEventScheduledDate(
      calendarLocalizedDate(l10n, widget.scheduledDate),
    );

    return AlertDialog(
      key: Key(
        _form.isEdit
            ? 'calendar-edit-event-dialog'
            : 'calendar-create-event-dialog',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _form.isEdit
                ? l10n.calendarEditEventTitle
                : l10n.calendarCreateEventTitle,
          ),
          const SizedBox(height: 6),
          Text(
            scheduledLabel,
            key: const Key('calendar-manual-scheduled-date'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          // Top padding keeps the first floating label fully visible.
          padding: const EdgeInsets.only(top: 12),
          child: CalendarManualEventFormBody(
            errorCode: _form.errorCode,
            type: _form.type,
            isEdit: _form.isEdit,
            titleAr: _form.titleAr,
            titleEn: _form.titleEn,
            notes: _form.notes,
            onTypeChanged: (t) => setState(() => _form.onTypeChanged(t)),
            setTime: _form.setTime,
            startTime: _form.startTime,
            endTime: _form.endTime,
            onSetTimeChanged: (v) => setState(() => _form.onSetTimeChanged(v)),
            onStartTimeChanged: (t) => setState(() => _form.startTime = t),
            onEndTimeChanged: (t) => setState(() => _form.endTime = t),
            formatTimeOfDay: CalendarManualEventFormController.formatTimeOfDay,
            meetingMode: _form.meetingMode,
            meetingUrl: _form.meetingUrl,
            locationText: _form.locationText,
            team: _form.team,
            onMeetingModeChanged: (m) =>
                setState(() => _form.onMeetingModeChanged(m)),
            canPickCustomer: canPickCustomer,
            canPickContract: canPickContract,
            customerId: _form.customerId,
            customerLabel: _form.customerLabel,
            customerSearch: _form.customerSearch,
            customerResults: _form.customerResults,
            locations: _form.locations,
            contracts: _form.contracts,
            serviceLocationId: _form.serviceLocationId,
            contractId: _form.contractId,
            loadingLookups: _form.loadingLookups,
            locale: locale,
            onClearCustomer: () => setState(_form.clearCustomer),
            onSearchCustomers: (q) =>
                _runLookup(() => _form.searchCustomers(ref, q)),
            onSelectCustomer: (c) {
              setState(() => _form.selectCustomer(c, locale));
              _runLookup(() => _form.loadLocationsAndContracts(ref, c.id));
            },
            onServiceLocationChanged: (v) =>
                setState(() => _form.serviceLocationId = v),
            onContractChanged: (v) => setState(() => _form.contractId = v),
            participantSearch: _form.participantSearch,
            selectedParticipants: _form.selectedParticipants,
            participantCandidates: _form.participantCandidates,
            onParticipantSearch: (q) =>
                _runLookup(() => _form.loadParticipants(ref, search: q)),
            onToggleParticipant: (p, selected) =>
                setState(() => _form.toggleParticipant(p, selected)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _form.submitting
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(l10n.financeActionCancel),
        ),
        FilledButton(
          key: const Key('calendar-manual-event-submit'),
          onPressed: _form.submitting ? null : _submit,
          child: Text(
            _form.isEdit
                ? l10n.calendarSaveEvent
                : l10n.calendarCreateEventConfirm,
          ),
        ),
      ],
    );
  }
}
