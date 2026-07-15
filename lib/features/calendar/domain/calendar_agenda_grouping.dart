import 'calendar_event.dart';

/// Groups agenda events into Timed appointments vs Day tasks for display only.
///
/// Does **not** re-sort within groups; preserves server page order.
class CalendarAgendaGroups {
  const CalendarAgendaGroups({
    required this.timedAppointments,
    required this.dayTasks,
  });

  final List<CalendarEvent> timedAppointments;
  final List<CalendarEvent> dayTasks;

  bool get isEmpty => timedAppointments.isEmpty && dayTasks.isEmpty;
}

CalendarAgendaGroups groupCalendarAgendaEvents(List<CalendarEvent> events) {
  final timed = <CalendarEvent>[];
  final dayTasks = <CalendarEvent>[];
  for (final event in events) {
    if (event.isTimed) {
      timed.add(event);
    } else {
      dayTasks.add(event);
    }
  }
  return CalendarAgendaGroups(timedAppointments: timed, dayTasks: dayTasks);
}
