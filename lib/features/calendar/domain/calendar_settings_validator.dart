import 'calendar_settings.dart';

class CalendarSettingsValidationResult {
  const CalendarSettingsValidationResult({this.fieldErrors = const {}});

  final Map<String, String> fieldErrors;

  bool get isValid => fieldErrors.isEmpty;
}

class CalendarSettingsValidator {
  static final _timePattern = RegExp(r'^\d{2}:\d{2}$');

  static CalendarSettingsValidationResult validateForSave({
    required String? timezoneName,
    required List<WorkingDayRow> days,
  }) {
    final errors = <String, String>{};

    if (timezoneName == null || timezoneName.trim().isEmpty) {
      errors['timezone'] = 'timezone_required';
    }

    if (days.length != 7) {
      errors['days'] = 'days_incomplete';
      return CalendarSettingsValidationResult(fieldErrors: errors);
    }

    final seen = <int>{};
    for (final day in days) {
      if (day.isoWeekday < 1 || day.isoWeekday > 7) {
        errors['day_${day.isoWeekday}'] = 'invalid_weekday';
        continue;
      }
      if (seen.contains(day.isoWeekday)) {
        errors['day_${day.isoWeekday}'] = 'duplicate_weekday';
      }
      seen.add(day.isoWeekday);

      switch (day.mode) {
        case TenantWorkingDayMode.unreviewed:
          errors['day_${day.isoWeekday}'] = 'day_unreviewed';
        case TenantWorkingDayMode.workingHours:
          if (!_isValidTime(day.workStart) || !_isValidTime(day.workEnd)) {
            errors['day_${day.isoWeekday}'] = 'working_hours_required';
          } else if (!_isStartBeforeEnd(day.workStart, day.workEnd)) {
            errors['day_${day.isoWeekday}'] = 'invalid_time_window';
          }
        case TenantWorkingDayMode.dayOff:
        case TenantWorkingDayMode.hours24:
          if (day.workStart.isNotEmpty || day.workEnd.isNotEmpty) {
            errors['day_${day.isoWeekday}'] = 'times_not_allowed';
          }
      }
    }

    if (seen.length != 7) {
      errors['days'] = 'days_incomplete';
    }

    return CalendarSettingsValidationResult(fieldErrors: errors);
  }

  static bool _isValidTime(String value) {
    if (value.isEmpty || !_timePattern.hasMatch(value)) return false;
    final parts = value.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return false;
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  static bool _isStartBeforeEnd(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startHour = int.tryParse(startParts[0]);
    final startMinute = int.tryParse(startParts[1]);
    final endHour = int.tryParse(endParts[0]);
    final endMinute = int.tryParse(endParts[1]);
    if (startHour == null ||
        startMinute == null ||
        endHour == null ||
        endMinute == null) {
      return false;
    }
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    return startMinutes < endMinutes;
  }
}
