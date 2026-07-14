/// Safe operational metadata surfaced from event source metadata.
class CalendarOperationalMetadata {
  const CalendarOperationalMetadata({this.actionKind, this.coverageMonthKey});

  final String? actionKind;
  final String? coverageMonthKey;
}
