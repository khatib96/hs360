import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../domain/audit_log_entry.dart';
import '../domain/audit_log_filters.dart';

typedef AuditLogRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepository(ref.watch(supabaseClientProvider));
});

class AuditLogException implements Exception {
  const AuditLogException(this.code);

  static const notConfigured = 'supabase_not_configured';
  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
  static const unavailable = 'unavailable';

  final String code;
}

class AuditLogRepository {
  AuditLogRepository(this._client, {AuditLogRpcInvoker? rpcInvoker})
    : _rpcInvoker = rpcInvoker;

  static const pageSize = 50;

  final SupabaseClient? _client;
  final AuditLogRpcInvoker? _rpcInvoker;

  Future<AuditLogPage> list(
    AppSession session, {
    AuditLogFilters filters = const AuditLogFilters(),
    DateTime? beforeAt,
    int? beforeId,
    int limit = pageSize,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_module': filters.module,
        'p_action': filters.action,
        'p_actor_id': filters.actorId,
        'p_date_from': _formatDate(filters.dateFrom),
        'p_date_to': _formatDate(filters.dateTo),
        'p_search': _trimmed(filters.search),
        'p_limit': limit,
        'p_before_at': beforeAt?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
      };
      final invoker = _rpcInvoker;
      final response = invoker != null
          ? await invoker('list_phase_7_5_audit_log', params)
          : await _requireClient.rpc(
              'list_phase_7_5_audit_log',
              params: params,
            );
      return AuditLogPage.fromJson(_asMap(response));
    } catch (error) {
      throw _mapError(error);
    }
  }

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw const AuditLogException(AuditLogException.notConfigured);
    }
    return client;
  }

  static String? _formatDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw const FormatException('Expected audit object response');
  }

  static AuditLogException _mapError(Object error) {
    if (error is AuditLogException) return error;
    final message = error.toString().toLowerCase();
    if (message.contains(AuditLogException.permissionDenied)) {
      return const AuditLogException(AuditLogException.permissionDenied);
    }
    if (message.contains(AuditLogException.validationFailed)) {
      return const AuditLogException(AuditLogException.validationFailed);
    }
    return const AuditLogException(AuditLogException.unavailable);
  }
}
