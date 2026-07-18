/// Employee candidate row from `list_calendar_route_employees`.
///
/// Used by the tenant-wide Route View employee picker.
class CalendarRouteEmployee {
  const CalendarRouteEmployee({
    required this.employeeId,
    required this.nameAr,
    this.nameEn,
    required this.isActive,
  });

  final String employeeId;
  final String nameAr;
  final String? nameEn;
  final bool isActive;
}

/// Result of `list_calendar_route_employees`.
class CalendarRouteEmployeeListResult {
  const CalendarRouteEmployeeListResult({
    required this.employees,
    required this.hasMore,
  });

  final List<CalendarRouteEmployee> employees;
  final bool hasMore;
}
