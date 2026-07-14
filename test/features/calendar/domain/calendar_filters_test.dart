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
}
