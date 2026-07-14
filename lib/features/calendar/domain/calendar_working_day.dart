import 'calendar_settings.dart';

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
}
