import 'calendar_date.dart';
import 'calendar_event.dart';
import 'calendar_manual_mutation.dart';

/// Business payload for `assign_calendar_event` (M8).
///
/// A null [assignedAgentId] means "unassign"; the RPC requires the
/// `assigned_agent_id` key to always be present.
class CalendarAssignmentData {
  const CalendarAssignmentData({this.assignedAgentId});

  final String? assignedAgentId;

  Map<String, dynamic> toRpcPayload() => {'assigned_agent_id': assignedAgentId};
}

/// Business payload for `reschedule_calendar_event` (M8).
///
/// Only `scheduled_date` and `reason` participate in the server idempotency
/// hash; acknowledgements ride along unhashed exactly like M7A soft-conflict
/// retries.
class CalendarRescheduleData {
  const CalendarRescheduleData({
    required this.scheduledDate,
    required this.reason,
    this.acknowledgements = const CalendarManualAcknowledgements(),
  });

  final DateTime scheduledDate;
  final String reason;
  final CalendarManualAcknowledgements acknowledgements;

  Map<String, dynamic> toRpcPayload() {
    final map = <String, dynamic>{
      'scheduled_date': formatCalendarDateOnly(scheduledDate),
      'reason': reason.trim(),
    };
    final acks = acknowledgements.toRpcPayload();
    if (acks.isNotEmpty) map['acknowledgements'] = acks;
    return map;
  }

  CalendarRescheduleData copyWith({
    CalendarManualAcknowledgements? acknowledgements,
  }) {
    return CalendarRescheduleData(
      scheduledDate: scheduledDate,
      reason: reason,
      acknowledgements: acknowledgements ?? this.acknowledgements,
    );
  }
}

/// Result of assign/reschedule schedule mutation RPCs.
sealed class CalendarScheduleMutationResult {
  const CalendarScheduleMutationResult();
}

class CalendarScheduleMutationOk extends CalendarScheduleMutationResult {
  const CalendarScheduleMutationOk(this.event, {required this.changed});

  final CalendarEvent event;

  /// False when the request was a ledgered no-op (same assignee/date).
  final bool changed;
}

/// Reuses the M7A conflict payload: reschedule soft conflicts share the same
/// schedule/overlap warning shape and confirm dialog.
class CalendarScheduleMutationConfirmationRequired
    extends CalendarScheduleMutationResult {
  const CalendarScheduleMutationConfirmationRequired(this.conflicts);

  final CalendarManualConflictInfo conflicts;
}
