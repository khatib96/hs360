import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_settings_validator.dart';

List<WorkingDayRow> _configuredDays() {
  return [
    const WorkingDayRow(
      isoWeekday: 1,
      mode: TenantWorkingDayMode.workingHours,
      workStart: '08:00',
      workEnd: '17:00',
    ),
    const WorkingDayRow(isoWeekday: 2, mode: TenantWorkingDayMode.dayOff),
    const WorkingDayRow(isoWeekday: 3, mode: TenantWorkingDayMode.hours24),
    const WorkingDayRow(
      isoWeekday: 4,
      mode: TenantWorkingDayMode.workingHours,
      workStart: '09:00',
      workEnd: '18:00',
    ),
    const WorkingDayRow(isoWeekday: 5, mode: TenantWorkingDayMode.dayOff),
    const WorkingDayRow(isoWeekday: 6, mode: TenantWorkingDayMode.hours24),
    const WorkingDayRow(
      isoWeekday: 7,
      mode: TenantWorkingDayMode.workingHours,
      workStart: '10:00',
      workEnd: '14:00',
    ),
  ];
}

void main() {
  group('CalendarSettingsValidator', () {
    test('accepts complete valid configuration', () {
      final result = CalendarSettingsValidator.validateForSave(
        timezoneName: 'Asia/Kuwait',
        days: _configuredDays(),
      );
      expect(result.isValid, isTrue);
    });

    test('requires timezone', () {
      final result = CalendarSettingsValidator.validateForSave(
        timezoneName: '',
        days: _configuredDays(),
      );
      expect(result.fieldErrors['timezone'], 'timezone_required');
    });

    test('rejects unreviewed day', () {
      final days = _configuredDays();
      days[0] = const WorkingDayRow(isoWeekday: 1);
      final result = CalendarSettingsValidator.validateForSave(
        timezoneName: 'Asia/Kuwait',
        days: days,
      );
      expect(result.fieldErrors['day_1'], 'day_unreviewed');
    });

    test('rejects working hours without times', () {
      final days = _configuredDays();
      days[0] = const WorkingDayRow(
        isoWeekday: 1,
        mode: TenantWorkingDayMode.workingHours,
      );
      final result = CalendarSettingsValidator.validateForSave(
        timezoneName: 'Asia/Kuwait',
        days: days,
      );
      expect(result.fieldErrors['day_1'], 'working_hours_required');
    });

    test('rejects end before start', () {
      final days = _configuredDays();
      days[0] = const WorkingDayRow(
        isoWeekday: 1,
        mode: TenantWorkingDayMode.workingHours,
        workStart: '17:00',
        workEnd: '08:00',
      );
      final result = CalendarSettingsValidator.validateForSave(
        timezoneName: 'Asia/Kuwait',
        days: days,
      );
      expect(result.fieldErrors['day_1'], 'invalid_time_window');
    });

    test('rejects times on day off', () {
      final days = _configuredDays();
      days[1] = const WorkingDayRow(
        isoWeekday: 2,
        mode: TenantWorkingDayMode.dayOff,
        workStart: '08:00',
        workEnd: '17:00',
      );
      final result = CalendarSettingsValidator.validateForSave(
        timezoneName: 'Asia/Kuwait',
        days: days,
      );
      expect(result.fieldErrors['day_2'], 'times_not_allowed');
    });

    test('rejects invalid hour and minute boundaries', () {
      const timezone = 'Asia/Kuwait';

      List<WorkingDayRow> daysWithStart(String start, String end) {
        final days = List<WorkingDayRow>.from(_configuredDays());
        days[0] = WorkingDayRow(
          isoWeekday: 1,
          mode: TenantWorkingDayMode.workingHours,
          workStart: start,
          workEnd: end,
        );
        return days;
      }

      expect(
        CalendarSettingsValidator.validateForSave(
          timezoneName: timezone,
          days: daysWithStart('00:00', '17:00'),
        ).isValid,
        isTrue,
      );

      expect(
        CalendarSettingsValidator.validateForSave(
          timezoneName: timezone,
          days: daysWithStart('08:00', '23:59'),
        ).isValid,
        isTrue,
      );

      for (final invalid in ['24:00', '12:60', '99:99', 'ab:cd', '8:00']) {
        final result = CalendarSettingsValidator.validateForSave(
          timezoneName: timezone,
          days: daysWithStart(invalid, '17:00'),
        );
        expect(result.isValid, isFalse, reason: invalid);
        expect(result.fieldErrors['day_1'], 'working_hours_required');
      }
    });

    test('rejects incomplete weekday set', () {
      final result = CalendarSettingsValidator.validateForSave(
        timezoneName: 'Asia/Kuwait',
        days: _configuredDays().take(6).toList(),
      );
      expect(result.fieldErrors['days'], 'days_incomplete');
    });
  });
}
