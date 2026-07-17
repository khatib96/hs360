import 'calendar_settings.dart';

export 'calendar_working_date_exception_mutation.dart';

/// Working-date exception kind (`tenant_working_date_exception_kind`).
enum CalendarWorkingDateExceptionKind {
  officialHoliday,
  companyClosure,
  exceptionalWorkingDay;

  static CalendarWorkingDateExceptionKind? fromRpc(String value) {
    return switch (value) {
      'official_holiday' => CalendarWorkingDateExceptionKind.officialHoliday,
      'company_closure' => CalendarWorkingDateExceptionKind.companyClosure,
      'exceptional_working_day' =>
        CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarWorkingDateExceptionKind.officialHoliday => 'official_holiday',
    CalendarWorkingDateExceptionKind.companyClosure => 'company_closure',
    CalendarWorkingDateExceptionKind.exceptionalWorkingDay =>
      'exceptional_working_day',
  };

  /// Only an exceptional working day may carry `day_mode`/work window
  /// fields; a holiday or closure always resolves to a plain day off.
  bool get allowsWorkingHoursOverride =>
      this == CalendarWorkingDateExceptionKind.exceptionalWorkingDay;
}

/// Working-date exception lifecycle status
/// (`tenant_working_date_exception_status`).
enum CalendarWorkingDateExceptionStatus {
  active,
  cancelled;

  static CalendarWorkingDateExceptionStatus? fromRpc(String value) {
    return switch (value) {
      'active' => CalendarWorkingDateExceptionStatus.active,
      'cancelled' => CalendarWorkingDateExceptionStatus.cancelled,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarWorkingDateExceptionStatus.active => 'active',
    CalendarWorkingDateExceptionStatus.cancelled => 'cancelled',
  };
}

/// `list_working_date_exceptions` status filter. `all` is filter-only and is
/// never a persisted row status.
enum CalendarWorkingDateExceptionStatusFilter {
  active,
  cancelled,
  all;

  static CalendarWorkingDateExceptionStatusFilter? fromRpc(String value) {
    return switch (value) {
      'active' => CalendarWorkingDateExceptionStatusFilter.active,
      'cancelled' => CalendarWorkingDateExceptionStatusFilter.cancelled,
      'all' => CalendarWorkingDateExceptionStatusFilter.all,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarWorkingDateExceptionStatusFilter.active => 'active',
    CalendarWorkingDateExceptionStatusFilter.cancelled => 'cancelled',
    CalendarWorkingDateExceptionStatusFilter.all => 'all',
  };
}

/// Resolves a display title, preferring [locale] and falling back to the
/// other language when the preferred one is blank. Never returns null since
/// the server guarantees at least one non-empty title (`chk_twde_title_present`).
String resolveWorkingDateExceptionTitle({
  required String locale,
  String? titleAr,
  String? titleEn,
}) {
  final ar = titleAr?.trim();
  final en = titleEn?.trim();
  final preferAr = locale.toLowerCase().startsWith('ar');
  if (preferAr) {
    if (ar != null && ar.isNotEmpty) return ar;
    if (en != null && en.isNotEmpty) return en;
  } else {
    if (en != null && en.isNotEmpty) return en;
    if (ar != null && ar.isNotEmpty) return ar;
  }
  return '';
}

/// Minimal safe projection embedded in `working_day`/schedule-warning
/// payloads (`safe_date_exception_json`): kind + bilingual title only. Never
/// carries `id`, `notes`, or any audit/lifecycle field, so it is safe to show
/// without `settings.calendar.view`.
class CalendarDateExceptionRef {
  const CalendarDateExceptionRef({
    required this.kind,
    this.titleAr,
    this.titleEn,
  });

  final CalendarWorkingDateExceptionKind kind;
  final String? titleAr;
  final String? titleEn;

  String titleFallback(String locale) => resolveWorkingDateExceptionTitle(
    locale: locale,
    titleAr: titleAr,
    titleEn: titleEn,
  );
}

/// Full working-date exception row returned by get/create/update/cancel and
/// list item RPCs (`build_working_date_exception_response`).
///
/// `tenant_id` is intentionally absent: the server-side DTO builder never
/// includes it (tenant identity is derived server-side and never trusted
/// from the client), so it is not modeled here.
class WorkingDateException {
  const WorkingDateException({
    required this.id,
    required this.kind,
    required this.startDate,
    required this.endDate,
    this.titleAr,
    this.titleEn,
    this.notes,
    this.dayMode,
    this.workStart,
    this.workEnd,
    required this.status,
    required this.version,
    this.cancelReason,
    this.cancelledAt,
    this.cancelledBy,
    required this.createdAt,
    this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final CalendarWorkingDateExceptionKind kind;
  final DateTime startDate;
  final DateTime endDate;
  final String? titleAr;
  final String? titleEn;
  final String? notes;

  /// Only set for [CalendarWorkingDateExceptionKind.exceptionalWorkingDay].
  final TenantWorkingDayMode? dayMode;
  final String? workStart;
  final String? workEnd;
  final CalendarWorkingDateExceptionStatus status;
  final int version;
  final String? cancelReason;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime updatedAt;
  final String? updatedBy;

  bool get isActive => status == CalendarWorkingDateExceptionStatus.active;

  String titleFallback(String locale) => resolveWorkingDateExceptionTitle(
    locale: locale,
    titleAr: titleAr,
    titleEn: titleEn,
  );
}

/// Applied filters echoed by `list_working_date_exceptions`.
class WorkingDateExceptionFiltersApplied {
  const WorkingDateExceptionFiltersApplied({
    required this.status,
    this.kind,
    required this.dateFrom,
    required this.dateTo,
    required this.limit,
  });

  final CalendarWorkingDateExceptionStatusFilter status;
  final CalendarWorkingDateExceptionKind? kind;
  final DateTime dateFrom;
  final DateTime dateTo;
  final int limit;
}

/// Result of `list_working_date_exceptions`.
class WorkingDateExceptionListResult {
  WorkingDateExceptionListResult({
    required List<WorkingDateException> items,
    required this.hasMore,
    this.nextCursor,
    required this.filtersApplied,
    required this.filtersHash,
  }) : items = List.unmodifiable(items);

  final List<WorkingDateException> items;

  /// Opaque cursor string for the next page; never decoded by UI.
  final String? nextCursor;
  final bool hasMore;
  final WorkingDateExceptionFiltersApplied filtersApplied;
  final String filtersHash;
}
