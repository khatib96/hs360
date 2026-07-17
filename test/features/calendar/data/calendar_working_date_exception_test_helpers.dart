import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';

AppSession testSession({
  Set<String> permissions = const {},
  bool isManager = false,
}) {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: isManager ? 'manager' : 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: isManager, permissions: permissions),
  );
}

WorkingDateExceptionData sampleWorkingDateExceptionData({
  CalendarWorkingDateExceptionKind kind =
      CalendarWorkingDateExceptionKind.officialHoliday,
}) {
  return WorkingDateExceptionData(
    kind: kind,
    startDate: DateTime(2026, 8, 1),
    endDate: DateTime(2026, 8, 1),
    titleAr: 'عيد',
    titleEn: 'Holiday',
  );
}
