/// Permission-derived actions for a calendar event row.
class CalendarAvailableActions {
  const CalendarAvailableActions({
    required this.canViewCustomer,
    required this.canViewContract,
    required this.canAssign,
    required this.canReschedule,
    required this.canCreateManual,
    required this.canOpenDirections,
    required this.canEditManual,
    required this.canCancelManual,
    required this.canMarkManualDone,
    required this.canOpenMeetingLink,
  });

  final bool canViewCustomer;
  final bool canViewContract;
  final bool canAssign;
  final bool canReschedule;
  final bool canCreateManual;
  final bool canOpenDirections;
  final bool canEditManual;
  final bool canCancelManual;
  final bool canMarkManualDone;
  final bool canOpenMeetingLink;
}
