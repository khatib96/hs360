import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_filter_validator.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';

AppSession _session({
  Set<String> permissions = const {},
  String accountType = 'user',
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
  group('CalendarFilterValidator', () {
    final from = DateTime(2026, 7, 1);
    final to = DateTime(2026, 7, 31);
    final tenantSession = _session(permissions: {'calendar.view'});

    test('accepts range of 1 and 62 days', () {
      expect(
        CalendarFilterValidator.validate(
          dateFrom: from,
          dateTo: from,
          filters: CalendarFilters.empty,
          session: tenantSession,
        ).isValid,
        isTrue,
      );
      expect(
        CalendarFilterValidator.validate(
          dateFrom: DateTime(2026, 7, 1),
          dateTo: DateTime(2026, 8, 31),
          filters: CalendarFilters.empty,
          session: tenantSession,
        ).isValid,
        isTrue,
      );
    });

    test('rejects span 0 and 63', () {
      final spanZero = CalendarFilterValidator.validate(
        dateFrom: DateTime(2026, 7, 2),
        dateTo: DateTime(2026, 7, 1),
        filters: CalendarFilters.empty,
        session: tenantSession,
      );
      expect(
        spanZero.codes,
        contains(CalendarFilterValidator.rangeSpanInvalid),
      );

      final span63 = CalendarFilterValidator.validate(
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 9, 1),
        filters: CalendarFilters.empty,
        session: tenantSession,
      );
      expect(span63.codes, contains(CalendarFilterValidator.rangeSpanInvalid));
    });

    test('rejects search shorter than 2 characters', () {
      final result = CalendarFilterValidator.validate(
        dateFrom: from,
        dateTo: to,
        filters: CalendarFilters(search: 'a'),
        session: tenantSession,
      );
      expect(result.codes, contains(CalendarFilterValidator.searchTooShort));
    });

    test('rejects unassigned + assigned agent together', () {
      final result = CalendarFilterValidator.validate(
        dateFrom: from,
        dateTo: to,
        filters: CalendarFilters(
          unassignedOnly: true,
          assignedAgentId: 'agent-1',
        ),
        session: tenantSession,
      );
      expect(
        result.codes,
        contains(CalendarFilterValidator.unassignedAssignedConflict),
      );
    });

    test('rejects overdue_only without pending in statuses', () {
      final result = CalendarFilterValidator.validate(
        dateFrom: from,
        dateTo: to,
        filters: CalendarFilters(
          overdueOnly: true,
          statuses: [CalendarEventStatus.done],
        ),
        session: tenantSession,
      );
      expect(
        result.codes,
        contains(CalendarFilterValidator.overdueRequiresPending),
      );
    });

    test('allows overdue_only with empty statuses or pending', () {
      expect(
        CalendarFilterValidator.validate(
          dateFrom: from,
          dateTo: to,
          filters: CalendarFilters(overdueOnly: true),
          session: tenantSession,
        ).isValid,
        isTrue,
      );
      expect(
        CalendarFilterValidator.validate(
          dateFrom: from,
          dateTo: to,
          filters: CalendarFilters(
            overdueOnly: true,
            statuses: [CalendarEventStatus.pending],
          ),
          session: tenantSession,
        ).isValid,
        isTrue,
      );
    });

    test('rejects invalid page limit', () {
      expect(
        CalendarFilterValidator.validate(
          dateFrom: from,
          dateTo: to,
          filters: CalendarFilters.empty,
          session: tenantSession,
          pageLimit: 0,
        ).codes,
        contains(CalendarFilterValidator.pageLimitInvalid),
      );
      expect(
        CalendarFilterValidator.validate(
          dateFrom: from,
          dateTo: to,
          filters: CalendarFilters.empty,
          session: tenantSession,
          pageLimit: 101,
        ).codes,
        contains(CalendarFilterValidator.pageLimitInvalid),
      );
    });

    test('assigned-only rejects agent and unassigned filters', () {
      final assignedOnly = _session(permissions: {'calendar.view_assigned'});

      final agentResult = CalendarFilterValidator.validate(
        dateFrom: from,
        dateTo: to,
        filters: CalendarFilters(assignedAgentId: 'agent-1'),
        session: assignedOnly,
      );
      expect(
        agentResult.codes,
        contains(CalendarFilterValidator.assignedOnlyAgentFilterForbidden),
      );

      final unassignedResult = CalendarFilterValidator.validate(
        dateFrom: from,
        dateTo: to,
        filters: CalendarFilters(unassignedOnly: true),
        session: assignedOnly,
      );
      expect(
        unassignedResult.codes,
        contains(CalendarFilterValidator.assignedOnlyUnassignedForbidden),
      );
    });

    test('tenant-wide calendar.view allows assigned_agent_id filter', () {
      final result = CalendarFilterValidator.validate(
        dateFrom: from,
        dateTo: to,
        filters: CalendarFilters(assignedAgentId: 'agent-1'),
        session: tenantSession,
      );
      expect(result.isValid, isTrue);
    });
  });
}
