/// Tenant-local timed window returned by calendar read/mutation RPCs.
///
/// Flutter must not convert device-local time; values are HH:mm strings in the
/// event's IANA [timezoneName].
class CalendarTimeWindow {
  const CalendarTimeWindow({
    required this.startLocal,
    required this.endLocal,
    required this.timezoneName,
  });

  final String startLocal;
  final String endLocal;
  final String timezoneName;
}
