import '../../../core/errors/calendar_exception.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_event_participant.dart';
import '../domain/calendar_manual_mutation.dart';
import 'calendar_read_rpc_parsers.dart';

CalendarManualMutationResult mapCalendarManualMutationResult(dynamic raw) {
  final map = requireMap(raw, 'manual mutation root');
  final status = requireString(map['status'], 'manual mutation.status');

  if (status == 'confirmation_required') {
    final conflictsRaw = requireMap(
      map['conflicts'],
      'manual mutation.conflicts',
    );
    return CalendarManualMutationConfirmationRequired(
      CalendarManualConflictInfo(
        scheduleWarnings: _mapWarningList(
          conflictsRaw['schedule_warnings'],
          'conflicts.schedule_warnings',
        ),
        overlapWarnings: _mapWarningList(
          conflictsRaw['overlap_warnings'],
          'conflicts.overlap_warnings',
        ),
        overlapTotalCount: requireInt(
          conflictsRaw['overlap_total_count'],
          'conflicts.overlap_total_count',
        ),
      ),
    );
  }

  if (status != 'ok') {
    throw CalendarException(
      code: CalendarException.malformedResponse,
      technicalDetail: 'unexpected mutation status "$status"',
    );
  }

  final eventRaw = requireMap(map['event'], 'manual mutation.event');
  return CalendarManualMutationOk(mapCalendarEvent(eventRaw));
}

CalendarEvent mapCalendarManualOkEvent(dynamic raw) {
  final result = mapCalendarManualMutationResult(raw);
  if (result is! CalendarManualMutationOk) {
    throw const CalendarException(
      code: CalendarException.malformedResponse,
      technicalDetail: 'expected ok mutation status',
    );
  }
  return result.event;
}

List<CalendarEventParticipant> mapParticipantCandidates(dynamic raw) {
  final map = requireMap(raw, 'participant candidates root');
  return mapCalendarParticipants(map['rows'], 'participant candidates.rows');
}

List<Map<String, dynamic>> _mapWarningList(dynamic value, String detail) {
  if (value == null) return const [];
  final list = requireList(value, detail);
  return list
      .map((item) => requireMap(item, '$detail[]'))
      .toList(growable: false);
}
