import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_event_list_result.dart';
import '../domain/calendar_filter_validator.dart';
import '../domain/calendar_filters.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_range_summary.dart';
import 'calendar_event_list_rpc_mapper.dart';
import 'calendar_range_summary_rpc_mapper.dart';

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
}
