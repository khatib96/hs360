import '../domain/calendar_settings.dart';

CalendarSettings mapCalendarSettingsFromRpc(Map<String, dynamic> raw) {
  final daysRaw = raw['days'];
  final days = daysRaw is List
      ? daysRaw
            .map(
              (item) => mapWorkingDayFromRpc(Map<String, dynamic>.from(item)),
            )
            .toList()
      : CalendarSettings.defaultUnreviewedDays();

  days.sort((a, b) => a.isoWeekday.compareTo(b.isoWeekday));

  return CalendarSettings(
    timezoneName: raw['timezone_name'] as String?,
    timezoneConfirmed: raw['timezone_confirmed'] == true,
    legacyTimezoneSuggestion: raw['legacy_timezone_suggestion'] as String?,
    workingScheduleConfigured: raw['working_schedule_configured'] == true,
    remindEventWorkdayStart: raw['remind_event_workday_start'] != false,
    remindPreviousWorkdayStart: raw['remind_previous_workday_start'] != false,
    canEdit: raw['can_edit'] == true,
    days: days.length == 7 ? days : CalendarSettings.defaultUnreviewedDays(),
  );
}

WorkingDayRow mapWorkingDayFromRpc(Map<String, dynamic> raw) {
  final iso = raw['iso_weekday'];
  return WorkingDayRow(
    isoWeekday: iso is int ? iso : int.tryParse('$iso') ?? 1,
    mode:
        TenantWorkingDayMode.fromRpc(raw['day_mode'] as String?) ??
        TenantWorkingDayMode.unreviewed,
    workStart: raw['work_start'] as String? ?? '',
    workEnd: raw['work_end'] as String? ?? '',
  );
}

Map<String, dynamic> mapCalendarSettingsToUpdatePayload({
  required String timezoneName,
  required bool remindEventWorkdayStart,
  required bool remindPreviousWorkdayStart,
  required List<WorkingDayRow> days,
}) {
  return {
    'timezone_name': timezoneName,
    'remind_event_workday_start': remindEventWorkdayStart,
    'remind_previous_workday_start': remindPreviousWorkdayStart,
    'days': days
        .map(
          (day) => {
            'iso_weekday': day.isoWeekday,
            'day_mode': day.mode.toRpc(),
            if (day.mode == TenantWorkingDayMode.workingHours) ...{
              'work_start': day.workStart,
              'work_end': day.workEnd,
            },
          },
        )
        .toList(),
  };
}

List<String> mapTimezoneListFromRpc(dynamic rows) {
  if (rows is! List) return const [];
  return rows
      .map((row) {
        if (row is Map) {
          return row['timezone_name'] as String? ?? row['name'] as String?;
        }
        return row as String?;
      })
      .whereType<String>()
      .toList();
}
