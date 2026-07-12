import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/data/calendar_settings_rpc_mapper.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';

void main() {
  group('calendar_settings_rpc_mapper', () {
    test('mapCalendarSettingsFromRpc parses settings and sorts days', () {
      final settings = mapCalendarSettingsFromRpc({
        'timezone_name': 'Asia/Dubai',
        'timezone_confirmed': true,
        'legacy_timezone_suggestion': 'Asia/Kuwait',
        'working_schedule_configured': true,
        'remind_event_workday_start': false,
        'remind_previous_workday_start': true,
        'can_edit': true,
        'days': [
          {
            'iso_weekday': 7,
            'day_mode': 'day_off',
            'work_start': null,
            'work_end': null,
          },
          {
            'iso_weekday': 1,
            'day_mode': 'working_hours',
            'work_start': '08:00',
            'work_end': '17:00',
          },
          {'iso_weekday': 2, 'day_mode': '24_hours'},
          {'iso_weekday': 3, 'day_mode': 'day_off'},
          {
            'iso_weekday': 4,
            'day_mode': 'working_hours',
            'work_start': '09:00',
            'work_end': '18:00',
          },
          {'iso_weekday': 5, 'day_mode': 'day_off'},
          {'iso_weekday': 6, 'day_mode': '24_hours'},
        ],
      });

      expect(settings.timezoneName, 'Asia/Dubai');
      expect(settings.timezoneConfirmed, isTrue);
      expect(settings.legacyTimezoneSuggestion, 'Asia/Kuwait');
      expect(settings.workingScheduleConfigured, isTrue);
      expect(settings.remindEventWorkdayStart, isFalse);
      expect(settings.remindPreviousWorkdayStart, isTrue);
      expect(settings.canEdit, isTrue);
      expect(settings.days, hasLength(7));
      expect(settings.days.first.isoWeekday, 1);
      expect(settings.days.first.mode, TenantWorkingDayMode.workingHours);
      expect(settings.days.last.isoWeekday, 7);
    });

    test('mapCalendarSettingsFromRpc falls back when days incomplete', () {
      final settings = mapCalendarSettingsFromRpc({
        'timezone_name': 'UTC',
        'days': [
          {'iso_weekday': 1, 'day_mode': 'day_off'},
        ],
      });

      expect(settings.days, hasLength(7));
      expect(
        settings.days.every((d) => d.mode == TenantWorkingDayMode.unreviewed),
        isTrue,
      );
    });

    test(
      'mapCalendarSettingsToUpdatePayload omits times for non-working modes',
      () {
        final payload = mapCalendarSettingsToUpdatePayload(
          timezoneName: 'Asia/Kuwait',
          remindEventWorkdayStart: true,
          remindPreviousWorkdayStart: false,
          days: [
            const WorkingDayRow(
              isoWeekday: 1,
              mode: TenantWorkingDayMode.workingHours,
              workStart: '08:00',
              workEnd: '17:00',
            ),
            const WorkingDayRow(
              isoWeekday: 2,
              mode: TenantWorkingDayMode.dayOff,
            ),
          ],
        );

        expect(payload['timezone_name'], 'Asia/Kuwait');
        expect(payload['remind_event_workday_start'], isTrue);
        expect(payload['remind_previous_workday_start'], isFalse);
        final days = payload['days'] as List;
        expect(days.first['work_start'], '08:00');
        expect(days.first['work_end'], '17:00');
        expect(days[1].containsKey('work_start'), isFalse);
      },
    );

    test('mapWorkingDayFromRpc maps all day modes', () {
      expect(
        mapWorkingDayFromRpc({'iso_weekday': 1, 'day_mode': null}).mode,
        TenantWorkingDayMode.unreviewed,
      );
      expect(
        mapWorkingDayFromRpc({'iso_weekday': 2, 'day_mode': 'day_off'}).mode,
        TenantWorkingDayMode.dayOff,
      );
      expect(
        mapWorkingDayFromRpc({
          'iso_weekday': 3,
          'day_mode': 'working_hours',
          'work_start': '08:00',
          'work_end': '17:00',
        }).workStart,
        '08:00',
      );
      expect(
        mapWorkingDayFromRpc({'iso_weekday': 4, 'day_mode': '24_hours'}).mode,
        TenantWorkingDayMode.hours24,
      );
    });

    test('mapTimezoneListFromRpc parses table rows and strings', () {
      expect(
        mapTimezoneListFromRpc([
          {'timezone_name': 'Asia/Kuwait'},
          {'name': 'UTC'},
          'Europe/London',
        ]),
        ['Asia/Kuwait', 'UTC', 'Europe/London'],
      );
      expect(mapTimezoneListFromRpc(null), isEmpty);
    });
  });
}
