import '../domain/calendar_settings.dart';
import '../domain/calendar_working_day.dart';
import 'calendar_read_rpc_primitives.dart';

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
    return malformedCalendarResponse(
      'working_day: day_mode unreviewed but is_unreviewed is false',
    );
  }
  for (final key in ['is_day_off', 'is_24_hours', 'is_working_hours']) {
    final flag = optionalBool(raw[key], 'working_day.$key');
    if (flag == true) {
      return malformedCalendarResponse(
        'working_day: unreviewed day_mode cannot have $key=true',
      );
    }
  }
  if (raw['work_start'] != null || raw['work_end'] != null) {
    return malformedCalendarResponse(
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
    return malformedCalendarResponse(
      'working_day: configured day_mode cannot have is_unreviewed=true',
    );
  }

  switch (dayMode) {
    case TenantWorkingDayMode.dayOff:
      if (!isDayOff || is24Hours || isWorkingHours) {
        return malformedCalendarResponse(
          'working_day: day_off flags inconsistent',
        );
      }
      if (workStart != null || workEnd != null) {
        return malformedCalendarResponse(
          'working_day: day_off cannot include work window',
        );
      }
    case TenantWorkingDayMode.hours24:
      if (!is24Hours || isDayOff || isWorkingHours) {
        return malformedCalendarResponse(
          'working_day: 24_hours flags inconsistent',
        );
      }
      if (workStart != null || workEnd != null) {
        return malformedCalendarResponse(
          'working_day: 24_hours cannot include work window',
        );
      }
    case TenantWorkingDayMode.workingHours:
      if (!isWorkingHours || isDayOff || is24Hours) {
        return malformedCalendarResponse(
          'working_day: working_hours flags inconsistent',
        );
      }
      if (workStart == null || workEnd == null) {
        return malformedCalendarResponse(
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
    return malformedCalendarResponse(
      'working_day.day_mode: expected string or null, got ${value.runtimeType}',
    );
  }
  final mode = TenantWorkingDayMode.fromRpc(value);
  if (mode == null) {
    return malformedCalendarResponse(
      'working_day.day_mode: unknown value "$value"',
    );
  }
  return mode;
}
