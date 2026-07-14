import '../../auth/domain/app_session.dart';
import '../domain/calendar_permissions.dart';

/// Tenant-wide agent/unassigned filters require tenant calendar access, never
/// inferred from a null/loading scope alone.
bool calendarShowsTenantWideFilters(AppSession? session) {
  if (session == null) return false;
  return canViewTenantCalendar(session);
}
