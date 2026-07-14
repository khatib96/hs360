import 'calendar_enums.dart';

/// Immutable calendar read filters matching the M4 filter bundle.
class CalendarFilters {
  const CalendarFilters._({
    this.eventTypes,
    this.statuses,
    this.assignedAgentId,
    this.unassignedOnly = false,
    this.customerId,
    this.contractId,
    this.serviceLocationId,
    this.sourceKind,
    this.workingDayConflict = false,
    this.overdueOnly = false,
    this.search,
  });

  /// Empty / default filters (const).
  static const empty = CalendarFilters._();

  /// Creates filters, freezing any provided enum lists.
  factory CalendarFilters({
    List<CalendarEventType>? eventTypes,
    List<CalendarEventStatus>? statuses,
    String? assignedAgentId,
    bool unassignedOnly = false,
    String? customerId,
    String? contractId,
    String? serviceLocationId,
    CalendarEventSourceKind? sourceKind,
    bool workingDayConflict = false,
    bool overdueOnly = false,
    String? search,
  }) {
    return CalendarFilters._(
      eventTypes: eventTypes == null
          ? null
          : List.unmodifiable(List<CalendarEventType>.from(eventTypes)),
      statuses: statuses == null
          ? null
          : List.unmodifiable(List<CalendarEventStatus>.from(statuses)),
      assignedAgentId: assignedAgentId,
      unassignedOnly: unassignedOnly,
      customerId: customerId,
      contractId: contractId,
      serviceLocationId: serviceLocationId,
      sourceKind: sourceKind,
      workingDayConflict: workingDayConflict,
      overdueOnly: overdueOnly,
      search: search,
    );
  }

  static const int minRangeDays = 1;
  static const int maxRangeDays = 62;
  static const int defaultPageLimit = 50;
  static const int maxPageLimit = 100;

  final List<CalendarEventType>? eventTypes;
  final List<CalendarEventStatus>? statuses;
  final String? assignedAgentId;
  final bool unassignedOnly;
  final String? customerId;
  final String? contractId;
  final String? serviceLocationId;
  final CalendarEventSourceKind? sourceKind;
  final bool workingDayConflict;
  final bool overdueOnly;
  final String? search;

  /// Canonical filter payload for RPC / hash alignment.
  ///
  /// Omits nulls, false booleans, empty enum lists, and empty search.
  Map<String, dynamic> toCanonicalPayload() {
    final payload = <String, dynamic>{};

    final types = eventTypes;
    if (types != null && types.isNotEmpty) {
      payload['event_types'] = List<String>.unmodifiable(
        types.map((e) => e.rpcValue).toList(),
      );
    }

    final statusList = statuses;
    if (statusList != null && statusList.isNotEmpty) {
      payload['statuses'] = List<String>.unmodifiable(
        statusList.map((e) => e.rpcValue).toList(),
      );
    }

    final agentId = assignedAgentId?.trim();
    if (agentId != null && agentId.isNotEmpty) {
      payload['assigned_agent_id'] = agentId;
    }

    if (unassignedOnly) {
      payload['unassigned_only'] = true;
    }

    final customer = customerId?.trim();
    if (customer != null && customer.isNotEmpty) {
      payload['customer_id'] = customer;
    }

    final contract = contractId?.trim();
    if (contract != null && contract.isNotEmpty) {
      payload['contract_id'] = contract;
    }

    final location = serviceLocationId?.trim();
    if (location != null && location.isNotEmpty) {
      payload['service_location_id'] = location;
    }

    if (sourceKind != null) {
      payload['source_kind'] = sourceKind!.rpcValue;
    }

    if (workingDayConflict) {
      payload['working_day_conflict'] = true;
    }

    if (overdueOnly) {
      payload['overdue_only'] = true;
    }

    final trimmedSearch = search?.trim();
    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      payload['search'] = trimmedSearch;
    }

    return Map<String, dynamic>.unmodifiable(payload);
  }

  CalendarFilters copyWith({
    List<CalendarEventType>? eventTypes,
    bool clearEventTypes = false,
    List<CalendarEventStatus>? statuses,
    bool clearStatuses = false,
    String? assignedAgentId,
    bool clearAssignedAgentId = false,
    bool? unassignedOnly,
    String? customerId,
    bool clearCustomerId = false,
    String? contractId,
    bool clearContractId = false,
    String? serviceLocationId,
    bool clearServiceLocationId = false,
    CalendarEventSourceKind? sourceKind,
    bool clearSourceKind = false,
    bool? workingDayConflict,
    bool? overdueOnly,
    String? search,
    bool clearSearch = false,
  }) {
    return CalendarFilters(
      eventTypes: clearEventTypes ? null : (eventTypes ?? this.eventTypes),
      statuses: clearStatuses ? null : (statuses ?? this.statuses),
      assignedAgentId: clearAssignedAgentId
          ? null
          : (assignedAgentId ?? this.assignedAgentId),
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      contractId: clearContractId ? null : (contractId ?? this.contractId),
      serviceLocationId: clearServiceLocationId
          ? null
          : (serviceLocationId ?? this.serviceLocationId),
      sourceKind: clearSourceKind ? null : (sourceKind ?? this.sourceKind),
      workingDayConflict: workingDayConflict ?? this.workingDayConflict,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      search: clearSearch ? null : (search ?? this.search),
    );
  }
}
