import '../../../core/errors/calendar_exception.dart';
import '../domain/calendar_schedule_mutation.dart';
import 'calendar_manual_mutation_mapper.dart';
import 'calendar_read_rpc_parsers.dart';

/// Maps `assign_calendar_event` / `reschedule_calendar_event` responses.
///
/// Success shape: `{status: "ok", changed: bool, event: {...}}`.
/// Reschedule soft conflicts reuse the M7A `confirmation_required` shape.
CalendarScheduleMutationResult mapCalendarScheduleMutationResult(dynamic raw) {
  final map = requireMap(raw, 'schedule mutation root');
  final status = requireString(map['status'], 'schedule mutation.status');

  if (status == 'confirmation_required') {
    return CalendarScheduleMutationConfirmationRequired(
      mapCalendarManualConflictInfo(map['conflicts'], 'schedule mutation'),
    );
  }

  if (status != 'ok') {
    throw CalendarException(
      code: CalendarException.malformedResponse,
      technicalDetail: 'unexpected schedule mutation status "$status"',
    );
  }

  final changed = requireBool(map['changed'], 'schedule mutation.changed');
  final eventRaw = requireMap(map['event'], 'schedule mutation.event');
  return CalendarScheduleMutationOk(
    mapCalendarEvent(eventRaw),
    changed: changed,
  );
}
