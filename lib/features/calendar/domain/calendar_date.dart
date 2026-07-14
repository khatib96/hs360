final _calendarDateOnlyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Parses a strict `YYYY-MM-DD` calendar date with no time or offset.
///
/// Rejects invalid calendar days (e.g. `2026-02-30`). Never calls
/// [DateTime.toLocal] or [DateTime.toUtc].
DateTime parseCalendarDateOnly(String value) {
  final match = _calendarDateOnlyPattern.firstMatch(value);
  if (match == null) {
    throw FormatException('Expected YYYY-MM-DD calendar date, got: $value');
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);

  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('Invalid calendar date: $value');
  }

  return date;
}

/// Formats [date] as `YYYY-MM-DD` from year/month/day components only.
String formatCalendarDateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Clamps [date] to a date-only [DateTime] (midnight local components).
DateTime calendarDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Inclusive day count between date-only [from] and [to].
///
/// Uses UTC midnight constructed from year/month/day so DST transitions that
/// make local midnights 23h or 25h apart do not change the ordinal day count.
int inclusiveDaySpan(DateTime from, DateTime to) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays + 1;
}
