import 'calendar_enums.dart';
import 'calendar_filters.dart';
import 'calendar_working_day.dart';

/// Dense per-day summary inside a range response.
class CalendarDaySummary {
  const CalendarDaySummary({
    required this.date,
    required this.isoWeekday,
    required this.eventCount,
    this.unassignedCount,
    required this.overdueCount,
    required this.workingDay,
  });

  final DateTime date;
  final int isoWeekday;
  final int eventCount;

  /// Null for assigned-only scope (server masks unassigned leakage).
  final int? unassignedCount;
  final int overdueCount;
  final CalendarWorkingDay workingDay;
}

/// Overdue-outside-range summary block on range responses.
class CalendarOverdueOutsideRangeSummary {
  const CalendarOverdueOutsideRangeSummary({
    required this.state,
    this.count,
    this.oldestOriginalDueDate,
  });

  final CalendarOverdueOutsideRangeState state;
  final int? count;
  final DateTime? oldestOriginalDueDate;
}

/// Result of `get_calendar_range_summary`.
class CalendarRangeSummaryResult {
  CalendarRangeSummaryResult({
    required this.dateFrom,
    required this.dateTo,
    this.timezoneName,
    required this.workingScheduleConfigured,
    this.tenantLocalToday,
    required this.scope,
    required this.filtersHash,
    required List<CalendarDaySummary> days,
    required this.overdueOutsideRange,
    required this.filtersApplied,
  }) : days = List.unmodifiable(List<CalendarDaySummary>.from(days));

  final DateTime dateFrom;
  final DateTime dateTo;
  final String? timezoneName;
  final bool workingScheduleConfigured;
  final DateTime? tenantLocalToday;
  final CalendarReadScope scope;
  final String filtersHash;
  final List<CalendarDaySummary> days;
  final CalendarOverdueOutsideRangeSummary overdueOutsideRange;
  final CalendarFilters filtersApplied;
}
