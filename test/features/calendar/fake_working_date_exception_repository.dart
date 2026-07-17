import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/data/calendar_working_date_exception_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';

WorkingDateException sampleWorkingDateException({
  String id = 'wde-1',
  CalendarWorkingDateExceptionKind kind =
      CalendarWorkingDateExceptionKind.officialHoliday,
  DateTime? startDate,
  DateTime? endDate,
  String? titleAr = 'عيد',
  String? titleEn = 'Holiday',
  String? notes,
  TenantWorkingDayMode? dayMode,
  String? workStart,
  String? workEnd,
  CalendarWorkingDateExceptionStatus status =
      CalendarWorkingDateExceptionStatus.active,
  int version = 1,
  String? cancelReason,
  DateTime? cancelledAt,
  String? cancelledBy,
  DateTime? createdAt,
  String? createdBy = 'user-1',
  DateTime? updatedAt,
  String? updatedBy = 'user-1',
}) {
  final start = startDate ?? DateTime(2026, 8, 1);
  return WorkingDateException(
    id: id,
    kind: kind,
    startDate: start,
    endDate: endDate ?? start,
    titleAr: titleAr,
    titleEn: titleEn,
    notes: notes,
    dayMode: dayMode,
    workStart: workStart,
    workEnd: workEnd,
    status: status,
    version: version,
    cancelReason: cancelReason,
    cancelledAt: cancelledAt,
    cancelledBy: cancelledBy,
    createdAt: createdAt ?? DateTime(2026, 7, 1),
    createdBy: createdBy,
    updatedAt: updatedAt ?? DateTime(2026, 7, 1),
    updatedBy: updatedBy,
  );
}

WorkingDateExceptionListResult sampleWorkingDateExceptionList({
  List<WorkingDateException>? items,
  bool hasMore = false,
  String? nextCursor,
  CalendarWorkingDateExceptionStatusFilter status =
      CalendarWorkingDateExceptionStatusFilter.active,
  CalendarWorkingDateExceptionKind? kind,
  DateTime? dateFrom,
  DateTime? dateTo,
  int limit = CalendarWorkingDateExceptionListDefaults.pageLimit,
}) {
  return WorkingDateExceptionListResult(
    items: items ?? [sampleWorkingDateException()],
    hasMore: hasMore,
    nextCursor: nextCursor,
    filtersApplied: WorkingDateExceptionFiltersApplied(
      status: status,
      kind: kind,
      dateFrom: dateFrom ?? DateTime(2026, 6, 1),
      dateTo: dateTo ?? DateTime(2026, 12, 31),
      limit: limit,
    ),
    filtersHash: 'hash-wde',
  );
}

/// Kept as a small named constant rather than importing the validators file,
/// so fixtures stay decoupled from validation internals.
class CalendarWorkingDateExceptionListDefaults {
  static const pageLimit = 50;
}

typedef FakeWorkingDateExceptionListHandler =
    Future<WorkingDateExceptionListResult> Function(
      AppSession session, {
      required CalendarWorkingDateExceptionStatusFilter status,
      CalendarWorkingDateExceptionKind? kind,
      DateTime? dateFrom,
      DateTime? dateTo,
      String? cursor,
      int? limit,
    });

class FakeWorkingDateExceptionRepository
    extends CalendarWorkingDateExceptionRepository {
  FakeWorkingDateExceptionRepository({
    WorkingDateExceptionListResult? listResult,
    WorkingDateException? getResult,
    WorkingDateException? mutationResult,
    this.listError,
    this.getError,
    this.createError,
    this.updateError,
    this.cancelError,
    this.listHandler,
  }) : listResult = listResult ?? sampleWorkingDateExceptionList(),
       getResult = getResult ?? sampleWorkingDateException(),
       mutationResult = mutationResult ?? sampleWorkingDateException(),
       super(null);

  WorkingDateExceptionListResult listResult;
  WorkingDateException getResult;
  WorkingDateException mutationResult;

  Object? listError;
  Object? getError;
  Object? createError;
  Object? updateError;
  Object? cancelError;
  FakeWorkingDateExceptionListHandler? listHandler;

  int listCount = 0;
  int getCount = 0;
  int createCount = 0;
  int updateCount = 0;
  int cancelCount = 0;

  AppSession? lastSession;
  String? lastExceptionId;
  int? lastExpectedVersion;
  WorkingDateExceptionData? lastData;
  String? lastReason;
  String? lastIdempotencyKey;
  DateTime? lastDateFrom;
  DateTime? lastDateTo;
  String? lastCursor;
  int? lastLimit;

  Object _resolveError(Object? error) {
    if (error is CalendarException) return error;
    return const CalendarException(code: CalendarException.unknown);
  }

  @override
  Future<WorkingDateExceptionListResult> listExceptions(
    AppSession session, {
    CalendarWorkingDateExceptionStatusFilter status =
        CalendarWorkingDateExceptionStatusFilter.active,
    CalendarWorkingDateExceptionKind? kind,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? cursor,
    int? limit,
  }) async {
    listCount++;
    lastSession = session;
    lastDateFrom = dateFrom;
    lastDateTo = dateTo;
    lastCursor = cursor;
    lastLimit = limit;
    final handler = listHandler;
    if (handler != null) {
      return handler(
        session,
        status: status,
        kind: kind,
        dateFrom: dateFrom,
        dateTo: dateTo,
        cursor: cursor,
        limit: limit,
      );
    }
    final error = listError;
    if (error != null) throw _resolveError(error);
    return WorkingDateExceptionListResult(
      items: listResult.items,
      hasMore: listResult.hasMore,
      nextCursor: listResult.nextCursor,
      filtersApplied: WorkingDateExceptionFiltersApplied(
        status: status,
        kind: kind,
        dateFrom: dateFrom ?? listResult.filtersApplied.dateFrom,
        dateTo: dateTo ?? listResult.filtersApplied.dateTo,
        limit: limit ?? listResult.filtersApplied.limit,
      ),
      filtersHash: listResult.filtersHash,
    );
  }

  @override
  Future<WorkingDateException> getException(
    AppSession session,
    String exceptionId,
  ) async {
    getCount++;
    lastSession = session;
    lastExceptionId = exceptionId;
    final error = getError;
    if (error != null) throw _resolveError(error);
    return getResult;
  }

  @override
  Future<WorkingDateException> createException(
    AppSession session, {
    required WorkingDateExceptionData data,
    required String idempotencyKey,
  }) async {
    createCount++;
    lastSession = session;
    lastData = data;
    lastIdempotencyKey = idempotencyKey;
    final error = createError;
    if (error != null) throw _resolveError(error);
    return mutationResult;
  }

  @override
  Future<WorkingDateException> updateException(
    AppSession session, {
    required String exceptionId,
    required int expectedVersion,
    required WorkingDateExceptionData data,
    required String idempotencyKey,
  }) async {
    updateCount++;
    lastSession = session;
    lastExceptionId = exceptionId;
    lastExpectedVersion = expectedVersion;
    lastData = data;
    lastIdempotencyKey = idempotencyKey;
    final error = updateError;
    if (error != null) throw _resolveError(error);
    return mutationResult;
  }

  @override
  Future<WorkingDateException> cancelException(
    AppSession session, {
    required String exceptionId,
    required int expectedVersion,
    required String reason,
    required String idempotencyKey,
  }) async {
    cancelCount++;
    lastSession = session;
    lastExceptionId = exceptionId;
    lastExpectedVersion = expectedVersion;
    lastReason = reason;
    lastIdempotencyKey = idempotencyKey;
    final error = cancelError;
    if (error != null) throw _resolveError(error);
    return mutationResult;
  }
}
