import '../domain/calendar_settings.dart';
import '../domain/calendar_working_date_exception.dart';
import 'calendar_read_rpc_primitives.dart';

const _dateExceptionRefKeys = {'kind', 'title_ar', 'title_en'};

/// Maps `safe_date_exception_json`: `{kind, title_ar, title_en}` or `null`.
///
/// Rejects any unexpected key (e.g. `id`, `notes`) so a future server leak of
/// a non-safe field is treated as malformed rather than silently displayed.
CalendarDateExceptionRef? mapCalendarDateExceptionRef(dynamic value) {
  if (value == null) return null;
  final map = requireMap(value, 'date_exception');
  for (final key in map.keys) {
    if (!_dateExceptionRefKeys.contains(key)) {
      return malformedCalendarResponse(
        'date_exception: unexpected key "$key" in safe projection',
      );
    }
  }
  return CalendarDateExceptionRef(
    kind: requireEnum(
      map['kind'],
      CalendarWorkingDateExceptionKind.fromRpc,
      'date_exception.kind',
    ),
    titleAr: optionalString(map['title_ar']),
    titleEn: optionalString(map['title_en']),
  );
}

/// Parses `day_mode` restricted to the values a working-date exception may
/// carry (`working_hours` | `24_hours` | absent). `day_off` and the
/// unreviewed `null`-mode meaning used by [TenantWorkingDayMode.fromRpc] do
/// not apply to exception rows and are rejected as malformed.
TenantWorkingDayMode? _parseExceptionDayMode(dynamic value) {
  if (value == null) return null;
  if (value is! String) {
    return malformedCalendarResponse(
      'working_date_exception.day_mode: expected string or null, '
      'got ${value.runtimeType}',
    );
  }
  return switch (value) {
    'working_hours' => TenantWorkingDayMode.workingHours,
    '24_hours' => TenantWorkingDayMode.hours24,
    _ => malformedCalendarResponse(
      'working_date_exception.day_mode: unexpected value "$value"',
    ),
  };
}

void _assertMatrixConsistency({
  required CalendarWorkingDateExceptionKind kind,
  required TenantWorkingDayMode? dayMode,
  required String? workStart,
  required String? workEnd,
}) {
  if (!kind.allowsWorkingHoursOverride) {
    if (dayMode != null || workStart != null || workEnd != null) {
      malformedCalendarResponse(
        'working_date_exception: ${kind.rpcValue} cannot carry day_mode/work '
        'window fields',
      );
    }
    return;
  }

  switch (dayMode) {
    case null:
      malformedCalendarResponse(
        'working_date_exception: exceptional_working_day requires day_mode',
      );
    case TenantWorkingDayMode.hours24:
      if (workStart != null || workEnd != null) {
        malformedCalendarResponse(
          'working_date_exception: 24_hours cannot include work window',
        );
      }
    case TenantWorkingDayMode.workingHours:
      if (workStart == null || workEnd == null) {
        malformedCalendarResponse(
          'working_date_exception: working_hours requires work_start and '
          'work_end',
        );
      }
    case TenantWorkingDayMode.dayOff:
    case TenantWorkingDayMode.unreviewed:
      malformedCalendarResponse(
        'working_date_exception: unexpected day_mode "$dayMode" for '
        'exceptional_working_day',
      );
  }
}

/// Maps a full `tenant_working_date_exceptions` DTO
/// (`build_working_date_exception_response`).
WorkingDateException mapWorkingDateException(Map<String, dynamic> raw) {
  final kind = requireEnum(
    raw['kind'],
    CalendarWorkingDateExceptionKind.fromRpc,
    'working_date_exception.kind',
  );
  final dayMode = _parseExceptionDayMode(raw['day_mode']);
  final workStart = optionalString(raw['work_start']);
  final workEnd = optionalString(raw['work_end']);

  _assertMatrixConsistency(
    kind: kind,
    dayMode: dayMode,
    workStart: workStart,
    workEnd: workEnd,
  );

  final startDate = parseRequiredCalendarDate(raw['start_date']);
  final endDate = parseRequiredCalendarDate(raw['end_date']);
  if (endDate.isBefore(startDate)) {
    return malformedCalendarResponse(
      'working_date_exception: end_date before start_date',
    );
  }

  return WorkingDateException(
    id: requireString(raw['id'], 'working_date_exception.id'),
    kind: kind,
    startDate: startDate,
    endDate: endDate,
    titleAr: optionalString(raw['title_ar']),
    titleEn: optionalString(raw['title_en']),
    notes: optionalString(raw['notes']),
    dayMode: dayMode,
    workStart: workStart,
    workEnd: workEnd,
    status: requireEnum(
      raw['status'],
      CalendarWorkingDateExceptionStatus.fromRpc,
      'working_date_exception.status',
    ),
    version: requireInt(raw['version'], 'working_date_exception.version'),
    cancelReason: optionalString(raw['cancel_reason']),
    cancelledAt: parseOptionalDateTime(
      raw['cancelled_at'],
      'working_date_exception.cancelled_at',
    ),
    cancelledBy: optionalString(raw['cancelled_by']),
    createdAt: requireDateTime(
      raw['created_at'],
      'working_date_exception.created_at',
    ),
    createdBy: optionalString(raw['created_by']),
    updatedAt: requireDateTime(
      raw['updated_at'],
      'working_date_exception.updated_at',
    ),
    updatedBy: optionalString(raw['updated_by']),
  );
}

/// Maps `get_working_date_exception`, which returns the DTO directly
/// (no `{status, exception}` wrapper).
WorkingDateException mapGetWorkingDateExceptionResult(dynamic raw) {
  return mapWorkingDateException(requireMap(raw, 'get_working_date_exception'));
}

/// Maps the shared `{status: 'ok', exception: {...}}` shape returned by
/// create/update/cancel (and their idempotent replay results).
WorkingDateException mapWorkingDateExceptionMutationResult(
  dynamic raw,
  String opDetail,
) {
  final map = requireMap(raw, opDetail);
  final status = requireString(map['status'], '$opDetail.status');
  if (status != 'ok') {
    return malformedCalendarResponse(
      '$opDetail.status: unexpected value "$status"',
    );
  }
  return mapWorkingDateException(
    requireMap(map['exception'], '$opDetail.exception'),
  );
}

/// Maps `list_working_date_exceptions`.
WorkingDateExceptionListResult mapWorkingDateExceptionListFromRpc(dynamic raw) {
  final map = requireMap(raw, 'list_working_date_exceptions');

  final itemsRaw = requireList(
    map['items'],
    'list_working_date_exceptions.items',
  );
  final items = itemsRaw
      .map(
        (item) => mapWorkingDateException(
          requireMap(item, 'list_working_date_exceptions.items[]'),
        ),
      )
      .toList();

  final filtersAppliedRaw = requireMap(
    map['filters_applied'],
    'list_working_date_exceptions.filters_applied',
  );

  return WorkingDateExceptionListResult(
    items: items,
    hasMore: requireBool(
      map['has_more'],
      'list_working_date_exceptions.has_more',
    ),
    nextCursor: optionalString(map['next_cursor']),
    filtersApplied: WorkingDateExceptionFiltersApplied(
      status: requireEnum(
        filtersAppliedRaw['status'],
        CalendarWorkingDateExceptionStatusFilter.fromRpc,
        'filters_applied.status',
      ),
      kind: optionalEnum(
        filtersAppliedRaw['kind'],
        CalendarWorkingDateExceptionKind.fromRpc,
        'filters_applied.kind',
      ),
      dateFrom: parseRequiredCalendarDate(filtersAppliedRaw['date_from']),
      dateTo: parseRequiredCalendarDate(filtersAppliedRaw['date_to']),
      limit: requireInt(filtersAppliedRaw['limit'], 'filters_applied.limit'),
    ),
    filtersHash: requireString(
      map['filters_hash'],
      'list_working_date_exceptions.filters_hash',
    ),
  );
}
