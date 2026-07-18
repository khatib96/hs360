import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_event_list_result.dart';
import '../domain/calendar_event_participant.dart';
import '../domain/calendar_filter_validator.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_directions_target.dart';
import '../domain/calendar_manual_mutation.dart';
import '../domain/calendar_mutation_validators.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_range_summary.dart';
import '../domain/calendar_route_employee.dart';
import '../domain/calendar_route_result.dart';
import '../domain/calendar_schedule_mutation.dart';
import 'calendar_event_list_rpc_mapper.dart';
import 'calendar_manual_mutation_mapper.dart';
import 'calendar_range_summary_rpc_mapper.dart';
import 'calendar_route_repository.dart';
import 'calendar_schedule_mutation_mapper.dart';

part 'calendar_repository.g.dart';

/// Testable RPC invoker: `(functionName, params) => raw JSON`.
typedef CalendarRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);

@Riverpod(keepAlive: true)
CalendarRepository calendarRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return CalendarRepository(client);
}

class CalendarRepository {
  CalendarRepository(this._client, {CalendarRpcInvoker? rpcInvoker})
    : _rpcInvoker = rpcInvoker;

  final SupabaseClient? _client;
  final CalendarRpcInvoker? _rpcInvoker;

  /// M10 Route View / directions RPCs, extracted to keep this file focused.
  late final CalendarRouteRepository _routeRepo = CalendarRouteRepository(
    _invokeRpc,
  );

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw CalendarException.notConfigured();
    return client;
  }

  Future<dynamic> _invokeRpc(String functionName, Map<String, dynamic> params) {
    final invoker = _rpcInvoker;
    if (invoker != null) return invoker(functionName, params);
    return _requireClient.rpc(functionName, params: params);
  }

  void _assertCanAccess(AppSession session) {
    if (!canAccessCalendar(session)) {
      throw const CalendarException(code: CalendarException.permissionDenied);
    }
  }

  void _assertCanCreate(AppSession session) {
    if (!canCreateCalendarEvent(session)) {
      throw const CalendarException(code: CalendarException.permissionDenied);
    }
  }

  void _assertCanEdit(AppSession session) {
    if (!canEditCalendarEvent(session)) {
      throw const CalendarException(code: CalendarException.permissionDenied);
    }
  }

  void _assertFiltersValid({
    required DateTime dateFrom,
    required DateTime dateTo,
    required CalendarFilters filters,
    required AppSession session,
    int? pageLimit,
  }) {
    final validation = CalendarFilterValidator.validate(
      dateFrom: dateFrom,
      dateTo: dateTo,
      filters: filters,
      session: session,
      pageLimit: pageLimit,
    );
    if (!validation.isValid) {
      throw CalendarException(
        code: CalendarException.validationFailed,
        technicalDetail: validation.codes.join(','),
      );
    }
  }

  Future<CalendarRangeSummaryResult> getRangeSummary(
    AppSession session, {
    required DateTime dateFrom,
    required DateTime dateTo,
    CalendarFilters filters = CalendarFilters.empty,
  }) async {
    _assertCanAccess(session);
    _assertFiltersValid(
      dateFrom: dateFrom,
      dateTo: dateTo,
      filters: filters,
      session: session,
    );
    try {
      final result = await _invokeRpc('get_calendar_range_summary', {
        'p_date_from': formatCalendarDateOnly(dateFrom),
        'p_date_to': formatCalendarDateOnly(dateTo),
        'p_filters': filters.toCanonicalPayload(),
      });
      return mapCalendarRangeSummaryFromRpc(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

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
    _assertCanAccess(session);

    final effectiveLimit = (limit ?? CalendarFilters.defaultPageLimit)
        .clamp(1, CalendarFilters.maxPageLimit)
        .toInt();

    _assertFiltersValid(
      dateFrom: dateFrom,
      dateTo: dateTo,
      filters: filters,
      session: session,
      pageLimit: effectiveLimit,
    );

    final cursorSupplied = cursorInRange != null || cursorOverdue != null;

    try {
      final result = await _invokeRpc('list_calendar_events', {
        'p_date_from': formatCalendarDateOnly(dateFrom),
        'p_date_to': formatCalendarDateOnly(dateTo),
        'p_filters': filters.toCanonicalPayload(),
        'p_cursor_in_range': cursorInRange,
        'p_cursor_overdue': cursorOverdue,
        'p_limit': effectiveLimit,
        'p_include_overdue_outside_range': includeOverdueOutsideRange,
      });
      return mapCalendarEventListFromRpc(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(
        e,
        stackTrace: st,
        cursorSupplied: cursorSupplied,
      );
    }
  }

  Future<CalendarManualMutationResult> createManualEvent(
    AppSession session, {
    required CalendarManualEventData data,
    required String idempotencyKey,
  }) async {
    _assertCanCreate(session);
    try {
      final result = await _invokeRpc('create_manual_calendar_event', {
        'p_data': data.toCreateRpcPayload(),
        'p_idempotency_key': idempotencyKey,
      });
      return mapCalendarManualMutationResult(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  Future<CalendarManualMutationResult> updateManualEvent(
    AppSession session, {
    required String eventId,
    required int expectedVersion,
    required CalendarManualEventData data,
    required String idempotencyKey,
  }) async {
    _assertCanEdit(session);
    try {
      final result = await _invokeRpc('update_manual_calendar_event', {
        'p_event_id': eventId,
        'p_expected_version': expectedVersion,
        'p_data': data.toUpdateRpcPayload(),
        'p_idempotency_key': idempotencyKey,
      });
      return mapCalendarManualMutationResult(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  Future<CalendarEvent> cancelManualEvent(
    AppSession session, {
    required String eventId,
    required int expectedVersion,
    required String reason,
    required String idempotencyKey,
  }) async {
    _assertCanEdit(session);
    final validation = CalendarMutationValidators.validateCancelReason(reason);
    if (!validation.isValid) {
      throw CalendarException(
        code: CalendarException.validationFailed,
        technicalDetail: validation.codes.join(','),
      );
    }
    try {
      final result = await _invokeRpc('cancel_manual_calendar_event', {
        'p_event_id': eventId,
        'p_expected_version': expectedVersion,
        'p_reason': reason.trim(),
        'p_idempotency_key': idempotencyKey,
      });
      return mapCalendarManualOkEvent(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  Future<CalendarEvent> markManualEventDone(
    AppSession session, {
    required String eventId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    _assertCanEdit(session);
    try {
      final result = await _invokeRpc('mark_manual_event_done', {
        'p_event_id': eventId,
        'p_expected_version': expectedVersion,
        'p_idempotency_key': idempotencyKey,
      });
      return mapCalendarManualOkEvent(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  /// Assigns (or unassigns, via null agent) a pending non-meeting event.
  Future<CalendarScheduleMutationResult> assignCalendarEvent(
    AppSession session, {
    required String eventId,
    required int expectedVersion,
    required CalendarAssignmentData data,
    required String idempotencyKey,
  }) async {
    _assertCanEdit(session);
    final validation = CalendarMutationValidators.validateAssignmentAgentId(
      data.assignedAgentId,
    );
    if (!validation.isValid) {
      throw CalendarException(
        code: CalendarException.validationFailed,
        technicalDetail: validation.codes.join(','),
      );
    }
    try {
      final result = await _invokeRpc('assign_calendar_event', {
        'p_event_id': eventId,
        'p_expected_version': expectedVersion,
        'p_data': data.toRpcPayload(),
        'p_idempotency_key': idempotencyKey,
      });
      return mapCalendarScheduleMutationResult(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  /// Moves a pending event to a new date with a mandatory audited reason.
  Future<CalendarScheduleMutationResult> rescheduleCalendarEvent(
    AppSession session, {
    required String eventId,
    required int expectedVersion,
    required CalendarRescheduleData data,
    required String idempotencyKey,
  }) async {
    _assertCanEdit(session);
    final codes = <String>[
      ...CalendarMutationValidators.validateRescheduleTargetDate(
        formatCalendarDateOnly(data.scheduledDate),
      ).codes,
      ...CalendarMutationValidators.validateRescheduleReason(data.reason).codes,
    ];
    if (codes.isNotEmpty) {
      throw CalendarException(
        code: CalendarException.validationFailed,
        technicalDetail: codes.join(','),
      );
    }
    try {
      final result = await _invokeRpc('reschedule_calendar_event', {
        'p_event_id': eventId,
        'p_expected_version': expectedVersion,
        'p_data': data.toRpcPayload(),
        'p_idempotency_key': idempotencyKey,
      });
      return mapCalendarScheduleMutationResult(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  Future<List<CalendarParticipantCandidate>> listParticipantCandidates(
    AppSession session, {
    String? search,
    int limit = 50,
  }) async {
    if (!canCreateCalendarEvent(session) && !canEditCalendarEvent(session)) {
      throw const CalendarException(code: CalendarException.permissionDenied);
    }
    try {
      final result = await _invokeRpc('list_calendar_participant_candidates', {
        'p_search': search,
        'p_limit': limit.clamp(1, 100),
      });
      return mapParticipantCandidates(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  /// M10: one employee's Route View events for [date] (`get_calendar_route_day`).
  Future<CalendarRouteResult> getRouteDay(
    AppSession session, {
    required DateTime date,
    String? employeeId,
  }) => _routeRepo.getRouteDay(session, date: date, employeeId: employeeId);

  /// M10: tenant-wide employee picker candidates (`list_calendar_route_employees`).
  Future<CalendarRouteEmployeeListResult> listRouteEmployees(
    AppSession session, {
    String? search,
    int? limit,
  }) => _routeRepo.listRouteEmployees(session, search: search, limit: limit);

  /// M10: resolved directions target for one event (`get_calendar_event_directions`).
  Future<CalendarDirectionsTarget> getEventDirections(
    AppSession session,
    String eventId,
  ) => _routeRepo.getEventDirections(session, eventId);
}
