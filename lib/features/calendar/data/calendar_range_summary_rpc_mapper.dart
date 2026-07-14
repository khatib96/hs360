import '../domain/calendar_enums.dart';
import '../domain/calendar_range_summary.dart';
import 'calendar_read_rpc_parsers.dart';

CalendarRangeSummaryResult mapCalendarRangeSummaryFromRpc(dynamic raw) {
  final map = requireMap(raw, 'calendar range summary root');

  final daysRaw = requireList(map['days'], 'days');
  final days = daysRaw.map((item) {
    final day = requireMap(item, 'days[]');
    return _mapDaySummary(day);
  }).toList();

  final overdueRaw = requireMap(
    map['overdue_outside_range'],
    'overdue_outside_range',
  );

  return CalendarRangeSummaryResult(
    dateFrom: parseRequiredCalendarDate(map['date_from']),
    dateTo: parseRequiredCalendarDate(map['date_to']),
    timezoneName: optionalString(map['timezone_name']),
    workingScheduleConfigured: requireBool(
      map['working_schedule_configured'],
      'working_schedule_configured',
    ),
    tenantLocalToday: parseOptionalCalendarDate(map['tenant_local_today']),
    scope: requireEnum(map['scope'], CalendarReadScope.fromRpc, 'scope'),
    filtersHash: requireString(map['filters_hash'], 'filters_hash'),
    days: days,
    overdueOutsideRange: _mapOverdueOutsideRange(overdueRaw),
    filtersApplied: mapCalendarFiltersApplied(map['filters_applied']),
  );
}

CalendarDaySummary _mapDaySummary(Map<String, dynamic> raw) {
  final workingDayRaw = requireMap(raw['working_day'], 'days[].working_day');

  int? unassignedCount;
  if (raw.containsKey('unassigned_count')) {
    unassignedCount = parseNullableInt(
      raw['unassigned_count'],
      'days[].unassigned_count',
    );
  }

  return CalendarDaySummary(
    date: parseRequiredCalendarDate(raw['date']),
    isoWeekday: requireInt(raw['iso_weekday'], 'days[].iso_weekday'),
    eventCount: requireInt(raw['event_count'], 'days[].event_count'),
    unassignedCount: unassignedCount,
    overdueCount: requireInt(raw['overdue_count'], 'days[].overdue_count'),
    workingDay: mapCalendarWorkingDay(workingDayRaw),
  );
}

CalendarOverdueOutsideRangeSummary _mapOverdueOutsideRange(
  Map<String, dynamic> raw,
) {
  return CalendarOverdueOutsideRangeSummary(
    state: requireEnum(
      raw['state'],
      CalendarOverdueOutsideRangeState.fromRpc,
      'overdue_outside_range.state',
    ),
    count: parseNullableInt(raw['count'], 'overdue_outside_range.count'),
    oldestOriginalDueDate: parseOptionalCalendarDate(
      raw['oldest_original_due_date'],
    ),
  );
}
