import '../domain/calendar_available_actions.dart';
import '../domain/calendar_event_participant.dart';
import '../domain/calendar_time_window.dart';
import 'calendar_read_rpc_primitives.dart';

CalendarAvailableActions mapCalendarAvailableActions(Map<String, dynamic> raw) {
  return CalendarAvailableActions(
    canViewCustomer: requireBool(
      raw['can_view_customer'],
      'available_actions.can_view_customer',
    ),
    canViewContract: requireBool(
      raw['can_view_contract'],
      'available_actions.can_view_contract',
    ),
    canAssign: requireBool(raw['can_assign'], 'available_actions.can_assign'),
    canReschedule: requireBool(
      raw['can_reschedule'],
      'available_actions.can_reschedule',
    ),
    canCreateManual: requireBool(
      raw['can_create_manual'],
      'available_actions.can_create_manual',
    ),
    canOpenDirections: requireBool(
      raw['can_open_directions'],
      'available_actions.can_open_directions',
    ),
    canEditManual: requireBool(
      raw['can_edit_manual'],
      'available_actions.can_edit_manual',
    ),
    canCancelManual: requireBool(
      raw['can_cancel_manual'],
      'available_actions.can_cancel_manual',
    ),
    canMarkManualDone: requireBool(
      raw['can_mark_manual_done'],
      'available_actions.can_mark_manual_done',
    ),
    canOpenMeetingLink: requireBool(
      raw['can_open_meeting_link'],
      'available_actions.can_open_meeting_link',
    ),
  );
}

/// Maps nullable `time_window`. Key must be present on the event object.
CalendarTimeWindow? mapCalendarTimeWindow(dynamic value, String detail) {
  if (value == null) return null;
  final map = requireMap(value, detail);
  return CalendarTimeWindow(
    startLocal: requireString(map['start_local'], '$detail.start_local'),
    endLocal: requireString(map['end_local'], '$detail.end_local'),
    timezoneName: requireString(map['timezone_name'], '$detail.timezone_name'),
  );
}

List<CalendarEventParticipant> mapCalendarParticipants(
  dynamic value,
  String detail,
) {
  final list = requireList(value, detail);
  return list.map((item) {
    final map = requireMap(item, '$detail[]');
    return CalendarEventParticipant(
      employeeId: requireString(map['employee_id'], '$detail.employee_id'),
      nameAr: requireString(map['name_ar'], '$detail.name_ar'),
      nameEn: optionalString(map['name_en']),
      isActive: requireBool(map['is_active'], '$detail.is_active'),
      hasAppAccount: requireBool(
        map['has_app_account'],
        '$detail.has_app_account',
      ),
    );
  }).toList();
}

/// Candidates carry the M8 reachability flags on top of the participant shape.
List<CalendarParticipantCandidate> mapCalendarParticipantCandidates(
  dynamic value,
  String detail,
) {
  final list = requireList(value, detail);
  // Frozen at the data boundary: lookup state and dialogs must never mutate
  // the candidate collection in place.
  return List.unmodifiable(
    list.map((item) {
      final map = requireMap(item, '$detail[]');
      return CalendarParticipantCandidate(
        employeeId: requireString(map['employee_id'], '$detail.employee_id'),
        nameAr: requireString(map['name_ar'], '$detail.name_ar'),
        nameEn: optionalString(map['name_en']),
        isActive: requireBool(map['is_active'], '$detail.is_active'),
        hasAppAccount: requireBool(
          map['has_app_account'],
          '$detail.has_app_account',
        ),
        hasActiveTenantAccount: requireBool(
          map['has_active_tenant_account'],
          '$detail.has_active_tenant_account',
        ),
        hasCalendarAccess: requireBool(
          map['has_calendar_access'],
          '$detail.has_calendar_access',
        ),
      );
    }),
  );
}
