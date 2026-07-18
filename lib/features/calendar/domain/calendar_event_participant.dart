/// Participant employee on a calendar event (not the assigned agent).
class CalendarEventParticipant {
  const CalendarEventParticipant({
    required this.employeeId,
    required this.nameAr,
    this.nameEn,
    required this.isActive,
    required this.hasAppAccount,
  });

  final String employeeId;
  final String nameAr;
  final String? nameEn;
  final bool isActive;
  final bool hasAppAccount;
}

/// Assignable/participant candidate from `list_calendar_participant_candidates`
/// with M8 reachability flags (candidates are always active employees).
///
/// Extends [CalendarEventParticipant] so M7A create/edit participant selection
/// continues to work without replacing the event-stored participant shape.
class CalendarParticipantCandidate extends CalendarEventParticipant {
  const CalendarParticipantCandidate({
    required super.employeeId,
    required super.nameAr,
    super.nameEn,
    required super.isActive,
    required super.hasAppAccount,
    required this.hasActiveTenantAccount,
    required this.hasCalendarAccess,
  });

  /// Employee's linked user has an active tenant account.
  final bool hasActiveTenantAccount;

  /// Employee's linked user can see calendar events (tenant-wide or assigned).
  final bool hasCalendarAccess;
}
