import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../contracts/domain/contract_summary.dart';
import '../../../customers/domain/customer.dart';
import '../../../customers/domain/customer_service_location.dart';
import '../../domain/calendar_enums.dart';
import '../../domain/calendar_event_participant.dart';
import '../../domain/calendar_meeting_mode.dart';
import '../calendar_labels.dart';
import 'calendar_manual_category_fields.dart';
import 'calendar_manual_customer_section.dart';
import 'calendar_manual_meeting_section.dart';
import 'calendar_manual_participant_section.dart';
import 'calendar_manual_time_section.dart';

/// Composes manual-event field sections; state lives in the dialog.
class CalendarManualEventFormBody extends StatelessWidget {
  const CalendarManualEventFormBody({
    required this.errorCode,
    required this.type,
    required this.isEdit,
    required this.titleAr,
    required this.titleEn,
    required this.notes,
    required this.onTypeChanged,
    required this.setTime,
    required this.startTime,
    required this.endTime,
    required this.onSetTimeChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.formatTimeOfDay,
    required this.meetingMode,
    required this.meetingUrl,
    required this.locationText,
    required this.team,
    required this.onMeetingModeChanged,
    required this.canPickCustomer,
    required this.canPickContract,
    required this.customerId,
    required this.customerLabel,
    required this.customerSearch,
    required this.customerResults,
    required this.locations,
    required this.contracts,
    required this.serviceLocationId,
    required this.contractId,
    required this.loadingLookups,
    required this.locale,
    required this.onClearCustomer,
    required this.onSearchCustomers,
    required this.onSelectCustomer,
    required this.onServiceLocationChanged,
    required this.onContractChanged,
    required this.participantSearch,
    required this.selectedParticipants,
    required this.participantCandidates,
    required this.onParticipantSearch,
    required this.onToggleParticipant,
    super.key,
  });

  final String? errorCode;
  final CalendarEventType type;
  final bool isEdit;
  final TextEditingController titleAr;
  final TextEditingController titleEn;
  final TextEditingController notes;
  final ValueChanged<CalendarEventType?> onTypeChanged;
  final bool setTime;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final ValueChanged<bool> onSetTimeChanged;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<TimeOfDay> onEndTimeChanged;
  final String Function(TimeOfDay) formatTimeOfDay;
  final CalendarMeetingMode? meetingMode;
  final TextEditingController meetingUrl;
  final TextEditingController locationText;
  final TextEditingController team;
  final ValueChanged<CalendarMeetingMode?> onMeetingModeChanged;
  final bool canPickCustomer;
  final bool canPickContract;
  final String? customerId;
  final String? customerLabel;
  final TextEditingController customerSearch;
  final List<Customer> customerResults;
  final List<CustomerServiceLocation> locations;
  final List<ContractSummary> contracts;
  final String? serviceLocationId;
  final String? contractId;
  final bool loadingLookups;
  final String locale;
  final VoidCallback onClearCustomer;
  final ValueChanged<String> onSearchCustomers;
  final ValueChanged<Customer> onSelectCustomer;
  final ValueChanged<String?> onServiceLocationChanged;
  final ValueChanged<String?> onContractChanged;
  final TextEditingController participantSearch;
  final Map<String, CalendarEventParticipant> selectedParticipants;
  final List<CalendarParticipantCandidate> participantCandidates;
  final ValueChanged<String> onParticipantSearch;
  final void Function(CalendarEventParticipant participant, bool selected)
  onToggleParticipant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorCode != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              calendarManualValidationMessage(l10n, errorCode!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        CalendarManualCategoryFields(
          type: type,
          isEdit: isEdit,
          titleAr: titleAr,
          titleEn: titleEn,
          notes: notes,
          onTypeChanged: onTypeChanged,
        ),
        CalendarManualTimeSection(
          setTime: setTime,
          startTime: startTime,
          endTime: endTime,
          onSetTimeChanged: onSetTimeChanged,
          onStartTimeChanged: onStartTimeChanged,
          onEndTimeChanged: onEndTimeChanged,
          formatTimeOfDay: formatTimeOfDay,
        ),
        CalendarManualMeetingSection(
          type: type,
          meetingMode: meetingMode,
          meetingUrl: meetingUrl,
          locationText: locationText,
          team: team,
          onMeetingModeChanged: onMeetingModeChanged,
        ),
        if (canPickCustomer)
          CalendarManualCustomerSection(
            customerId: customerId,
            customerLabel: customerLabel,
            customerSearch: customerSearch,
            customerResults: customerResults,
            locations: locations,
            contracts: contracts,
            serviceLocationId: serviceLocationId,
            contractId: contractId,
            loadingLookups: loadingLookups,
            canPickContract: canPickContract,
            locale: locale,
            onClearCustomer: onClearCustomer,
            onSearchCustomers: onSearchCustomers,
            onSelectCustomer: onSelectCustomer,
            onServiceLocationChanged: onServiceLocationChanged,
            onContractChanged: onContractChanged,
          ),
        CalendarManualParticipantSection(
          searchController: participantSearch,
          selectedParticipants: selectedParticipants,
          candidates: participantCandidates,
          locale: locale,
          onSearch: onParticipantSearch,
          onToggleParticipant: onToggleParticipant,
        ),
      ],
    );
  }
}
