import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';

void main() {
  group('CalendarFilters collision-safe identity', () {
    test(
      'delimiter collision: search forging statuses does not equal statuses',
      () {
        final forged = CalendarFilters(search: 'x&statuses=[pending]');
        final real = CalendarFilters(
          search: 'x',
          statuses: const [CalendarEventStatus.pending],
        );
        expect(forged, isNot(real));
        expect(forged.canonicalQueryKey, isNot(real.canonicalQueryKey));
      },
    );

    test('equals, commas, brackets inside search stay isolated', () {
      final a = CalendarFilters(search: 'a=b,c[d]');
      final b = CalendarFilters(search: 'a', customerId: 'b,c[d]');
      expect(a, isNot(b));
    });

    test('Arabic search distinguishes values', () {
      final a = CalendarFilters(search: 'عميل');
      final b = CalendarFilters(search: 'وكيل');
      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('identical semantic instances compare equal', () {
      final a = CalendarFilters(
        statuses: const [CalendarEventStatus.pending],
        search: '  ab  ',
        overdueOnly: true,
      );
      final b = CalendarFilters(
        statuses: const [CalendarEventStatus.pending],
        search: 'ab',
        overdueOnly: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a}, contains(b));
    });

    test('empty equivalents share empty JSON identity', () {
      expect(CalendarFilters.empty.canonicalQueryKey, '{}');
      expect(
        CalendarFilters(eventTypes: [], search: '  '),
        CalendarFilters.empty,
      );
    });

    test('canonicalQueryKey sorts payload keys for stable JSON', () {
      final filters = CalendarFilters(
        search: 'ab',
        overdueOnly: true,
        customerId: 'c1',
        statuses: const [CalendarEventStatus.pending],
      );
      final key = filters.canonicalQueryKey;
      expect(key, startsWith('{'));
      expect(key, endsWith('}'));
      // Sorted keys: customer_id, overdue_only, search, statuses.
      expect(
        key,
        '{"customer_id":"c1","overdue_only":true,"search":"ab",'
        '"statuses":["pending"]}',
      );
      expect(
        CalendarFilters(
          overdueOnly: true,
          customerId: 'c1',
          search: 'ab',
          statuses: const [CalendarEventStatus.pending],
        ).canonicalQueryKey,
        key,
      );
    });
  });
}
