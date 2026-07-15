import '../domain/calendar_date.dart';
import '../domain/calendar_month_grid.dart';
import 'calendar_state.dart';

/// Injectable clock for selectable “today”; overridden in tests.
typedef CalendarClock = DateTime Function();

CalendarClock calendarClock = DateTime.now;

CalendarState calendarInitialState(DateTime today) {
  final day = calendarDateOnly(today);
  final focused = focusedMonthOnly(day);
  final bounds = provisionalMonthBounds(focused);
  return CalendarState(
    isLoadingSummary: false,
    isLoadingAgenda: false,
    isLoadingOverdue: false,
    focusedMonth: focused,
    dateFrom: bounds.dateFrom,
    dateTo: bounds.dateTo,
    selectedDate: day,
  );
}
