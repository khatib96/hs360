import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../domain/calendar_date.dart';
import '../domain/calendar_mutation_validators.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_working_date_exception.dart';
import '../domain/calendar_working_date_exception_validators.dart';
import 'calendar_working_date_exception_rpc_mapper.dart';

part 'calendar_working_date_exception_repository.g.dart';

/// Testable RPC invoker: `(functionName, params) => raw JSON`.
typedef WorkingDateExceptionRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);

@Riverpod(keepAlive: true)
CalendarWorkingDateExceptionRepository calendarWorkingDateExceptionRepository(
  Ref ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return CalendarWorkingDateExceptionRepository(client);
}

/// Repository for M7B working-date exceptions (official holidays, company
/// closures, exceptional working days). Gated by `settings.calendar.view`
/// and `settings.calendar.edit`, distinct from ordinary calendar-event
/// permissions.
class CalendarWorkingDateExceptionRepository {
  CalendarWorkingDateExceptionRepository(
    this._client, {
    WorkingDateExceptionRpcInvoker? rpcInvoker,
  }) : _rpcInvoker = rpcInvoker;

  final SupabaseClient? _client;
  final WorkingDateExceptionRpcInvoker? _rpcInvoker;

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

  void _assertCanView(AppSession session) {
    if (!canViewCalendarSettings(session)) {
      throw const CalendarException(code: CalendarException.permissionDenied);
    }
  }

  void _assertCanEdit(AppSession session) {
    if (!canEditCalendarSettings(session)) {
      throw const CalendarException(code: CalendarException.permissionDenied);
    }
  }

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
    _assertCanView(session);
    if ((dateFrom == null) != (dateTo == null)) {
      throw const CalendarException(code: CalendarException.validationFailed);
    }
    if (limit != null &&
        (limit < 1 ||
            limit > CalendarWorkingDateExceptionValidators.maxPageLimit)) {
      throw const CalendarException(code: CalendarException.validationFailed);
    }
    if (dateFrom != null && dateTo != null) {
      if (dateTo.isBefore(dateFrom) ||
          inclusiveDaySpan(dateFrom, dateTo) - 1 >
              CalendarWorkingDateExceptionValidators.maxListRangeDays) {
        throw const CalendarException(code: CalendarException.validationFailed);
      }
    }

    final filters = <String, dynamic>{'status': status.rpcValue};
    if (kind != null) filters['kind'] = kind.rpcValue;
    if (dateFrom != null && dateTo != null) {
      filters['date_from'] = formatCalendarDateOnly(dateFrom);
      filters['date_to'] = formatCalendarDateOnly(dateTo);
    }

    try {
      final result = await _invokeRpc('list_working_date_exceptions', {
        'p_filters': filters,
        'p_cursor': cursor,
        'p_limit': limit,
      });
      return mapWorkingDateExceptionListFromRpc(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(
        e,
        stackTrace: st,
        cursorSupplied: cursor != null,
      );
    }
  }

  Future<WorkingDateException> getException(
    AppSession session,
    String exceptionId,
  ) async {
    _assertCanView(session);
    try {
      final result = await _invokeRpc('get_working_date_exception', {
        'p_exception_id': exceptionId,
      });
      return mapGetWorkingDateExceptionResult(result);
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  Future<WorkingDateException> createException(
    AppSession session, {
    required WorkingDateExceptionData data,
    required String idempotencyKey,
  }) async {
    _assertCanEdit(session);
    try {
      final result = await _invokeRpc('create_working_date_exception', {
        'p_data': data.toCreateRpcPayload(),
        'p_idempotency_key': idempotencyKey,
      });
      return mapWorkingDateExceptionMutationResult(
        result,
        'create_working_date_exception',
      );
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  Future<WorkingDateException> updateException(
    AppSession session, {
    required String exceptionId,
    required int expectedVersion,
    required WorkingDateExceptionData data,
    required String idempotencyKey,
  }) async {
    _assertCanEdit(session);
    try {
      final result = await _invokeRpc('update_working_date_exception', {
        'p_exception_id': exceptionId,
        'p_expected_version': expectedVersion,
        'p_data': data.toUpdateRpcPayload(),
        'p_idempotency_key': idempotencyKey,
      });
      return mapWorkingDateExceptionMutationResult(
        result,
        'update_working_date_exception',
      );
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }

  Future<WorkingDateException> cancelException(
    AppSession session, {
    required String exceptionId,
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
      final result = await _invokeRpc('cancel_working_date_exception', {
        'p_exception_id': exceptionId,
        'p_expected_version': expectedVersion,
        'p_reason': reason.trim(),
        'p_idempotency_key': idempotencyKey,
      });
      return mapWorkingDateExceptionMutationResult(
        result,
        'cancel_working_date_exception',
      );
    } catch (e, st) {
      if (e is CalendarException) rethrow;
      throw CalendarException.fromSupabase(e, stackTrace: st);
    }
  }
}
