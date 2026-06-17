/// Inclusive date filter for finance list queries.
class DateRange {
  const DateRange({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  bool get isEmpty => from == null && to == null;

  DateRange copyWith({
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return DateRange(
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }
}

String? dateRangeToIsoDate(DateTime? date) {
  if (date == null) return null;
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
