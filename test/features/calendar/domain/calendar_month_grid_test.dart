import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_month_grid.dart';

void main() {
  group('calendarPaddedMonthRange', () {
    test('pads July 2026 for Sunday week start', () {
      final range = calendarPaddedMonthRange(
        DateTime(2026, 7),
        firstDayOfWeekIndex: 0,
      );
      // July 1 2026 is Wednesday → pad back to June 28.
      expect(range.dateFrom, DateTime(2026, 6, 28));
      // July 31 2026 is Friday → pad forward to Aug 1.
      expect(range.dateTo, DateTime(2026, 8, 1));
    });

    test('pads July 2026 for Saturday week start', () {
      final range = calendarPaddedMonthRange(
        DateTime(2026, 7),
        firstDayOfWeekIndex: 6,
      );
      // Saturday start: June 27 … July 31 (Friday is last weekday of week).
      expect(range.dateFrom, DateTime(2026, 6, 27));
      expect(range.dateTo, DateTime(2026, 7, 31));
    });
  });

  group('buildCalendarGridCells', () {
    test('marks outside-month leading and trailing', () {
      final cells = buildCalendarGridCells(
        focusedMonth: DateTime(2026, 7),
        dateFrom: DateTime(2026, 6, 28),
        dateTo: DateTime(2026, 8, 1),
      );
      expect(cells.first.isOutsideMonth, isTrue);
      expect(
        cells.firstWhere((c) => c.date == DateTime(2026, 7, 1)).isOutsideMonth,
        isFalse,
      );
      expect(cells.last.isOutsideMonth, isTrue);
    });
  });

  group('clampDayOfMonth', () {
    test('clamps Jan 31 into February', () {
      expect(
        clampDayOfMonth(DateTime(2026, 1, 31), DateTime(2026, 2)),
        DateTime(2026, 2, 28),
      );
    });

    test('preserves mid-month day', () {
      expect(
        clampDayOfMonth(DateTime(2026, 3, 15), DateTime(2026, 2)),
        DateTime(2026, 2, 15),
      );
    });
  });

  group('CalendarCappedCount', () {
    test('caps at 99 with overflow', () {
      final capped = CalendarCappedCount.fromRaw(150);
      expect(capped.value, 99);
      expect(capped.overflow, isTrue);
    });

    test('keeps small counts', () {
      final capped = CalendarCappedCount.fromRaw(12);
      expect(capped.value, 12);
      expect(capped.overflow, isFalse);
    });
  });

  group('week padding DST and week-start extremes', () {
    test('March 2026 Sunday start pads without Duration gaps', () {
      final range = calendarPaddedMonthRange(
        DateTime(2026, 3),
        firstDayOfWeekIndex: 0,
      );
      // Mar 1 2026 is Sunday → from Mar 1; Mar 31 Tuesday → pad to Apr 4.
      expect(range.dateFrom, DateTime(2026, 3, 1));
      expect(range.dateTo, DateTime(2026, 4, 4));
      final cells = buildCalendarGridCells(
        focusedMonth: DateTime(2026, 3),
        dateFrom: range.dateFrom,
        dateTo: range.dateTo,
      );
      expect(cells.length % 7, 0);
      expect(cells[7].date, DateTime(2026, 3, 8)); // DST spring week
    });

    test('February leap year Saturday week start', () {
      final range = calendarPaddedMonthRange(
        DateTime(2024, 2),
        firstDayOfWeekIndex: 6,
      );
      expect(range.dateFrom.weekday % 7, 6); // Saturday material index
      final cells = buildCalendarGridCells(
        focusedMonth: DateTime(2024, 2),
        dateFrom: range.dateFrom,
        dateTo: range.dateTo,
      );
      expect(
        cells.any((c) => c.date == DateTime(2024, 2, 29) && !c.isOutsideMonth),
        isTrue,
      );
    });

    test('year-end December pads into next year', () {
      final range = calendarPaddedMonthRange(
        DateTime(2026, 12),
        firstDayOfWeekIndex: 0,
      );
      expect(range.dateTo.year, 2027);
      expect(
        range.dateFrom.isBefore(DateTime(2026, 12, 1)) ||
            range.dateFrom == DateTime(2026, 12, 1),
        isTrue,
      );
    });
  });
}
