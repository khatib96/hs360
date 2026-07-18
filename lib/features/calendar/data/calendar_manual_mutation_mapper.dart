import '../../../core/errors/calendar_exception.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_event_participant.dart';
import '../domain/calendar_manual_mutation.dart';
import 'calendar_read_rpc_parsers.dart';

CalendarManualMutationResult mapCalendarManualMutationResult(dynamic raw) {
  final map = requireMap(raw, 'manual mutation root');
  final status = requireString(map['status'], 'manual mutation.status');

  if (status == 'confirmation_required') {
    return CalendarManualMutationConfirmationRequired(
      mapCalendarManualConflictInfo(map['conflicts'], 'manual mutation'),
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

List<CalendarParticipantCandidate> mapParticipantCandidates(dynamic raw) {
  final map = requireMap(raw, 'participant candidates root');
  return mapCalendarParticipantCandidates(
    map['rows'],
    'participant candidates.rows',
  );
}

/// Shared soft-conflict payload mapping for M7A manual and M8 schedule RPCs.
CalendarManualConflictInfo mapCalendarManualConflictInfo(
  dynamic raw,
  String detail,
) {
  final conflictsRaw = requireMap(raw, '$detail.conflicts');
  return CalendarManualConflictInfo(
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
  );
}

List<Map<String, dynamic>> _mapWarningList(dynamic value, String detail) {
  if (value == null) return const [];
  final list = requireList(value, detail);
  return list
      .map((item) => requireMap(item, '$detail[]'))
      .toList(growable: false);
}
