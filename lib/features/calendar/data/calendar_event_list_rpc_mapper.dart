import '../domain/calendar_enums.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_event_list_result.dart';
import 'calendar_read_rpc_parsers.dart';

CalendarEventListResult mapCalendarEventListFromRpc(dynamic raw) {
  final map = requireMap(raw, 'calendar event list root');

  return CalendarEventListResult(
    dateFrom: parseRequiredCalendarDate(map['date_from']),
    dateTo: parseRequiredCalendarDate(map['date_to']),
    limit: requireInt(map['limit'], 'limit'),
    scope: requireEnum(map['scope'], CalendarReadScope.fromRpc, 'scope'),
    tenantLocalToday: parseOptionalCalendarDate(map['tenant_local_today']),
    filtersHash: requireString(map['filters_hash'], 'filters_hash'),
    inRange: _mapBucket(map['in_range'], 'in_range'),
    overdueOutsideRange: _mapBucket(
      map['overdue_outside_range'],
      'overdue_outside_range',
    ),
  );
}

CalendarEventBucket _mapBucket(dynamic raw, String label) {
  final map = requireMap(raw, label);
  final rowsRaw = requireList(map['rows'], '$label.rows');
  final rows = <CalendarEvent>[];
  for (final item in rowsRaw) {
    final row = requireMap(item, '$label.rows[]');
    rows.add(mapCalendarEvent(row));
  }

  return CalendarEventBucket(
    rows: rows,
    nextCursor: optionalString(map['next_cursor']),
    hasMore: requireBool(map['has_more'], '$label.has_more'),
  );
}
