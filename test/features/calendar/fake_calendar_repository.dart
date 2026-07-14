import 'dart:async';

import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_event.dart';
import 'package:hs360/features/calendar/domain/calendar_event_list_result.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';
import 'package:hs360/features/calendar/domain/calendar_range_summary.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_working_day.dart';

CalendarWorkingDay sampleCalendarWorkingDay([DateTime? date]) {
  final d = date ?? DateTime(2026, 7, 14);
  return CalendarWorkingDay(
    tenantId: 'tenant-1',
    date: d,
    isoWeekday: d.weekday,
    scheduleConfigured: true,
    timezoneName: 'Asia/Kuwait',
    dayMode: TenantWorkingDayMode.workingHours,
    workStart: '08:00',
    workEnd: '17:00',
    isUnreviewed: false,
    isDayOff: false,
    is24Hours: false,
    isWorkingHours: true,
  );
}

CalendarEvent sampleCalendarEvent({
  String id = 'event-1',
  DateTime? scheduledDate,
  DateTime? originalDueDate,
}) {
  final date = scheduledDate ?? DateTime(2026, 7, 14);
  return CalendarEvent(
    id: id,
    type: CalendarEventType.refillDue,
    status: CalendarEventStatus.pending,
    sourceKind: CalendarEventSourceKind.contractGenerated,
    scheduledDate: date,
    originalDueDate: originalDueDate ?? date,
    titleAr: 'تعبئة',
    titleEn: 'Refill',
    isRescheduled: false,
    directionsAvailable: false,
    scheduleState: CalendarScheduleState.workingDay,
    workingDay: sampleCalendarWorkingDay(date),
    isOverdue: false,
    overdueDays: 0,
    overdueState: CalendarOverdueState.notOverdue,
    availableActions: const CalendarAvailableActions(
      canViewCustomer: true,
      canViewContract: true,
      canAssign: false,
      canReschedule: false,
      canCreateManual: false,
      canOpenDirections: false,
    ),
  );
}

CalendarRangeSummaryResult sampleRangeSummary({
  DateTime? dateFrom,
  DateTime? dateTo,
  DateTime? tenantLocalToday,
  bool workingScheduleConfigured = true,
  CalendarOverdueOutsideRangeState overdueState =
      CalendarOverdueOutsideRangeState.available,
}) {
  final from = dateFrom ?? DateTime(2026, 7, 1);
  final to = dateTo ?? DateTime(2026, 7, 31);
  return CalendarRangeSummaryResult(
    dateFrom: from,
    dateTo: to,
    timezoneName: 'Asia/Kuwait',
    workingScheduleConfigured: workingScheduleConfigured,
    tenantLocalToday: tenantLocalToday ?? DateTime(2026, 7, 14),
    scope: CalendarReadScope.tenantWide,
    filtersHash: 'hash-abc',
    days: [
      CalendarDaySummary(
        date: DateTime(2026, 7, 14),
        isoWeekday: 2,
        eventCount: 1,
        unassignedCount: 0,
        overdueCount: 0,
        workingDay: sampleCalendarWorkingDay(),
      ),
    ],
    overdueOutsideRange: CalendarOverdueOutsideRangeSummary(
      state: overdueState,
      count: overdueState == CalendarOverdueOutsideRangeState.available
          ? 1
          : null,
      oldestOriginalDueDate:
          overdueState == CalendarOverdueOutsideRangeState.available
          ? DateTime(2026, 6, 1)
          : null,
    ),
    filtersApplied: CalendarFilters.empty,
  );
}

CalendarEventListResult sampleEventList({
  DateTime? dateFrom,
  DateTime? dateTo,
  DateTime? tenantLocalToday,
  List<CalendarEvent>? inRangeRows,
  List<CalendarEvent>? overdueRows,
  String? nextCursorInRange,
  String? nextCursorOverdue,
  bool hasMoreInRange = false,
  bool hasMoreOverdue = false,
}) {
  final from = dateFrom ?? DateTime(2026, 7, 14);
  final to = dateTo ?? from;
  return CalendarEventListResult(
    dateFrom: from,
    dateTo: to,
    limit: CalendarFilters.defaultPageLimit,
    scope: CalendarReadScope.tenantWide,
    tenantLocalToday: tenantLocalToday ?? DateTime(2026, 7, 14),
    filtersHash: 'hash-list',
    inRange: CalendarEventBucket(
      rows: inRangeRows ?? [sampleCalendarEvent()],
      nextCursor: nextCursorInRange,
      hasMore: hasMoreInRange,
    ),
    overdueOutsideRange: CalendarEventBucket(
      rows:
          overdueRows ??
          [
            sampleCalendarEvent(
              id: 'overdue-1',
              scheduledDate: DateTime(2026, 6, 1),
              originalDueDate: DateTime(2026, 6, 1),
            ),
          ],
      nextCursor: nextCursorOverdue,
      hasMore: hasMoreOverdue,
    ),
  );
}

class FakeCalendarRepository extends CalendarRepository {
  FakeCalendarRepository({
    CalendarRangeSummaryResult? rangeResult,
    CalendarEventListResult? listResult,
    this.rangeError,
    this.listError,
    this.listErrorWhenIncludeOverdue,
  }) : rangeResult = rangeResult ?? sampleRangeSummary(),
       listResult = listResult ?? sampleEventList(),
       super(null);

  CalendarRangeSummaryResult rangeResult;
  CalendarEventListResult listResult;
  Object? rangeError;
  Object? listError;

  /// When set, only list calls with includeOverdueOutsideRange=true throw.
  Object? listErrorWhenIncludeOverdue;

  /// Gates: when non-null, the corresponding call awaits [Completer.future]
  /// before returning (lets tests switch tenant mid-flight).
  Completer<void>? holdSummaryUntil;
  Completer<void>? holdAgendaUntil;
  Completer<void>? holdOverdueUntil;
  Completer<void>? holdLoadMoreInRangeUntil;
  Completer<void>? holdLoadMoreOverdueUntil;

  int getRangeSummaryCount = 0;
  int listEventsCount = 0;

  DateTime? lastRangeFrom;
  DateTime? lastRangeTo;
  CalendarFilters? lastRangeFilters;
  AppSession? lastRangeSession;

  DateTime? lastListFrom;
  DateTime? lastListTo;
  CalendarFilters? lastListFilters;
  String? lastCursorInRange;
  String? lastCursorOverdue;
  int? lastLimit;
  bool? lastIncludeOverdue;
  AppSession? lastListSession;

  final List<
    ({
      DateTime dateFrom,
      DateTime dateTo,
      CalendarFilters filters,
      String? cursorInRange,
      String? cursorOverdue,
      bool includeOverdue,
    })
  >
  listCallLog = [];

  final List<({DateTime dateFrom, DateTime dateTo, CalendarFilters filters})>
  rangeCallLog = [];

  @override
  Future<CalendarRangeSummaryResult> getRangeSummary(
    AppSession session, {
    required DateTime dateFrom,
    required DateTime dateTo,
    CalendarFilters filters = CalendarFilters.empty,
  }) async {
    getRangeSummaryCount++;
    lastRangeFrom = dateFrom;
    lastRangeTo = dateTo;
    lastRangeFilters = filters;
    lastRangeSession = session;
    rangeCallLog.add((dateFrom: dateFrom, dateTo: dateTo, filters: filters));

    final gate = holdSummaryUntil;
    if (gate != null) await gate.future;

    final error = rangeError;
    if (error != null) {
      if (error is CalendarException) throw error;
      throw CalendarException(
        code: CalendarException.unknown,
        technicalDetail: error.toString(),
      );
    }
    return rangeResult;
  }

  @override
  Future<CalendarEventListResult> listEvents(
    AppSession session, {
    required DateTime dateFrom,
    required DateTime dateTo,
    CalendarFilters filters = CalendarFilters.empty,
    String? cursorInRange,
    String? cursorOverdue,
    int? limit,
    bool includeOverdueOutsideRange = false,
  }) async {
    listEventsCount++;
    lastListFrom = dateFrom;
    lastListTo = dateTo;
    lastListFilters = filters;
    lastCursorInRange = cursorInRange;
    lastCursorOverdue = cursorOverdue;
    lastLimit = limit;
    lastIncludeOverdue = includeOverdueOutsideRange;
    lastListSession = session;
    listCallLog.add((
      dateFrom: dateFrom,
      dateTo: dateTo,
      filters: filters,
      cursorInRange: cursorInRange,
      cursorOverdue: cursorOverdue,
      includeOverdue: includeOverdueOutsideRange,
    ));

    if (includeOverdueOutsideRange) {
      if (cursorOverdue != null) {
        final gate = holdLoadMoreOverdueUntil;
        if (gate != null) await gate.future;
      } else {
        final gate = holdOverdueUntil;
        if (gate != null) await gate.future;
      }
    } else {
      if (cursorInRange != null) {
        final gate = holdLoadMoreInRangeUntil;
        if (gate != null) await gate.future;
      } else {
        final gate = holdAgendaUntil;
        if (gate != null) await gate.future;
      }
    }

    final overdueOnlyError = listErrorWhenIncludeOverdue;
    if (includeOverdueOutsideRange && overdueOnlyError != null) {
      if (overdueOnlyError is CalendarException) throw overdueOnlyError;
      throw CalendarException(
        code: CalendarException.unknown,
        technicalDetail: overdueOnlyError.toString(),
      );
    }

    final error = listError;
    if (error != null) {
      if (error is CalendarException) throw error;
      throw CalendarException(
        code: CalendarException.unknown,
        technicalDetail: error.toString(),
      );
    }
    return listResult;
  }
}
