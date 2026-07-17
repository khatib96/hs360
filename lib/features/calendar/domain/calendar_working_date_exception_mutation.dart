import 'calendar_date.dart';
import 'calendar_settings.dart';
import 'calendar_working_date_exception.dart';

/// Business payload for create/update working-date exception RPCs.
class WorkingDateExceptionData {
  const WorkingDateExceptionData({
    required this.kind,
    required this.startDate,
    required this.endDate,
    this.titleAr,
    this.titleEn,
    this.notes,
    this.dayMode,
    this.workStart,
    this.workEnd,
  });

  final CalendarWorkingDateExceptionKind kind;
  final DateTime startDate;
  final DateTime endDate;
  final String? titleAr;
  final String? titleEn;
  final String? notes;
  final TenantWorkingDayMode? dayMode;
  final String? workStart;
  final String? workEnd;

  /// Full create payload.
  Map<String, dynamic> toCreateRpcPayload() {
    return {
      'kind': kind.rpcValue,
      'start_date': formatCalendarDateOnly(startDate),
      'end_date': formatCalendarDateOnly(endDate),
      ..._patchableFields,
    };
  }

  /// Full editable business overlay for `update_working_date_exception`.
  Map<String, dynamic> toUpdateRpcPayload() {
    return {
      'kind': kind.rpcValue,
      'start_date': formatCalendarDateOnly(startDate),
      'end_date': formatCalendarDateOnly(endDate),
      ..._patchableFields,
    };
  }

  Map<String, dynamic> get _patchableFields => {
    'title_ar': titleAr?.trim(),
    'title_en': titleEn?.trim(),
    'notes': notes?.trim(),
    'day_mode': dayMode?.toRpc(),
    'work_start': workStart,
    'work_end': workEnd,
  };
}
