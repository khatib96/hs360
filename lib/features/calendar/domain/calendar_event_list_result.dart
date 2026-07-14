import 'calendar_enums.dart';
import 'calendar_event.dart';

/// Paginated event bucket (`in_range` or `overdue_outside_range`).
class CalendarEventBucket {
  CalendarEventBucket({
    required List<CalendarEvent> rows,
    this.nextCursor,
    required this.hasMore,
  }) : rows = List.unmodifiable(List<CalendarEvent>.from(rows));

  final List<CalendarEvent> rows;

  /// Opaque cursor string for the next page; never decoded by UI.
  final String? nextCursor;
  final bool hasMore;
}

/// Result of `list_calendar_events`.
class CalendarEventListResult {
  const CalendarEventListResult({
    required this.dateFrom,
    required this.dateTo,
    required this.limit,
    required this.scope,
    this.tenantLocalToday,
    required this.filtersHash,
    required this.inRange,
    required this.overdueOutsideRange,
  });

  final DateTime dateFrom;
  final DateTime dateTo;
  final int limit;
  final CalendarReadScope scope;
  final DateTime? tenantLocalToday;
  final String filtersHash;
  final CalendarEventBucket inRange;
  final CalendarEventBucket overdueOutsideRange;
}
