import 'calendar_date.dart';

/// Compact month-cell count without localized formatting.
class CalendarCappedCount {
  const CalendarCappedCount({required this.value, required this.overflow});

  /// Displayed numeric value (capped at [cap] when [overflow] is true).
  final int value;
  final bool overflow;

  static const int cap = 99;

  factory CalendarCappedCount.fromRaw(int raw) {
    if (raw < 0) {
      return const CalendarCappedCount(value: 0, overflow: false);
    }
    if (raw > cap) {
      return const CalendarCappedCount(value: cap, overflow: true);
    }
    return CalendarCappedCount(value: raw, overflow: false);
  }
}

/// One cell in a week-aligned month grid.
class CalendarGridCell {
  const CalendarGridCell({required this.date, required this.isOutsideMonth});

  final DateTime date;
  final bool isOutsideMonth;
}

/// Inclusive padded range for [focusedMonth] given Material-style week start
/// (`0` = Sunday … `6` = Saturday). Flutter-independent.
({DateTime dateFrom, DateTime dateTo}) calendarPaddedMonthRange(
  DateTime focusedMonth, {
  required int firstDayOfWeekIndex,
}) {
  final month = DateTime(focusedMonth.year, focusedMonth.month);
  final monthEnd = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
  final from = _alignToWeekStart(month, firstDayOfWeekIndex);
  final to = _alignToWeekEnd(monthEnd, firstDayOfWeekIndex);
  return (dateFrom: from, dateTo: to);
}

/// Builds every day cell from [dateFrom] through [dateTo] for [focusedMonth].
List<CalendarGridCell> buildCalendarGridCells({
  required DateTime focusedMonth,
  required DateTime dateFrom,
  required DateTime dateTo,
}) {
  final month = focusedMonth.month;
  final year = focusedMonth.year;
  final cells = <CalendarGridCell>[];
  var cursor = calendarDateOnly(dateFrom);
  final end = calendarDateOnly(dateTo);
  while (!cursor.isAfter(end)) {
    cells.add(
      CalendarGridCell(
        date: cursor,
        isOutsideMonth: cursor.year != year || cursor.month != month,
      ),
    );
    cursor = addCalendarDays(cursor, 1);
  }
  return cells;
}

/// Preserves day-of-month when possible; clamps to last day of [targetMonth].
DateTime clampDayOfMonth(DateTime selected, DateTime targetMonth) {
  final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
  final day = selected.day > lastDay ? lastDay : selected.day;
  return DateTime(targetMonth.year, targetMonth.month, day);
}

DateTime focusedMonthOnly(DateTime date) => DateTime(date.year, date.month);

/// Material weekday index for [date]: Sunday=0 … Saturday=6.
int materialWeekdayIndex(DateTime date) {
  // Dart DateTime.weekday: Mon=1 … Sun=7.
  return date.weekday % 7;
}

DateTime _alignToWeekStart(DateTime date, int firstDayOfWeekIndex) {
  final normalized = firstDayOfWeekIndex % 7;
  final current = materialWeekdayIndex(date);
  final delta = (current - normalized + 7) % 7;
  return addCalendarDays(calendarDateOnly(date), -delta);
}

/// Public week-start alignment for mobile week strips and grids.
DateTime calendarAlignToWeekStart(DateTime date, int firstDayOfWeekIndex) =>
    _alignToWeekStart(date, firstDayOfWeekIndex);

/// Seven date-only days for the week containing [selectedDate].
List<DateTime> calendarWeekDaysContaining(
  DateTime selectedDate, {
  required int firstDayOfWeekIndex,
}) {
  final start = calendarAlignToWeekStart(selectedDate, firstDayOfWeekIndex);
  return [for (var i = 0; i < 7; i++) addCalendarDays(start, i)];
}

DateTime _alignToWeekEnd(DateTime date, int firstDayOfWeekIndex) {
  final normalized = firstDayOfWeekIndex % 7;
  final lastDayIndex = (normalized + 6) % 7;
  final current = materialWeekdayIndex(date);
  final delta = (lastDayIndex - current + 7) % 7;
  return addCalendarDays(calendarDateOnly(date), delta);
}
