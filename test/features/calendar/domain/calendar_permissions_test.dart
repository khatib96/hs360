import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/domain/calendar_permissions.dart';

AppSession _session({
  String accountType = 'user',
  Set<String> permissions = const {},
}) {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: accountType,
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: accountType == 'manager',
      permissions: permissions,
    ),
  );
}

void main() {
  group('calendar permissions', () {
    test('canViewTenantCalendar for view or manager only', () {
      expect(
        canViewTenantCalendar(_session(permissions: {'calendar.view'})),
        isTrue,
      );
      expect(canViewTenantCalendar(_session(accountType: 'manager')), isTrue);
      expect(
        canViewTenantCalendar(
          _session(permissions: {'calendar.view_assigned'}),
        ),
        isFalse,
      );
      expect(canViewTenantCalendar(_session()), isFalse);
    });

    test('canViewAssignedCalendar requires calendar.view_assigned', () {
      expect(
        canViewAssignedCalendar(
          _session(permissions: {'calendar.view_assigned'}),
        ),
        isTrue,
      );
      expect(
        canViewAssignedCalendar(_session(permissions: {'calendar.view'})),
        isFalse,
      );
      // Managers bypass AppPermissions.can, so this is true via manager bypass.
      expect(canViewAssignedCalendar(_session(accountType: 'manager')), isTrue);
      expect(canViewAssignedCalendar(_session()), isFalse);
    });

    test('canAccessCalendar is true for view, view_assigned, or manager', () {
      expect(canAccessCalendar(_session(accountType: 'manager')), isTrue);
      expect(
        canAccessCalendar(_session(permissions: {'calendar.view'})),
        isTrue,
      );
      expect(
        canAccessCalendar(_session(permissions: {'calendar.view_assigned'})),
        isTrue,
      );
      expect(canAccessCalendar(_session()), isFalse);
    });

    test('settings.calendar.view does not grant canAccessCalendar', () {
      expect(
        canAccessCalendar(_session(permissions: {'settings.calendar.view'})),
        isFalse,
      );
    });

    test('canCreateCalendarEvent and canEditCalendarEvent stay separate', () {
      final viewer = _session(permissions: {'calendar.view'});
      expect(canCreateCalendarEvent(viewer), isFalse);
      expect(canEditCalendarEvent(viewer), isFalse);

      expect(
        canCreateCalendarEvent(_session(permissions: {'calendar.create'})),
        isTrue,
      );
      expect(
        canEditCalendarEvent(_session(permissions: {'calendar.edit'})),
        isTrue,
      );
      expect(canCreateCalendarEvent(_session(accountType: 'manager')), isTrue);
      expect(canEditCalendarEvent(_session(accountType: 'manager')), isTrue);
    });

    test('settings helpers remain independent of calendar view', () {
      final settingsOnly = _session(permissions: {'settings.calendar.view'});
      expect(canViewCalendarSettings(settingsOnly), isTrue);
      expect(canEditCalendarSettings(settingsOnly), isFalse);
      expect(canAccessCalendar(settingsOnly), isFalse);

      final calendarOnly = _session(permissions: {'calendar.view'});
      expect(canAccessCalendar(calendarOnly), isTrue);
      expect(canViewCalendarSettings(calendarOnly), isFalse);

      expect(
        canEditCalendarSettings(
          _session(permissions: {'settings.calendar.edit'}),
        ),
        isTrue,
      );
      expect(
        canViewCalendarSettings(
          _session(permissions: {'settings.calendar.edit'}),
        ),
        isTrue,
      );
    });
  });
}
