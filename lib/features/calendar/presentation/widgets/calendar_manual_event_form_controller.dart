import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../customers/data/customer_service_location_repository.dart';
import '../../../customers/domain/customer.dart';
import '../../../customers/domain/customer_filters.dart';
import '../../../customers/domain/customer_permissions.dart';
import '../../../customers/domain/customer_service_location.dart';
import '../../../contracts/data/contract_repository.dart';
import '../../../contracts/domain/contract_filters.dart';
import '../../../contracts/domain/contract_summary.dart';
import '../../data/calendar_repository.dart';
import '../../domain/calendar_enums.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_event_participant.dart';
import '../../domain/calendar_manual_mutation.dart';
import '../../domain/calendar_meeting_mode.dart';
import '../../domain/calendar_mutation_validators.dart';

/// Owns create/edit form field state, lookups, and client-side validation.
class CalendarManualEventFormController {
  CalendarManualEventFormController({
    required this.scheduledDate,
    required this.acknowledgements,
    this.existing,
  });

  final DateTime scheduledDate;
  final CalendarEvent? existing;
  final CalendarManualAcknowledgements acknowledgements;

  late CalendarEventType type;
  late final TextEditingController titleAr;
  late final TextEditingController titleEn;
  late final TextEditingController notes;
  late final TextEditingController team;
  late final TextEditingController locationText;
  late final TextEditingController meetingUrl;
  late final TextEditingController customerSearch;
  late final TextEditingController participantSearch;

  var setTime = false;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  CalendarMeetingMode? meetingMode;
  String? customerId;
  String? customerLabel;
  String? serviceLocationId;
  String? contractId;
  final selectedParticipants = <String, CalendarEventParticipant>{};
  var participantCandidates = <CalendarParticipantCandidate>[];
  var customerResults = <Customer>[];
  var locations = <CustomerServiceLocation>[];
  var contracts = <ContractSummary>[];
  var loadingLookups = false;
  String? errorCode;
  var submitting = false;

  bool get isEdit => existing != null;

  void init() {
    final existing = this.existing;
    type = existing?.type ?? CalendarEventType.internalTask;
    titleAr = TextEditingController(text: existing?.titleAr ?? '');
    titleEn = TextEditingController(text: existing?.titleEn ?? '');
    notes = TextEditingController(text: existing?.notes ?? '');
    team = TextEditingController(text: existing?.freeTextTeam ?? '');
    locationText = TextEditingController(
      text: existing?.freeTextLocation ?? '',
    );
    meetingUrl = TextEditingController(text: existing?.meetingUrl ?? '');
    customerSearch = TextEditingController();
    participantSearch = TextEditingController();
    meetingMode = existing?.meetingMode;
    customerId = existing?.customerId;
    customerLabel = existing?.customerNameEn ?? existing?.customerNameAr;
    serviceLocationId = existing?.serviceLocationId;
    contractId = existing?.contractId;
    final tw = existing?.timeWindow;
    if (tw != null) {
      setTime = true;
      startTime = parseTimeOfDay(tw.startLocal);
      endTime = parseTimeOfDay(tw.endLocal);
    }
    for (final p
        in existing?.participants ?? const <CalendarEventParticipant>[]) {
      selectedParticipants[p.employeeId] = p;
    }
  }

  void dispose() {
    titleAr.dispose();
    titleEn.dispose();
    notes.dispose();
    team.dispose();
    locationText.dispose();
    meetingUrl.dispose();
    customerSearch.dispose();
    participantSearch.dispose();
  }

  static TimeOfDay? parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> loadParticipants(WidgetRef ref, {String? search}) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    try {
      participantCandidates = await ref
          .read(calendarRepositoryProvider)
          .listParticipantCandidates(session, search: search, limit: 50);
    } catch (_) {
      // Soft-fail lookup; form can still submit with already selected IDs.
    }
  }

  Future<void> searchCustomers(WidgetRef ref, String query) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewCustomers(session)) return;
    loadingLookups = true;
    try {
      customerResults = await ref
          .read(customerRepositoryProvider)
          .fetchCustomers(
            session,
            CustomerFilters(search: query.trim().isEmpty ? null : query),
            limit: 20,
          );
    } catch (_) {
      // Soft-fail customer search.
    } finally {
      loadingLookups = false;
    }
  }

  Future<void> loadLocationsAndContracts(
    WidgetRef ref,
    String selectedCustomerId,
  ) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    loadingLookups = true;
    try {
      List<CustomerServiceLocation> nextLocations = const [];
      List<ContractSummary> nextContracts = const [];
      if (canViewCustomers(session)) {
        nextLocations = await ref
            .read(customerServiceLocationRepositoryProvider)
            .listLocations(session, selectedCustomerId);
      }
      if (canViewContracts(session)) {
        nextContracts = await ref
            .read(contractRepositoryProvider)
            .listContracts(
              session,
              filters: ContractFilters(customerId: selectedCustomerId),
            );
      }
      locations = nextLocations;
      contracts = nextContracts;
    } catch (_) {
      // Soft-fail linked lookups.
    } finally {
      loadingLookups = false;
    }
  }

  void onTypeChanged(CalendarEventType? next) {
    if (next == null) return;
    type = next;
    if (next.isInternalCategory) {
      customerId = null;
      customerLabel = null;
      serviceLocationId = null;
      contractId = null;
      customerResults = const [];
      locations = const [];
      contracts = const [];
    }
    if (next != CalendarEventType.internalMeeting) {
      meetingMode = null;
      meetingUrl.clear();
    } else {
      meetingMode ??= CalendarMeetingMode.inPerson;
    }
  }

  void onMeetingModeChanged(CalendarMeetingMode? mode) {
    meetingMode = mode;
    if (mode == CalendarMeetingMode.online) {
      locationText.clear();
    } else if (mode == CalendarMeetingMode.inPerson) {
      meetingUrl.clear();
    }
  }

  void onSetTimeChanged(bool enabled) {
    setTime = enabled;
    if (!enabled) {
      startTime = null;
      endTime = null;
    } else {
      startTime ??= const TimeOfDay(hour: 9, minute: 0);
      endTime ??= const TimeOfDay(hour: 10, minute: 0);
    }
  }

  void clearCustomer() {
    customerId = null;
    customerLabel = null;
    serviceLocationId = null;
    contractId = null;
    locations = const [];
    contracts = const [];
  }

  void selectCustomer(Customer customer, String locale) {
    customerId = customer.id;
    customerLabel = locale == 'ar'
        ? customer.nameAr
        : (customer.nameEn ?? customer.nameAr);
    serviceLocationId = null;
    contractId = null;
    customerResults = const [];
    customerSearch.clear();
  }

  void toggleParticipant(CalendarEventParticipant participant, bool selected) {
    if (selected) {
      selectedParticipants[participant.employeeId] = participant;
    } else {
      selectedParticipants.remove(participant.employeeId);
    }
  }

  /// Returns validated data, or null after setting [errorCode].
  CalendarManualEventData? buildData() {
    final timeWindow = setTime && startTime != null && endTime != null
        ? CalendarManualTimeWindowInput(
            startLocal: formatTimeOfDay(startTime!),
            endLocal: formatTimeOfDay(endTime!),
          )
        : null;

    final validation = CalendarMutationValidators.validateManualEventForm(
      type: type,
      titleAr: titleAr.text,
      titleEn: titleEn.text,
      notes: notes.text,
      setTimeEnabled: setTime,
      timeWindow: timeWindow,
      customerId: customerId,
      serviceLocationId: serviceLocationId,
      contractId: contractId,
      freeTextTeam: team.text,
      freeTextLocation: locationText.text,
      meetingMode: meetingMode,
      meetingUrl: meetingUrl.text,
      participantEmployeeIds: selectedParticipants.keys.toList(),
    );
    if (!validation.isValid) {
      errorCode = validation.codes.first;
      return null;
    }

    return CalendarManualEventData(
      type: type,
      scheduledDate: existing?.scheduledDate ?? scheduledDate,
      titleAr: titleAr.text.trim(),
      titleEn: titleEn.text.trim().isEmpty ? null : titleEn.text.trim(),
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      timeWindow: timeWindow,
      customerId: customerId,
      serviceLocationId: serviceLocationId,
      contractId: contractId,
      freeTextTeam: team.text.trim().isEmpty ? null : team.text.trim(),
      freeTextLocation: locationText.text.trim().isEmpty
          ? null
          : locationText.text.trim(),
      participantEmployeeIds: selectedParticipants.keys.toList(),
      meetingMode: meetingMode,
      meetingUrl: meetingUrl.text.trim().isEmpty
          ? null
          : meetingUrl.text.trim(),
      acknowledgements: acknowledgements,
    );
  }
}
