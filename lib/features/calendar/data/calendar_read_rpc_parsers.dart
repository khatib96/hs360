import '../domain/calendar_enums.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_meeting_mode.dart';
import '../domain/calendar_operational_metadata.dart';
import 'calendar_execution_summary_rpc_parsers.dart';
import 'calendar_m7a_read_parsers.dart';
import 'calendar_read_rpc_primitives.dart';
import 'calendar_working_day_rpc_parsers.dart';

export 'calendar_execution_summary_rpc_parsers.dart';
export 'calendar_m7a_read_parsers.dart';
export 'calendar_read_rpc_primitives.dart';
export 'calendar_working_day_rpc_parsers.dart';

CalendarFilters mapCalendarFiltersApplied(dynamic raw) {
  final map = requireMap(raw, 'filters_applied');

  List<CalendarEventType>? eventTypes;
  if (map.containsKey('event_types') && map['event_types'] != null) {
    final list = requireList(map['event_types'], 'filters_applied.event_types');
    eventTypes = list
        .map(
          (item) => requireEnum(
            item,
            CalendarEventType.fromRpc,
            'filters_applied.event_types',
          ),
        )
        .toList();
  }

  List<CalendarEventStatus>? statuses;
  if (map.containsKey('statuses') && map['statuses'] != null) {
    final list = requireList(map['statuses'], 'filters_applied.statuses');
    statuses = list
        .map(
          (item) => requireEnum(
            item,
            CalendarEventStatus.fromRpc,
            'filters_applied.statuses',
          ),
        )
        .toList();
  }

  return CalendarFilters(
    eventTypes: eventTypes,
    statuses: statuses,
    assignedAgentId: optionalString(map['assigned_agent_id']),
    unassignedOnly: map.containsKey('unassigned_only')
        ? requireBool(map['unassigned_only'], 'filters_applied.unassigned_only')
        : false,
    customerId: optionalString(map['customer_id']),
    contractId: optionalString(map['contract_id']),
    serviceLocationId: optionalString(map['service_location_id']),
    sourceKind: optionalEnum(
      map['source_kind'],
      CalendarEventSourceKind.fromRpc,
      'filters_applied.source_kind',
    ),
    workingDayConflict: map.containsKey('working_day_conflict')
        ? requireBool(
            map['working_day_conflict'],
            'filters_applied.working_day_conflict',
          )
        : false,
    overdueOnly: map.containsKey('overdue_only')
        ? requireBool(map['overdue_only'], 'filters_applied.overdue_only')
        : false,
    search: optionalString(map['search']),
  );
}

CalendarOperationalMetadata? mapOperationalMetadata(dynamic value) {
  if (value == null) return null;
  final map = requireMap(value, 'operational_metadata');
  return CalendarOperationalMetadata(
    actionKind: optionalString(map['action_kind']),
    coverageMonthKey: optionalString(map['coverage_month_key']),
  );
}

CalendarEvent mapCalendarEvent(Map<String, dynamic> raw) {
  if (!raw.containsKey('execution_summary')) {
    return malformedCalendarResponse('event.execution_summary key required');
  }
  if (!raw.containsKey('time_window')) {
    return malformedCalendarResponse('event.time_window key required');
  }
  if (!raw.containsKey('participants')) {
    return malformedCalendarResponse('event.participants key required');
  }
  if (!raw.containsKey('schedule_version')) {
    return malformedCalendarResponse('event.schedule_version key required');
  }

  final workingDayRaw = requireMap(raw['working_day'], 'event.working_day');
  final actionsRaw = requireMap(
    raw['available_actions'],
    'event.available_actions',
  );

  return CalendarEvent(
    id: requireString(raw['id'], 'event.id'),
    type: requireEnum(raw['type'], CalendarEventType.fromRpc, 'event.type'),
    status: requireEnum(
      raw['status'],
      CalendarEventStatus.fromRpc,
      'event.status',
    ),
    sourceKind: requireEnum(
      raw['source_kind'],
      CalendarEventSourceKind.fromRpc,
      'event.source_kind',
    ),
    scheduledDate: parseRequiredCalendarDate(raw['scheduled_date']),
    originalDueDate: parseRequiredCalendarDate(raw['original_due_date']),
    titleAr: requireString(raw['title_ar'], 'event.title_ar'),
    titleEn: optionalString(raw['title_en']),
    notes: optionalString(raw['notes']),
    isRescheduled: requireBool(raw['is_rescheduled'], 'event.is_rescheduled'),
    assignedAgentId: optionalString(raw['assigned_agent_id']),
    assignedAgentNameAr: optionalString(raw['assigned_agent_name_ar']),
    assignedAgentNameEn: optionalString(raw['assigned_agent_name_en']),
    customerId: optionalString(raw['customer_id']),
    customerNameAr: optionalString(raw['customer_name_ar']),
    customerNameEn: optionalString(raw['customer_name_en']),
    serviceLocationId: optionalString(raw['service_location_id']),
    serviceLocationName: optionalString(raw['service_location_name']),
    locationGovernorate: optionalString(raw['location_governorate']),
    locationArea: optionalString(raw['location_area']),
    contractId: optionalString(raw['contract_id']),
    contractNumber: optionalString(raw['contract_number']),
    contractLineId: optionalString(raw['contract_line_id']),
    productNameAr: optionalString(raw['product_name_ar']),
    productNameEn: optionalString(raw['product_name_en']),
    qtyPerRefill: optionalDecimal(
      raw['qty_per_refill'],
      'event.qty_per_refill',
    ),
    qtyUnit: optionalString(raw['qty_unit']),
    operationalMetadata: mapOperationalMetadata(raw['operational_metadata']),
    directionsAvailable: requireBool(
      raw['directions_available'],
      'event.directions_available',
    ),
    scheduleState: requireEnum(
      raw['schedule_state'],
      CalendarScheduleState.fromRpc,
      'event.schedule_state',
    ),
    workingDay: mapCalendarWorkingDay(workingDayRaw),
    isOverdue: requireBool(raw['is_overdue'], 'event.is_overdue'),
    overdueDays: requireInt(raw['overdue_days'], 'event.overdue_days'),
    overdueState: requireEnum(
      raw['overdue_state'],
      CalendarOverdueState.fromRpc,
      'event.overdue_state',
    ),
    availableActions: mapCalendarAvailableActions(actionsRaw),
    executionSummary: mapExecutionSummary(raw['execution_summary']),
    scheduleVersion: requireInt(
      raw['schedule_version'],
      'event.schedule_version',
    ),
    timeWindow: mapCalendarTimeWindow(raw['time_window'], 'event.time_window'),
    participants: mapCalendarParticipants(
      raw['participants'],
      'event.participants',
    ),
    meetingMode: optionalEnum(
      raw['meeting_mode'],
      CalendarMeetingMode.fromRpc,
      'event.meeting_mode',
    ),
    meetingUrl: optionalString(raw['meeting_url']),
    freeTextTeam: optionalString(raw['free_text_team']),
    freeTextLocation: optionalString(raw['free_text_location']),
    cancellationReason: optionalString(raw['cancellation_reason']),
  );
}
