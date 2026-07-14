import '../../auth/domain/app_session.dart';

bool canViewCalendarSettings(AppSession session) =>
    session.isManager ||
    session.permissions.can('settings.calendar.view') ||
    session.permissions.can('settings.calendar.edit');

bool canEditCalendarSettings(AppSession session) =>
    session.isManager || session.permissions.can('settings.calendar.edit');

bool canViewTenantCalendar(AppSession session) =>
    session.isManager || session.permissions.can('calendar.view');

bool canViewAssignedCalendar(AppSession session) =>
    session.permissions.can('calendar.view_assigned');

bool canAccessCalendar(AppSession session) =>
    canViewTenantCalendar(session) || canViewAssignedCalendar(session);

bool canCreateCalendarEvent(AppSession session) =>
    session.isManager || session.permissions.can('calendar.create');

bool canEditCalendarEvent(AppSession session) =>
    session.isManager || session.permissions.can('calendar.edit');
