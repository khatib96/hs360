import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_date.dart';

void main() {
  group('parseCalendarDateOnly', () {
    test('parses valid YYYY-MM-DD', () {
      final date = parseCalendarDateOnly('2026-07-14');
      expect(date.year, 2026);
      expect(date.month, 7);
      expect(date.day, 14);
    });

    test('rejects timestamps', () {
      expect(
        () => parseCalendarDateOnly('2026-07-14T00:00:00'),
        throwsFormatException,
      );
      expect(
        () => parseCalendarDateOnly('2026-07-14 00:00:00'),
        throwsFormatException,
      );
    });

    test('rejects offsets', () {
      expect(() => parseCalendarDateOnly('2026-07-14Z'), throwsFormatException);
      expect(
        () => parseCalendarDateOnly('2026-07-14+03:00'),
        throwsFormatException,
      );
    });

    test('rejects garbage', () {
      expect(() => parseCalendarDateOnly(''), throwsFormatException);
      expect(() => parseCalendarDateOnly('not-a-date'), throwsFormatException);
      expect(() => parseCalendarDateOnly('14-07-2026'), throwsFormatException);
      expect(() => parseCalendarDateOnly('2026/07/14'), throwsFormatException);
    });

    test('rejects normalized-invalid calendar days', () {
      expect(
        () => parseCalendarDateOnly('2026-02-30'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Invalid calendar date'),
          ),
        ),
      );
      expect(() => parseCalendarDateOnly('2026-13-01'), throwsFormatException);
      expect(() => parseCalendarDateOnly('2026-04-31'), throwsFormatException);
    });
  });

  group('formatCalendarDateOnly', () {
    test('formats year/month/day components only', () {
      expect(formatCalendarDateOnly(DateTime(2026, 7, 14)), '2026-07-14');
      expect(formatCalendarDateOnly(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('inclusiveDaySpan', () {
    test('same day = 1', () {
      expect(inclusiveDaySpan(DateTime(2026, 7, 1), DateTime(2026, 7, 1)), 1);
    });

    test('consecutive days = 2', () {
      expect(inclusiveDaySpan(DateTime(2026, 7, 1), DateTime(2026, 7, 2)), 2);
    });

    test('counts inclusive days across month', () {
      expect(inclusiveDaySpan(DateTime(2026, 7, 1), DateTime(2026, 7, 31)), 31);
      expect(inclusiveDaySpan(DateTime(2026, 7, 1), DateTime(2026, 8, 31)), 62);
    });

    test('month and year boundaries', () {
      expect(inclusiveDaySpan(DateTime(2025, 12, 31), DateTime(2026, 1, 2)), 3);
      expect(inclusiveDaySpan(DateTime(2026, 1, 31), DateTime(2026, 2, 1)), 2);
      expect(inclusiveDaySpan(DateTime(2026, 2, 28), DateTime(2026, 3, 1)), 2);
    });

    // Arithmetic uses DateTime.utc(y,m,d) so DST transitions that make local
    // midnights 23h/25h apart do not change the ordinal day count.
    test('US DST spring 2026 span is calendar days (UTC components)', () {
      // 2026-03-08 local US spring forward would be a 23h local midnight gap;
      // UTC y/m/d arithmetic still yields 3 inclusive days for Mar 7..9.
      expect(inclusiveDaySpan(DateTime(2026, 3, 7), DateTime(2026, 3, 9)), 3);
    });

    test('US DST fall 2026 span is calendar days (UTC components)', () {
      // 2026-11-01 local US fall back would be a 25h local midnight gap.
      expect(
        inclusiveDaySpan(DateTime(2026, 10, 31), DateTime(2026, 11, 2)),
        3,
      );
    });
  });
}
