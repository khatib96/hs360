/// Meeting mode for manual internal meetings (`calendar_meeting_mode`).
enum CalendarMeetingMode {
  inPerson,
  online;

  static CalendarMeetingMode? fromRpc(String value) {
    return switch (value) {
      'in_person' => CalendarMeetingMode.inPerson,
      'online' => CalendarMeetingMode.online,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarMeetingMode.inPerson => 'in_person',
    CalendarMeetingMode.online => 'online',
  };
}
