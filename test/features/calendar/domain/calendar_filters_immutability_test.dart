import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';
import 'package:hs360/features/calendar/presentation/calendar_state.dart';

import '../fake_calendar_repository.dart';

void main() {
  group('CalendarFilters immutability', () {
    test('mutating source list after construction does not change filters', () {
      final types = [CalendarEventType.refillDue];
      final filters = CalendarFilters(eventTypes: types);
      types.add(CalendarEventType.billingDue);

      expect(filters.eventTypes, [CalendarEventType.refillDue]);
    });

    test('mutating filters.eventTypes throws UnsupportedError', () {
      final filters = CalendarFilters(
        eventTypes: [CalendarEventType.refillDue],
      );
      expect(
        () => filters.eventTypes!.add(CalendarEventType.billingDue),
        throwsUnsupportedError,
      );
    });

    test('toCanonicalPayload map is unmodifiable', () {
      final filters = CalendarFilters(
        eventTypes: [CalendarEventType.refillDue],
        unassignedOnly: true,
      );
      final payload = filters.toCanonicalPayload();
      expect(() => payload['extra'] = true, throwsUnsupportedError);
      expect(
        () => (payload['event_types'] as List).add('billing_due'),
        throwsUnsupportedError,
      );
    });
  });

  group('CalendarState immutability', () {
    test('agendaEvents list is unmodifiable', () {
      final state = CalendarState(
        focusedMonth: DateTime(2026, 7),
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 31),
        selectedDate: DateTime(2026, 7, 14),
        agendaEvents: [sampleCalendarEvent()],
      );

      expect(
        () => state.agendaEvents.add(sampleCalendarEvent(id: 'other')),
        throwsUnsupportedError,
      );
    });

    test('copyWith freezes newly supplied lists', () {
      final mutable = [sampleCalendarEvent()];
      final state = CalendarState(
        focusedMonth: DateTime(2026, 7),
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 31),
        selectedDate: DateTime(2026, 7, 14),
      ).copyWith(agendaEvents: mutable);

      mutable.add(sampleCalendarEvent(id: 'extra'));
      expect(state.agendaEvents, hasLength(1));
      expect(
        () => state.agendaEvents.add(sampleCalendarEvent(id: 'nope')),
        throwsUnsupportedError,
      );
    });
  });
}
