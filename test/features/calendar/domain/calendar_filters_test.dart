import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';

void main() {
  group('CalendarFilters.toCanonicalPayload', () {
    test('omits null, false, and empty values', () {
      final filters = CalendarFilters(
        eventTypes: [],
        statuses: [],
        assignedAgentId: '  ',
        unassignedOnly: false,
        customerId: '',
        workingDayConflict: false,
        overdueOnly: false,
        search: '  ',
      );

      expect(filters.toCanonicalPayload(), isEmpty);
    });

    test('includes true booleans and non-empty enums', () {
      final filters = CalendarFilters(
        eventTypes: const [CalendarEventType.refillDue],
        statuses: const [CalendarEventStatus.pending],
        assignedAgentId: 'agent-1',
        unassignedOnly: true,
        customerId: 'cust-1',
        contractId: 'contract-1',
        serviceLocationId: 'loc-1',
        sourceKind: CalendarEventSourceKind.manual,
        workingDayConflict: true,
        overdueOnly: true,
        search: '  ab  ',
      );

      expect(filters.toCanonicalPayload(), {
        'event_types': ['refill_due'],
        'statuses': ['pending'],
        'assigned_agent_id': 'agent-1',
        'unassigned_only': true,
        'customer_id': 'cust-1',
        'contract_id': 'contract-1',
        'service_location_id': 'loc-1',
        'source_kind': 'manual',
        'working_day_conflict': true,
        'overdue_only': true,
        'search': 'ab',
      });
    });
  });

  group('CalendarFilters.withoutExactIdFilters', () {
    test(
      'clears agent/customer/contract/location ids and preserves facets',
      () {
        final filters = CalendarFilters(
          eventTypes: const [CalendarEventType.refillDue],
          statuses: const [CalendarEventStatus.pending],
          assignedAgentId: 'agent-1',
          unassignedOnly: true,
          customerId: 'cust-1',
          contractId: 'contract-1',
          serviceLocationId: 'loc-1',
          sourceKind: CalendarEventSourceKind.manual,
          workingDayConflict: true,
          overdueOnly: true,
          search: 'refill',
        );

        final cleaned = filters.withoutExactIdFilters();
        expect(cleaned.assignedAgentId, isNull);
        expect(cleaned.customerId, isNull);
        expect(cleaned.contractId, isNull);
        expect(cleaned.serviceLocationId, isNull);
        expect(cleaned.eventTypes, [CalendarEventType.refillDue]);
        expect(cleaned.statuses, [CalendarEventStatus.pending]);
        expect(cleaned.unassignedOnly, isTrue);
        expect(cleaned.sourceKind, CalendarEventSourceKind.manual);
        expect(cleaned.workingDayConflict, isTrue);
        expect(cleaned.overdueOnly, isTrue);
        expect(cleaned.search, 'refill');
      },
    );

    test('returns same instance when no exact ids present', () {
      final filters = CalendarFilters(overdueOnly: true, search: 'ab');
      expect(identical(filters.withoutExactIdFilters(), filters), isTrue);
    });
  });

  group('CalendarFilters.activePopoverGroupCount', () {
    test('counts popover facet groups and ignores search/exact ids', () {
      expect(CalendarFilters.empty.activePopoverGroupCount, 0);
      expect(
        CalendarFilters(
          search: 'refill',
          customerId: 'c1',
        ).activePopoverGroupCount,
        0,
      );
      expect(
        CalendarFilters(
          eventTypes: const [CalendarEventType.refillDue],
          statuses: const [CalendarEventStatus.pending],
          sourceKind: CalendarEventSourceKind.manual,
          overdueOnly: true,
          workingDayConflict: true,
          unassignedOnly: true,
          search: 'xx',
          customerId: 'c1',
        ).activePopoverGroupCount,
        6,
      );
    });

    test('popoverFacetFilters drops search and exact ids', () {
      final facets = CalendarFilters(
        eventTypes: const [CalendarEventType.refillDue],
        overdueOnly: true,
        search: 'ab',
        customerId: 'c1',
        assignedAgentId: 'a1',
      ).popoverFacetFilters;

      expect(facets.search, isNull);
      expect(facets.customerId, isNull);
      expect(facets.assignedAgentId, isNull);
      expect(facets.eventTypes, [CalendarEventType.refillDue]);
      expect(facets.overdueOnly, isTrue);
    });
  });
}
