/// RPC JSON fixtures mirroring migration 097 response shapes.
library;

Map<String, dynamic> validWorkingDayRpc({
  String tenantId = '11111111-1111-1111-1111-111111111111',
  String date = '2026-07-14',
  int isoWeekday = 2,
  bool scheduleConfigured = true,
  String? timezoneName = 'Asia/Kuwait',
  String? dayMode = 'working_hours',
  String? workStart = '08:00',
  String? workEnd = '17:00',
  bool isUnreviewed = false,
  bool isDayOff = false,
  bool is24Hours = false,
  bool isWorkingHours = true,
}) {
  return {
    'tenant_id': tenantId,
    'date': date,
    'iso_weekday': isoWeekday,
    'schedule_configured': scheduleConfigured,
    'timezone_name': timezoneName,
    'day_mode': dayMode,
    'work_start': workStart,
    'work_end': workEnd,
    'is_unreviewed': isUnreviewed,
    'is_day_off': isDayOff,
    'is_24_hours': is24Hours,
    'is_working_hours': isWorkingHours,
  };
}

/// Unconfigured working day AFTER strip_nulls: day_mode omitted, null flags
/// omitted, is_unreviewed may be true or omitted (mapper treats unreviewed mode).
Map<String, dynamic> unconfiguredWorkingDayRpc({
  String tenantId = '11111111-1111-1111-1111-111111111111',
  String date = '2026-07-14',
  int isoWeekday = 2,
  String? timezoneName = 'Asia/Kuwait',
  bool includeIsUnreviewed = true,
}) {
  final map = <String, dynamic>{
    'tenant_id': tenantId,
    'date': date,
    'iso_weekday': isoWeekday,
    'schedule_configured': false,
    'timezone_name': timezoneName,
  };
  if (includeIsUnreviewed) {
    map['is_unreviewed'] = true;
  }
  return map;
}

Map<String, dynamic> dayOffWorkingDayRpc({
  String tenantId = '11111111-1111-1111-1111-111111111111',
  String date = '2026-07-14',
  int isoWeekday = 2,
  String? timezoneName = 'Asia/Kuwait',
}) {
  return {
    'tenant_id': tenantId,
    'date': date,
    'iso_weekday': isoWeekday,
    'schedule_configured': true,
    'timezone_name': timezoneName,
    'day_mode': 'day_off',
    'is_unreviewed': false,
    'is_day_off': true,
    'is_24_hours': false,
    'is_working_hours': false,
  };
}

Map<String, dynamic> workingHoursWorkingDayRpc({
  String tenantId = '11111111-1111-1111-1111-111111111111',
  String date = '2026-07-14',
  int isoWeekday = 2,
  String? timezoneName = 'Asia/Kuwait',
  String workStart = '08:00',
  String workEnd = '17:00',
}) {
  return {
    'tenant_id': tenantId,
    'date': date,
    'iso_weekday': isoWeekday,
    'schedule_configured': true,
    'timezone_name': timezoneName,
    'day_mode': 'working_hours',
    'work_start': workStart,
    'work_end': workEnd,
    'is_unreviewed': false,
    'is_day_off': false,
    'is_24_hours': false,
    'is_working_hours': true,
  };
}

Map<String, dynamic> hours24WorkingDayRpc({
  String tenantId = '11111111-1111-1111-1111-111111111111',
  String date = '2026-07-14',
  int isoWeekday = 2,
  String? timezoneName = 'Asia/Kuwait',
}) {
  return {
    'tenant_id': tenantId,
    'date': date,
    'iso_weekday': isoWeekday,
    'schedule_configured': true,
    'timezone_name': timezoneName,
    'day_mode': '24_hours',
    'is_unreviewed': false,
    'is_day_off': false,
    'is_24_hours': true,
    'is_working_hours': false,
  };
}

Map<String, dynamic> validAvailableActionsRpc({
  bool canViewCustomer = true,
  bool canViewContract = true,
  bool canAssign = false,
  bool canReschedule = false,
  bool canCreateManual = false,
  bool canOpenDirections = false,
}) {
  return {
    'can_view_customer': canViewCustomer,
    'can_view_contract': canViewContract,
    'can_assign': canAssign,
    'can_reschedule': canReschedule,
    'can_create_manual': canCreateManual,
    'can_open_directions': canOpenDirections,
  };
}

/// Valid execution summary: required 094/097 fields present.
/// Pass exactly one of [coverageMonths] / [coverageDays] (positive).
Map<String, dynamic> validExecutionSummaryRpc({
  String actualCompletionDate = '2026-07-10',
  Object actualQuantityDelivered = '12.50',
  String quantityUnit = 'cylinder',
  Object contractedQuantityPerCycle = '10.00',
  int? coverageMonths = 1,
  int? coverageDays,
  String calculatedNextDueDate = '2026-08-10',
  String confirmedNextDueDate = '2026-08-12',
  bool nextDueOverridden = true,
}) {
  final map = <String, dynamic>{
    'actual_completion_date': actualCompletionDate,
    'actual_quantity_delivered': actualQuantityDelivered,
    'quantity_unit': quantityUnit,
    'contracted_quantity_per_cycle': contractedQuantityPerCycle,
    'calculated_next_due_date': calculatedNextDueDate,
    'confirmed_next_due_date': confirmedNextDueDate,
    'next_due_overridden': nextDueOverridden,
  };
  if (coverageMonths != null) {
    map['coverage_months'] = coverageMonths;
  }
  if (coverageDays != null) {
    map['coverage_days'] = coverageDays;
  }
  return map;
}

/// Month-coverage execution summary (coverage_days omitted).
Map<String, dynamic> monthCoverageExecutionSummaryRpc() {
  return validExecutionSummaryRpc(
    coverageMonths: 1,
    coverageDays: null,
    calculatedNextDueDate: '2026-08-10',
  );
}

/// Day-coverage execution summary (coverage_months omitted).
Map<String, dynamic> dayCoverageExecutionSummaryRpc() {
  return validExecutionSummaryRpc(
    coverageMonths: null,
    coverageDays: 30,
    calculatedNextDueDate: '2026-08-09',
  );
}

/// Complete event with `execution_summary: null` (key present).
Map<String, dynamic> validCalendarEventRpc({
  String id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  String type = 'refill_due',
  String status = 'pending',
  String sourceKind = 'contract_generated',
  String scheduledDate = '2026-07-14',
  String originalDueDate = '2026-07-14',
  String titleAr = 'تعبئة',
  String? titleEn = 'Refill',
  bool isRescheduled = false,
  Object? executionSummary,
  bool omitOptionalLinkedEntities = false,
  Object? qtyPerRefill = '2.5',
  String? qtyUnit = 'cylinder',
  Map<String, dynamic>? workingDay,
  String scheduleState = 'working_day',
  String overdueState = 'not_overdue',
}) {
  final event = <String, dynamic>{
    'id': id,
    'type': type,
    'status': status,
    'source_kind': sourceKind,
    'scheduled_date': scheduledDate,
    'original_due_date': originalDueDate,
    'title_ar': titleAr,
    'title_en': titleEn,
    'is_rescheduled': isRescheduled,
    'directions_available': false,
    'schedule_state': scheduleState,
    'working_day': workingDay ?? validWorkingDayRpc(date: scheduledDate),
    'is_overdue': false,
    'overdue_days': 0,
    'overdue_state': overdueState,
    'available_actions': validAvailableActionsRpc(),
    'execution_summary': executionSummary,
    'qty_per_refill': qtyPerRefill,
    'qty_unit': qtyUnit,
    'operational_metadata': {'action_kind': 'refill'},
  };

  if (!omitOptionalLinkedEntities) {
    event.addAll({
      'assigned_agent_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'assigned_agent_name_ar': 'وكيل',
      'assigned_agent_name_en': 'Agent',
      'customer_id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'customer_name_ar': 'عميل',
      'customer_name_en': 'Customer',
      'service_location_id': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      'service_location_name': 'Main',
      'location_governorate': 'Capital',
      'location_area': 'Sharq',
      'contract_id': 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      'contract_number': 'C-100',
      'contract_line_id': 'ffffffff-ffff-ffff-ffff-ffffffffffff',
      'product_name_ar': 'منتج',
      'product_name_en': 'Product',
    });
  }

  return event;
}

/// Event with unconfigured working_day + schedule_state schedule_unconfigured.
Map<String, dynamic> unconfiguredCalendarEventRpc({
  String id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  String scheduledDate = '2026-07-14',
}) {
  return validCalendarEventRpc(
    id: id,
    scheduledDate: scheduledDate,
    originalDueDate: scheduledDate,
    workingDay: unconfiguredWorkingDayRpc(date: scheduledDate),
    scheduleState: 'schedule_unconfigured',
    overdueState: 'schedule_unconfigured',
  );
}

/// Event with optional linked-entity keys absent (strip_nulls style).
Map<String, dynamic> validCalendarEventAbsentOptionalRpc() {
  return validCalendarEventRpc(omitOptionalLinkedEntities: true);
}

Map<String, dynamic> validRangeSummaryRpc({
  String dateFrom = '2026-07-01',
  String dateTo = '2026-07-31',
  String scope = 'tenant_wide',
  int? unassignedCount = 2,
  bool workingScheduleConfigured = true,
  String? tenantLocalToday = '2026-07-14',
  Map<String, dynamic>? overdueOutsideRange,
  Map<String, dynamic>? workingDay,
}) {
  final summary = <String, dynamic>{
    'date_from': dateFrom,
    'date_to': dateTo,
    'timezone_name': 'Asia/Kuwait',
    'working_schedule_configured': workingScheduleConfigured,
    'scope': scope,
    'filters_hash': 'hash-abc',
    'days': [
      {
        'date': '2026-07-14',
        'iso_weekday': 2,
        'event_count': 3,
        'unassigned_count': unassignedCount,
        'overdue_count': 1,
        'working_day': workingDay ?? validWorkingDayRpc(),
      },
    ],
    'overdue_outside_range':
        overdueOutsideRange ??
        {
          'state': 'available',
          'count': 1,
          'oldest_original_due_date': '2026-06-01',
        },
    'filters_applied': <String, dynamic>{},
  };
  if (tenantLocalToday != null) {
    summary['tenant_local_today'] = tenantLocalToday;
  }
  return summary;
}

/// Unconfigured days + overdue schedule_unconfigured + tenant_local_today
/// absent + working_schedule_configured false.
Map<String, dynamic> unconfiguredRangeSummaryRpc() {
  return validRangeSummaryRpc(
    workingScheduleConfigured: false,
    tenantLocalToday: null,
    workingDay: unconfiguredWorkingDayRpc(),
    overdueOutsideRange: {
      'state': 'schedule_unconfigured',
      'count': null,
      'oldest_original_due_date': null,
    },
  );
}

Map<String, dynamic> validAssignedOnlyRangeSummaryRpc() {
  return validRangeSummaryRpc(scope: 'assigned_only', unassignedCount: null);
}

Map<String, dynamic> scheduleUnconfiguredRangeSummaryRpc() {
  return validRangeSummaryRpc(
    workingScheduleConfigured: false,
    overdueOutsideRange: {
      'state': 'schedule_unconfigured',
      'count': null,
      'oldest_original_due_date': null,
    },
  );
}

Map<String, dynamic> validEventListRpc({
  String dateFrom = '2026-07-14',
  String dateTo = '2026-07-14',
  int limit = 50,
  String scope = 'tenant_wide',
  String? tenantLocalToday = '2026-07-14',
  List<Map<String, dynamic>>? inRangeRows,
  List<Map<String, dynamic>>? overdueRows,
  String? nextCursorInRange = 'cursor-in-1',
  String? nextCursorOverdue = 'cursor-od-1',
  bool hasMoreInRange = true,
  bool hasMoreOverdue = true,
}) {
  return {
    'date_from': dateFrom,
    'date_to': dateTo,
    'limit': limit,
    'scope': scope,
    'tenant_local_today': tenantLocalToday,
    'filters_hash': 'hash-list',
    'in_range': {
      'rows': inRangeRows ?? [validCalendarEventRpc()],
      'next_cursor': nextCursorInRange,
      'has_more': hasMoreInRange,
    },
    'overdue_outside_range': {
      'rows':
          overdueRows ??
          [
            validCalendarEventRpc(
              id: '99999999-9999-9999-9999-999999999999',
              scheduledDate: '2026-06-01',
              originalDueDate: '2026-06-01',
            ),
          ],
      'next_cursor': nextCursorOverdue,
      'has_more': hasMoreOverdue,
    },
  };
}
