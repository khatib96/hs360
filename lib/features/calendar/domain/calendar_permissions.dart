import '../../auth/domain/app_session.dart';

bool canViewCalendarSettings(AppSession session) =>
    session.isManager ||
    session.permissions.can('settings.calendar.view') ||
    session.permissions.can('settings.calendar.edit');

bool canEditCalendarSettings(AppSession session) =>
    session.isManager || session.permissions.can('settings.calendar.edit');
