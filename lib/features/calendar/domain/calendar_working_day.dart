import 'calendar_settings.dart';
import 'calendar_working_date_exception.dart';

/// Resolved working-day window for a single tenant-local date.
class CalendarWorkingDay {
  const CalendarWorkingDay({
    required this.tenantId,
    required this.date,
    required this.isoWeekday,
    required this.scheduleConfigured,
    this.timezoneName,
    required this.dayMode,
    this.workStart,
    this.workEnd,
    required this.isUnreviewed,
    required this.isDayOff,
    required this.is24Hours,
    required this.isWorkingHours,
    this.dateException,
  });

  final String tenantId;
  final DateTime date;
  final int isoWeekday;
  final bool scheduleConfigured;
  final String? timezoneName;
  final TenantWorkingDayMode dayMode;
  final String? workStart;
  final String? workEnd;
  final bool isUnreviewed;
  final bool isDayOff;
  final bool is24Hours;
  final bool isWorkingHours;

  /// M7B: the active `official_holiday`/`company_closure`/
  /// `exceptional_working_day` override for [date], if any. When present,
  /// this date's [dayMode]/window already reflects the exception (the
  /// weekly schedule was overridden server-side).
  final CalendarDateExceptionRef? dateException;
}
