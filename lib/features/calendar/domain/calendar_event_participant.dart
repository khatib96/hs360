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
