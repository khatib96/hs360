import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/data/calendar_settings_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';

import '../fake_calendar_settings_repository.dart';

AppSession _session({Set<String> permissions = const {}}) {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

List<WorkingDayRow> _validDays() {
  return List.generate(
    7,
    (index) =>
        WorkingDayRow(isoWeekday: index + 1, mode: TenantWorkingDayMode.dayOff),
  );
}

void main() {
  group('CalendarSettingsRepository permissions', () {
    test('fetchSettings requires view permission', () async {
      final repo = CalendarSettingsRepository(null);
      await expectLater(
        repo.fetchSettings(_session()),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.permissionDenied,
          ),
        ),
      );
    });

    test('updateSettings requires edit permission', () async {
      final repo = CalendarSettingsRepository(null);
      await expectLater(
        repo.updateSettings(
          _session(permissions: {'settings.calendar.view'}),
          timezoneName: 'UTC',
          remindEventWorkdayStart: true,
          remindPreviousWorkdayStart: true,
          days: _validDays(),
        ),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.permissionDenied,
          ),
        ),
      );
    });

    test('listTimezones requires view permission', () async {
      final repo = CalendarSettingsRepository(null);
      await expectLater(
        repo.listTimezones(_session()),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.permissionDenied,
          ),
        ),
      );
    });
  });

  group('FakeCalendarSettingsRepository', () {
    test('fetch and update delegate to fake state', () async {
      final fake = FakeCalendarSettingsRepository();
      final session = _session(permissions: {'settings.calendar.edit'});

      final loaded = await fake.fetchSettings(session);
      expect(loaded.timezoneName, 'Asia/Kuwait');
      expect(fake.fetchCount, 1);

      final updated = await fake.updateSettings(
        session,
        timezoneName: 'Asia/Dubai',
        remindEventWorkdayStart: false,
        remindPreviousWorkdayStart: true,
        days: _validDays(),
      );
      expect(updated.timezoneName, 'Asia/Dubai');
      expect(updated.workingScheduleConfigured, isTrue);
      expect(fake.updateCount, 1);
    });

    test('listTimezones filters by search', () async {
      final fake = FakeCalendarSettingsRepository();
      final session = _session(permissions: {'settings.calendar.view'});

      final all = await fake.listTimezones(session);
      expect(all, hasLength(3));

      final filtered = await fake.listTimezones(session, search: 'kuwait');
      expect(filtered, ['Asia/Kuwait']);
      expect(fake.lastTimezoneSearch, 'kuwait');
    });
  });
}
