import 'dart:async';

import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_date.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_event.dart';
import 'package:hs360/features/calendar/domain/calendar_event_list_result.dart';
import 'package:hs360/features/calendar/domain/calendar_event_participant.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';
import 'package:hs360/features/calendar/domain/calendar_meeting_mode.dart';
import 'package:hs360/features/calendar/domain/calendar_range_summary.dart';
import 'package:hs360/features/calendar/domain/calendar_schedule_mutation.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_time_window.dart';
import 'package:hs360/features/calendar/domain/calendar_working_day.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';

import 'fake_calendar_route_repository.dart';

CalendarWorkingDay sampleCalendarWorkingDay({
  DateTime? date,
  TenantWorkingDayMode dayMode = TenantWorkingDayMode.workingHours,
  String? workStart = '08:00',
  String? workEnd = '17:00',
  bool scheduleConfigured = true,
  bool? isUnreviewed,
  bool? isDayOff,
  bool? is24Hours,
  bool? isWorkingHours,
  CalendarDateExceptionRef? dateException,
}) {
  final d = date ?? DateTime(2026, 7, 14);
  final unreviewed =
      isUnreviewed ??
      (dayMode == TenantWorkingDayMode.unreviewed || !scheduleConfigured);
  final dayOff = isDayOff ?? dayMode == TenantWorkingDayMode.dayOff;
  final hours24 = is24Hours ?? dayMode == TenantWorkingDayMode.hours24;
  final working =
      isWorkingHours ?? dayMode == TenantWorkingDayMode.workingHours;
  return CalendarWorkingDay(
    tenantId: 'tenant-1',
    date: d,
    isoWeekday: d.weekday,
    scheduleConfigured: scheduleConfigured,
    timezoneName: 'Asia/Kuwait',
    dayMode: dayMode,
    workStart: hours24 || dayOff || unreviewed ? null : workStart,
    workEnd: hours24 || dayOff || unreviewed ? null : workEnd,
    isUnreviewed: unreviewed,
    isDayOff: dayOff,
    is24Hours: hours24,
    isWorkingHours: working,
    dateException: dateException,
  );
}

CalendarParticipantCandidate sampleParticipantCandidate({
  String employeeId = 'emp-1',
  String nameAr = 'موظف',
  String? nameEn = 'Employee',
  bool isActive = true,
  bool hasAppAccount = true,
  bool hasActiveTenantAccount = true,
  bool hasCalendarAccess = true,
}) {
  return CalendarParticipantCandidate(
    employeeId: employeeId,
    nameAr: nameAr,
    nameEn: nameEn,
    isActive: isActive,
    hasAppAccount: hasAppAccount,
    hasActiveTenantAccount: hasActiveTenantAccount,
    hasCalendarAccess: hasCalendarAccess,
  );
}

CalendarEvent sampleCalendarEvent({
  String id = 'event-1',
  DateTime? scheduledDate,
  DateTime? originalDueDate,
  String? titleAr,
  String? titleEn,
  CalendarEventType type = CalendarEventType.refillDue,
  CalendarEventStatus status = CalendarEventStatus.pending,
  CalendarEventSourceKind sourceKind =
      CalendarEventSourceKind.contractGenerated,
  String? customerId,
  String? customerNameAr,
  String? customerNameEn,
  String? contractId,
  String? contractNumber,
  String? serviceLocationName,
  String? assignedAgentId,
  String? assignedAgentNameAr,
  String? assignedAgentNameEn,
  bool directionsAvailable = false,
  bool isOverdue = false,
  int overdueDays = 0,
  CalendarOverdueState overdueState = CalendarOverdueState.notOverdue,
  CalendarAvailableActions? availableActions,
  int scheduleVersion = 1,
  CalendarTimeWindow? timeWindow,
  CalendarScheduleState scheduleState = CalendarScheduleState.workingDay,
  CalendarWorkingDay? workingDay,
  List<CalendarEventParticipant> participants = const [],
  CalendarMeetingMode? meetingMode,
  String? meetingUrl,
}) {
  final date = scheduledDate ?? DateTime(2026, 7, 14);
  return CalendarEvent(
    id: id,
    type: type,
    status: status,
    sourceKind: sourceKind,
    scheduledDate: date,
    originalDueDate: originalDueDate ?? date,
    titleAr: titleAr ?? 'تعبئة',
    titleEn: titleEn ?? 'Refill',
    isRescheduled: false,
    assignedAgentId: assignedAgentId,
    assignedAgentNameAr: assignedAgentNameAr,
    assignedAgentNameEn: assignedAgentNameEn,
    customerId: customerId,
    customerNameAr: customerNameAr,
    customerNameEn: customerNameEn,
    serviceLocationName: serviceLocationName,
    contractId: contractId,
    contractNumber: contractNumber,
    directionsAvailable: directionsAvailable,
    scheduleState: scheduleState,
    workingDay: workingDay ?? sampleCalendarWorkingDay(date: date),
    isOverdue: isOverdue,
    overdueDays: overdueDays,
    overdueState: overdueState,
    availableActions:
        availableActions ??
        const CalendarAvailableActions(
          canViewCustomer: true,
          canViewContract: true,
          canAssign: false,
          canReschedule: false,
          canCreateManual: false,
          canOpenDirections: false,
          canEditManual: false,
          canCancelManual: false,
          canMarkManualDone: false,
          canOpenMeetingLink: false,
        ),
    scheduleVersion: scheduleVersion,
    timeWindow: timeWindow,
    participants: participants,
    meetingMode: meetingMode,
    meetingUrl: meetingUrl,
  );
}

CalendarRangeSummaryResult sampleRangeSummary({
  DateTime? dateFrom,
  DateTime? dateTo,
  DateTime? tenantLocalToday,
  bool workingScheduleConfigured = true,
  CalendarOverdueOutsideRangeState overdueState =
      CalendarOverdueOutsideRangeState.available,
  int? overdueOutsideCount,
  CalendarFilters filtersApplied = CalendarFilters.empty,
  CalendarReadScope scope = CalendarReadScope.tenantWide,
  int? unassignedCount = 0,
  int Function(DateTime date)? eventCountForDate,
  CalendarWorkingDay Function(DateTime date)? workingDayForDate,
}) {
  final from = dateFrom ?? DateTime(2026, 7, 1);
  final to = dateTo ?? DateTime(2026, 7, 31);
  final highlight = DateTime(2026, 7, 14);
  final days = <CalendarDaySummary>[];
  var cursor = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  while (!cursor.isAfter(end)) {
    final isHighlight = cursor == highlight;
    days.add(
      CalendarDaySummary(
        date: cursor,
        isoWeekday: cursor.weekday,
        eventCount: eventCountForDate?.call(cursor) ?? (isHighlight ? 1 : 0),
        unassignedCount: unassignedCount,
        overdueCount: 0,
        workingDay:
            workingDayForDate?.call(cursor) ??
            sampleCalendarWorkingDay(date: cursor),
      ),
    );
    cursor = addCalendarDays(cursor, 1);
  }
  final resolvedOverdueCount =
      overdueOutsideCount ??
      (overdueState == CalendarOverdueOutsideRangeState.available ? 1 : null);
  return CalendarRangeSummaryResult(
    dateFrom: from,
    dateTo: to,
    timezoneName: 'Asia/Kuwait',
    workingScheduleConfigured: workingScheduleConfigured,
    tenantLocalToday: tenantLocalToday ?? DateTime(2026, 7, 14),
    scope: scope,
    filtersHash: 'hash-abc',
    days: days,
    overdueOutsideRange: CalendarOverdueOutsideRangeSummary(
      state: overdueState,
      count: resolvedOverdueCount,
      oldestOriginalDueDate:
          overdueState == CalendarOverdueOutsideRangeState.available &&
              (resolvedOverdueCount ?? 0) > 0
          ? DateTime(2026, 6, 1)
          : null,
    ),
    filtersApplied: filtersApplied,
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

class FakeCalendarRepository extends CalendarRepository
    with FakeCalendarRouteRepositoryMixin {
  FakeCalendarRepository({
    CalendarRangeSummaryResult? rangeResult,
    CalendarEventListResult? listResult,
    this.rangeError,
    this.listError,
    this.listErrorWhenIncludeOverdue,
    this.rangeScope = CalendarReadScope.tenantWide,
    this.rangeUnassignedCount = 0,
    this.workingDayForDate,
    this.eventCountForDate,
    this.echoAgendaDate = false,
    this.filterAgendaToRequestedDate = false,
    this.participantCandidates = const [],
  }) : rangeResult = rangeResult ?? sampleRangeSummary(),
       listResult = listResult ?? sampleEventList(),
       super(null);

  CalendarRangeSummaryResult rangeResult;
  CalendarEventListResult listResult;
  Object? rangeError;
  Object? listError;

  /// When set, only list calls with includeOverdueOutsideRange=true throw.
  Object? listErrorWhenIncludeOverdue;

  CalendarReadScope rangeScope;
  int? rangeUnassignedCount;
  CalendarWorkingDay Function(DateTime date)? workingDayForDate;
  int Function(DateTime date)? eventCountForDate;

  /// When true, agenda list rows are generated for the requested dateFrom.
  bool echoAgendaDate;

  /// When true (and [echoAgendaDate] is false), in-range rows are filtered to
  /// the requested agenda date so selected-day screenshots stay consistent.
  bool filterAgendaToRequestedDate;

  /// Optional participant-candidate list for M7A create/edit dialogs and the
  /// M8 assignment dialog.
  List<CalendarParticipantCandidate> participantCandidates;

  /// When non-null, assign/reschedule (or candidate lookups) throw.
  Object? assignError;
  Object? rescheduleError;
  Object? candidatesError;

  /// Queue of reschedule results (lets tests drive confirmation loops).
  /// Falls back to an ok/changed echo of the request when empty.
  final List<CalendarScheduleMutationResult> rescheduleResultsQueue = [];

  /// Optional fixed assign result; defaults to an ok/changed echo.
  CalendarScheduleMutationResult? assignResult;

  Completer<void>? holdAssignUntil;
  Completer<void>? holdRescheduleUntil;

  int assignCount = 0;
  int rescheduleCount = 0;
  int candidatesCount = 0;

  String? lastAssignEventId;
  int? lastAssignExpectedVersion;
  CalendarAssignmentData? lastAssignData;
  String? lastAssignIdempotencyKey;

  String? lastRescheduleEventId;
  int? lastRescheduleExpectedVersion;
  CalendarRescheduleData? lastRescheduleData;
  String? lastRescheduleIdempotencyKey;
  final List<String> assignKeyLog = [];
  final List<String> rescheduleKeyLog = [];

  String? lastCandidatesSearch;

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
    // Echo requested range/filters so controller contract checks pass.
    return sampleRangeSummary(
      dateFrom: dateFrom,
      dateTo: dateTo,
      tenantLocalToday: rangeResult.tenantLocalToday,
      workingScheduleConfigured: rangeResult.workingScheduleConfigured,
      overdueState: rangeResult.overdueOutsideRange.state,
      overdueOutsideCount: rangeResult.overdueOutsideRange.count,
      filtersApplied: filters,
      scope: rangeScope,
      unassignedCount: rangeUnassignedCount,
      eventCountForDate: eventCountForDate,
      workingDayForDate: workingDayForDate,
    );
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

    if (echoAgendaDate && !includeOverdueOutsideRange) {
      return sampleEventList(
        dateFrom: dateFrom,
        dateTo: dateTo,
        tenantLocalToday: listResult.tenantLocalToday,
        inRangeRows: [
          sampleCalendarEvent(
            id: 'event-${dateFrom.year}-${dateFrom.month}-${dateFrom.day}',
            scheduledDate: dateFrom,
          ),
        ],
        overdueRows: const [],
        hasMoreInRange: listResult.inRange.hasMore,
        nextCursorInRange: listResult.inRange.nextCursor,
        hasMoreOverdue: false,
      );
    }
    if (filterAgendaToRequestedDate && !includeOverdueOutsideRange) {
      final day = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
      final rows = listResult.inRange.rows
          .where(
            (e) =>
                e.scheduledDate.year == day.year &&
                e.scheduledDate.month == day.month &&
                e.scheduledDate.day == day.day,
          )
          .toList(growable: false);
      return CalendarEventListResult(
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: listResult.limit,
        scope: listResult.scope,
        tenantLocalToday: listResult.tenantLocalToday,
        filtersHash: listResult.filtersHash,
        inRange: CalendarEventBucket(
          rows: rows,
          nextCursor: listResult.inRange.nextCursor,
          hasMore: listResult.inRange.hasMore,
        ),
        overdueOutsideRange: listResult.overdueOutsideRange,
      );
    }
    return listResult;
  }

  @override
  Future<List<CalendarParticipantCandidate>> listParticipantCandidates(
    AppSession session, {
    String? search,
    int limit = 50,
  }) async {
    candidatesCount++;
    lastCandidatesSearch = search;
    _maybeThrow(candidatesError);
    final q = search?.trim().toLowerCase() ?? '';
    final filtered = q.isEmpty
        ? participantCandidates
        : participantCandidates.where((p) {
            final ar = p.nameAr.toLowerCase();
            final en = (p.nameEn ?? '').toLowerCase();
            return ar.contains(q) || en.contains(q);
          }).toList();
    // Mirrors the real mapper: candidate collections are frozen.
    return List.unmodifiable(filtered.take(limit.clamp(1, 100)));
  }

  @override
  Future<CalendarScheduleMutationResult> assignCalendarEvent(
    AppSession session, {
    required String eventId,
    required int expectedVersion,
    required CalendarAssignmentData data,
    required String idempotencyKey,
  }) async {
    assignCount++;
    lastAssignEventId = eventId;
    lastAssignExpectedVersion = expectedVersion;
    lastAssignData = data;
    lastAssignIdempotencyKey = idempotencyKey;
    assignKeyLog.add(idempotencyKey);

    final gate = holdAssignUntil;
    if (gate != null) await gate.future;

    _maybeThrow(assignError);
    return assignResult ??
        CalendarScheduleMutationOk(
          sampleCalendarEvent(id: eventId),
          changed: true,
        );
  }

  @override
  Future<CalendarScheduleMutationResult> rescheduleCalendarEvent(
    AppSession session, {
    required String eventId,
    required int expectedVersion,
    required CalendarRescheduleData data,
    required String idempotencyKey,
  }) async {
    rescheduleCount++;
    lastRescheduleEventId = eventId;
    lastRescheduleExpectedVersion = expectedVersion;
    lastRescheduleData = data;
    lastRescheduleIdempotencyKey = idempotencyKey;
    rescheduleKeyLog.add(idempotencyKey);

    final gate = holdRescheduleUntil;
    if (gate != null) await gate.future;

    _maybeThrow(rescheduleError);
    if (rescheduleResultsQueue.isNotEmpty) {
      return rescheduleResultsQueue.removeAt(0);
    }
    return CalendarScheduleMutationOk(
      sampleCalendarEvent(id: eventId, scheduledDate: data.scheduledDate),
      changed: true,
    );
  }

  void _maybeThrow(Object? error) {
    if (error == null) return;
    if (error is CalendarException) throw error;
    throw CalendarException(
      code: CalendarException.unknown,
      technicalDetail: error.toString(),
    );
  }
}
