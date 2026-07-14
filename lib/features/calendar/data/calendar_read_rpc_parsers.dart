import 'package:decimal/decimal.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../../core/utils/decimal_parser.dart';
import '../domain/calendar_available_actions.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_enums.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_execution_summary.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_operational_metadata.dart';
import '../domain/calendar_settings.dart';
import '../domain/calendar_working_day.dart';

Never _malformed(String detail) {
  throw CalendarException(
    code: CalendarException.malformedResponse,
    technicalDetail: detail,
  );
}

Map<String, dynamic> requireMap(dynamic value, String detail) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return _malformed(detail);
}

List<dynamic> requireList(dynamic value, String detail) {
  if (value is List) return value;
  return _malformed(detail);
}

String? optionalString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return _malformed('expected string or null, got ${value.runtimeType}');
}

String requireString(dynamic value, String detail) {
  if (value is String) return value;
  return _malformed(detail);
}

bool requireBool(dynamic value, String detail) {
  if (value is bool) return value;
  return _malformed(detail);
}

/// Nullable/absent bool → null (does not reject).
bool? optionalBool(dynamic value, String detail) {
  if (value == null) return null;
  if (value is bool) return value;
  return _malformed(detail);
}

int requireInt(dynamic value, String detail) {
  if (value is int) return value;
  if (value is num) {
    final asInt = value.toInt();
    if (asInt == value) return asInt;
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return _malformed(detail);
}

int? parseNullableInt(dynamic value, String detail) {
  if (value == null) return null;
  return requireInt(value, detail);
}

DateTime parseRequiredCalendarDate(dynamic value) {
  if (value is! String) {
    return _malformed('expected YYYY-MM-DD string, got ${value.runtimeType}');
  }
  try {
    return parseCalendarDateOnly(value);
  } on FormatException catch (e) {
    return _malformed(e.message);
  }
}

DateTime? parseOptionalCalendarDate(dynamic value) {
  if (value == null) return null;
  return parseRequiredCalendarDate(value);
}

T requireEnum<T>(dynamic value, T? Function(String) fromRpc, String detail) {
  final raw = requireString(value, detail);
  final parsed = fromRpc(raw);
  if (parsed == null) return _malformed('$detail: unknown value "$raw"');
  return parsed;
}

T? optionalEnum<T>(dynamic value, T? Function(String) fromRpc, String detail) {
  if (value == null) return null;
  return requireEnum(value, fromRpc, detail);
}

/// Maps `resolve_tenant_working_window` JSON, including post-`jsonb_strip_nulls`
/// shapes for unconfigured days (null mode flags omitted).
CalendarWorkingDay mapCalendarWorkingDay(Map<String, dynamic> raw) {
  final dayMode = _parseWorkingDayMode(raw);
  final scheduleConfigured = requireBool(
    raw['schedule_configured'],
    'working_day.schedule_configured',
  );

  if (dayMode == TenantWorkingDayMode.unreviewed) {
    return _mapUnreviewedWorkingDay(
      raw,
      scheduleConfigured: scheduleConfigured,
    );
  }

  return _mapConfiguredWorkingDay(
    raw,
    dayMode: dayMode,
    scheduleConfigured: scheduleConfigured,
  );
}

CalendarWorkingDay _mapUnreviewedWorkingDay(
  Map<String, dynamic> raw, {
  required bool scheduleConfigured,
}) {
  // SQL: NULL = enum yields NULL flags; strip_nulls removes them.
  final isUnreviewed = optionalBool(
    raw['is_unreviewed'],
    'working_day.is_unreviewed',
  );
  if (isUnreviewed == false) {
    return _malformed(
      'working_day: day_mode unreviewed but is_unreviewed is false',
    );
  }
  for (final key in ['is_day_off', 'is_24_hours', 'is_working_hours']) {
    final flag = optionalBool(raw[key], 'working_day.$key');
    if (flag == true) {
      return _malformed(
        'working_day: unreviewed day_mode cannot have $key=true',
      );
    }
  }
  if (raw['work_start'] != null || raw['work_end'] != null) {
    return _malformed(
      'working_day: unreviewed day_mode cannot include work window',
    );
  }

  return CalendarWorkingDay(
    tenantId: requireString(raw['tenant_id'], 'working_day.tenant_id'),
    date: parseRequiredCalendarDate(raw['date']),
    isoWeekday: requireInt(raw['iso_weekday'], 'working_day.iso_weekday'),
    scheduleConfigured: scheduleConfigured,
    timezoneName: optionalString(raw['timezone_name']),
    dayMode: TenantWorkingDayMode.unreviewed,
    workStart: null,
    workEnd: null,
    isUnreviewed: true,
    isDayOff: false,
    is24Hours: false,
    isWorkingHours: false,
  );
}

CalendarWorkingDay _mapConfiguredWorkingDay(
  Map<String, dynamic> raw, {
  required TenantWorkingDayMode dayMode,
  required bool scheduleConfigured,
}) {
  final isUnreviewed = requireBool(
    raw['is_unreviewed'],
    'working_day.is_unreviewed',
  );
  final isDayOff = requireBool(raw['is_day_off'], 'working_day.is_day_off');
  final is24Hours = requireBool(raw['is_24_hours'], 'working_day.is_24_hours');
  final isWorkingHours = requireBool(
    raw['is_working_hours'],
    'working_day.is_working_hours',
  );
  final workStart = optionalString(raw['work_start']);
  final workEnd = optionalString(raw['work_end']);

  if (isUnreviewed) {
    return _malformed(
      'working_day: configured day_mode cannot have is_unreviewed=true',
    );
  }

  switch (dayMode) {
    case TenantWorkingDayMode.dayOff:
      if (!isDayOff || is24Hours || isWorkingHours) {
        return _malformed('working_day: day_off flags inconsistent');
      }
      if (workStart != null || workEnd != null) {
        return _malformed('working_day: day_off cannot include work window');
      }
    case TenantWorkingDayMode.hours24:
      if (!is24Hours || isDayOff || isWorkingHours) {
        return _malformed('working_day: 24_hours flags inconsistent');
      }
      if (workStart != null || workEnd != null) {
        return _malformed('working_day: 24_hours cannot include work window');
      }
    case TenantWorkingDayMode.workingHours:
      if (!isWorkingHours || isDayOff || is24Hours) {
        return _malformed('working_day: working_hours flags inconsistent');
      }
      if (workStart == null || workEnd == null) {
        return _malformed(
          'working_day: working_hours requires work_start and work_end',
        );
      }
    case TenantWorkingDayMode.unreviewed:
      break;
  }

  return CalendarWorkingDay(
    tenantId: requireString(raw['tenant_id'], 'working_day.tenant_id'),
    date: parseRequiredCalendarDate(raw['date']),
    isoWeekday: requireInt(raw['iso_weekday'], 'working_day.iso_weekday'),
    scheduleConfigured: scheduleConfigured,
    timezoneName: optionalString(raw['timezone_name']),
    dayMode: dayMode,
    workStart: workStart,
    workEnd: workEnd,
    isUnreviewed: false,
    isDayOff: isDayOff,
    is24Hours: is24Hours,
    isWorkingHours: isWorkingHours,
  );
}

TenantWorkingDayMode _parseWorkingDayMode(Map<String, dynamic> raw) {
  if (!raw.containsKey('day_mode') || raw['day_mode'] == null) {
    return TenantWorkingDayMode.unreviewed;
  }
  final value = raw['day_mode'];
  if (value is! String) {
    return _malformed(
      'working_day.day_mode: expected string or null, got ${value.runtimeType}',
    );
  }
  final mode = TenantWorkingDayMode.fromRpc(value);
  if (mode == null) {
    return _malformed('working_day.day_mode: unknown value "$value"');
  }
  return mode;
}

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

CalendarAvailableActions mapCalendarAvailableActions(Map<String, dynamic> raw) {
  return CalendarAvailableActions(
    canViewCustomer: requireBool(
      raw['can_view_customer'],
      'available_actions.can_view_customer',
    ),
    canViewContract: requireBool(
      raw['can_view_contract'],
      'available_actions.can_view_contract',
    ),
    canAssign: requireBool(raw['can_assign'], 'available_actions.can_assign'),
    canReschedule: requireBool(
      raw['can_reschedule'],
      'available_actions.can_reschedule',
    ),
    canCreateManual: requireBool(
      raw['can_create_manual'],
      'available_actions.can_create_manual',
    ),
    canOpenDirections: requireBool(
      raw['can_open_directions'],
      'available_actions.can_open_directions',
    ),
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

/// Maps an execution summary. Null remains null.
///
/// When present (migrations 094/097), required non-null fields are:
/// `actual_completion_date`, `actual_quantity_delivered`, `quantity_unit`,
/// `contracted_quantity_per_cycle`, `calculated_next_due_date`,
/// `confirmed_next_due_date`, `next_due_overridden`, and exactly one of
/// `coverage_months` / `coverage_days` with a positive value.
CalendarExecutionSummary? mapExecutionSummary(dynamic value) {
  if (value == null) return null;
  final map = requireMap(value, 'execution_summary');

  final quantityUnit = optionalString(map['quantity_unit']);
  if (quantityUnit == null || quantityUnit.isEmpty) {
    return _malformed('execution_summary.quantity_unit required');
  }

  final coverageMonths = parseNullableInt(
    map['coverage_months'],
    'execution_summary.coverage_months',
  );
  final coverageDays = parseNullableInt(
    map['coverage_days'],
    'execution_summary.coverage_days',
  );

  final hasMonths = coverageMonths != null;
  final hasDays = coverageDays != null;
  if (hasMonths == hasDays) {
    return _malformed(
      'execution_summary: exactly one of coverage_months or coverage_days',
    );
  }
  if (hasMonths && coverageMonths <= 0) {
    return _malformed('execution_summary.coverage_months must be > 0');
  }
  if (hasDays && coverageDays <= 0) {
    return _malformed('execution_summary.coverage_days must be > 0');
  }

  return CalendarExecutionSummary(
    actualCompletionDate: parseRequiredCalendarDate(
      map['actual_completion_date'],
    ),
    actualQuantityDelivered: _requireDecimal(
      map['actual_quantity_delivered'],
      'execution_summary.actual_quantity_delivered',
    ),
    quantityUnit: quantityUnit,
    contractedQuantityPerCycle: _requireDecimal(
      map['contracted_quantity_per_cycle'],
      'execution_summary.contracted_quantity_per_cycle',
    ),
    coverageMonths: coverageMonths,
    coverageDays: coverageDays,
    calculatedNextDueDate: parseRequiredCalendarDate(
      map['calculated_next_due_date'],
    ),
    confirmedNextDueDate: parseRequiredCalendarDate(
      map['confirmed_next_due_date'],
    ),
    nextDueOverridden: requireBool(
      map['next_due_overridden'],
      'execution_summary.next_due_overridden',
    ),
  );
}

CalendarEvent mapCalendarEvent(Map<String, dynamic> raw) {
  if (!raw.containsKey('execution_summary')) {
    return _malformed('event.execution_summary key required');
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
    qtyPerRefill: _optionalDecimal(
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
  );
}

Decimal? _optionalDecimal(dynamic value, String detail) {
  if (value == null) return null;
  return _requireDecimal(value, detail);
}

Decimal _requireDecimal(dynamic value, String detail) {
  if (value == null) return _malformed('$detail required');
  try {
    final parsed = tryParseDecimal(value);
    if (parsed == null) return _malformed(detail);
    return parsed;
  } on FormatException catch (e) {
    return _malformed('$detail: ${e.message}');
  }
}
