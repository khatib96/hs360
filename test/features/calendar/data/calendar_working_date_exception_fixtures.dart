/// RPC JSON fixtures mirroring migration `100` response shapes.
library;

/// `build_working_date_exception_response` for a holiday/closure (day_mode
/// and work window always null).
Map<String, dynamic> validHolidayExceptionRpc({
  String id = 'aaaaaaaa-0000-0000-0000-000000000001',
  String kind = 'official_holiday',
  String startDate = '2026-08-01',
  String endDate = '2026-08-01',
  String? titleAr = 'عيد',
  String? titleEn = 'Holiday',
  String? notes,
  String status = 'active',
  int version = 1,
  String? cancelReason,
  String? cancelledAt,
  String? cancelledBy,
  String createdAt = '2026-07-01T08:00:00+00:00',
  String? createdBy = 'bbbbbbbb-0000-0000-0000-000000000001',
  String updatedAt = '2026-07-01T08:00:00+00:00',
  String? updatedBy = 'bbbbbbbb-0000-0000-0000-000000000001',
}) {
  return {
    'id': id,
    'kind': kind,
    'start_date': startDate,
    'end_date': endDate,
    'title_ar': titleAr,
    'title_en': titleEn,
    'notes': notes,
    'day_mode': null,
    'work_start': null,
    'work_end': null,
    'status': status,
    'version': version,
    'cancel_reason': cancelReason,
    'cancelled_at': cancelledAt,
    'cancelled_by': cancelledBy,
    'created_at': createdAt,
    'created_by': createdBy,
    'updated_at': updatedAt,
    'updated_by': updatedBy,
  };
}

/// `build_working_date_exception_response` for an exceptional working day
/// with a validated `working_hours` window.
Map<String, dynamic> validExceptionalWorkingDayRpc({
  String id = 'aaaaaaaa-0000-0000-0000-000000000002',
  String startDate = '2026-08-08',
  String endDate = '2026-08-08',
  String? titleAr = 'يوم عمل استثنائي',
  String? titleEn = 'Exceptional working day',
  String dayMode = 'working_hours',
  String? workStart = '09:00',
  String? workEnd = '13:00',
  String status = 'active',
  int version = 1,
}) {
  return validHolidayExceptionRpc(
    id: id,
    kind: 'exceptional_working_day',
    startDate: startDate,
    endDate: endDate,
    titleAr: titleAr,
    titleEn: titleEn,
    status: status,
    version: version,
  )..addAll({
    'day_mode': dayMode,
    'work_start': workStart,
    'work_end': workEnd,
  });
}

/// `create/update/cancel_working_date_exception` shared `{status, exception}`
/// success shape.
Map<String, dynamic> okMutationResultRpc({Map<String, dynamic>? exception}) {
  return {'status': 'ok', 'exception': exception ?? validHolidayExceptionRpc()};
}

/// `list_working_date_exceptions` result shape.
Map<String, dynamic> validExceptionListRpc({
  List<Map<String, dynamic>>? items,
  bool hasMore = false,
  String? nextCursor,
  String status = 'active',
  String? kind,
  String dateFrom = '2026-06-01',
  String dateTo = '2026-12-31',
  int limit = 50,
  String filtersHash = 'hash-wde',
}) {
  return {
    'items': items ?? [validHolidayExceptionRpc()],
    'has_more': hasMore,
    'next_cursor': nextCursor,
    'filters_applied': {
      'status': status,
      'kind': kind,
      'date_from': dateFrom,
      'date_to': dateTo,
      'limit': limit,
    },
    'filters_hash': filtersHash,
  };
}

/// `safe_date_exception_json`: `{kind, title_ar, title_en}`.
Map<String, dynamic> validDateExceptionRefRpc({
  String kind = 'official_holiday',
  String? titleAr = 'عيد',
  String? titleEn = 'Holiday',
}) {
  return {'kind': kind, 'title_ar': titleAr, 'title_en': titleEn};
}
