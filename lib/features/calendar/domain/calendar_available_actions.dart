/// Permission-derived actions for a calendar event row.
class CalendarAvailableActions {
  const CalendarAvailableActions({
    required this.canViewCustomer,
    required this.canViewContract,
    required this.canAssign,
    required this.canReschedule,
    required this.canCreateManual,
    required this.canOpenDirections,
  });

  final bool canViewCustomer;
  final bool canViewContract;
  final bool canAssign;
  final bool canReschedule;
  final bool canCreateManual;
  final bool canOpenDirections;
}
