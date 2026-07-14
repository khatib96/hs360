import '../../auth/domain/app_session.dart';
import 'calendar_date.dart';
import 'calendar_enums.dart';
import 'calendar_filters.dart';
import 'calendar_permissions.dart';

/// Outcome of [CalendarFilterValidator.validate].
class CalendarFilterValidationResult {
  const CalendarFilterValidationResult({this.codes = const []});

  const CalendarFilterValidationResult.valid() : codes = const [];

  final List<String> codes;

  bool get isValid => codes.isEmpty;
}

/// Client-side validation for calendar read filters and range bounds.
class CalendarFilterValidator {
  static const rangeSpanInvalid = 'range_span_invalid';
  static const searchTooShort = 'search_too_short';
  static const unassignedAssignedConflict = 'unassigned_assigned_conflict';
  static const overdueRequiresPending = 'overdue_requires_pending';
  static const pageLimitInvalid = 'page_limit_invalid';
  static const assignedOnlyAgentFilterForbidden =
      'assigned_only_agent_filter_forbidden';
  static const assignedOnlyUnassignedForbidden =
      'assigned_only_unassigned_forbidden';

  static CalendarFilterValidationResult validate({
    required DateTime dateFrom,
    required DateTime dateTo,
    required CalendarFilters filters,
    required AppSession session,
    int? pageLimit,
  }) {
    final codes = <String>[];

    final span = inclusiveDaySpan(dateFrom, dateTo);
    if (span < CalendarFilters.minRangeDays ||
        span > CalendarFilters.maxRangeDays) {
      codes.add(rangeSpanInvalid);
    }

    final search = filters.search?.trim() ?? '';
    if (search.isNotEmpty && search.length < 2) {
      codes.add(searchTooShort);
    }

    final agentId = filters.assignedAgentId?.trim();
    final hasAgent = agentId != null && agentId.isNotEmpty;
    if (filters.unassignedOnly && hasAgent) {
      codes.add(unassignedAssignedConflict);
    }

    if (filters.overdueOnly) {
      final statuses = filters.statuses;
      if (statuses != null &&
          statuses.isNotEmpty &&
          !statuses.contains(CalendarEventStatus.pending)) {
        codes.add(overdueRequiresPending);
      }
    }

    if (pageLimit != null &&
        (pageLimit < 1 || pageLimit > CalendarFilters.maxPageLimit)) {
      codes.add(pageLimitInvalid);
    }

    final assignedOnly =
        canAccessCalendar(session) && !canViewTenantCalendar(session);
    if (assignedOnly) {
      if (hasAgent) {
        codes.add(assignedOnlyAgentFilterForbidden);
      }
      if (filters.unassignedOnly) {
        codes.add(assignedOnlyUnassignedForbidden);
      }
    }

    if (codes.isEmpty) {
      return const CalendarFilterValidationResult.valid();
    }
    return CalendarFilterValidationResult(codes: codes);
  }
}
