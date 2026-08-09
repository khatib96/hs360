import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../domain/activity_feed.dart';
import '../domain/dashboard_summary.dart';

typedef DashboardRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

class DashboardException implements Exception {
  const DashboardException(this.code);

  static const notConfigured = 'supabase_not_configured';
  static const permissionDenied = 'permission_denied';
  static const timezoneUnconfigured = 'calendar_timezone_unconfigured';
  static const validationFailed = 'validation_failed';
  static const unavailable = 'unavailable';

  final String code;
}

class DashboardRepository {
  DashboardRepository(this._client, {DashboardRpcInvoker? rpcInvoker})
    : _rpcInvoker = rpcInvoker;

  static const pageSize = 40;

  final SupabaseClient? _client;
  final DashboardRpcInvoker? _rpcInvoker;

  Future<dynamic> _invoke(String name, Map<String, dynamic> params) {
    final invoker = _rpcInvoker;
    if (invoker != null) return invoker(name, params);
    final client = _client;
    if (client == null) {
      throw const DashboardException(DashboardException.notConfigured);
    }
    return client.rpc(name, params: params);
  }

  Future<DashboardSummary> getDashboard(
    AppSession session, {
    DateTime? businessDate,
  }) async {
    try {
      final response = await _invoke('get_phase_7_5_dashboard', {
        'p_business_date': _formatDate(businessDate),
      });
      return DashboardSummary.fromJson(_asMap(response));
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<ActivityFeedPage> listDashboardDrilldown(
    AppSession session, {
    required String kind,
    required DateTime businessDate,
    int offset = 0,
    int limit = pageSize,
  }) async {
    try {
      final response = await _invoke('list_phase_7_5_dashboard_drilldown', {
        'p_kind': kind,
        'p_business_date': _formatDate(businessDate),
        'p_limit': limit,
        'p_offset': offset,
      });
      return ActivityFeedPage.fromJson(_asMap(response));
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<ActivityFeedPage> listDailyActivity(
    AppSession session, {
    DateTime? businessDate,
    int offset = 0,
    int limit = pageSize,
  }) async {
    try {
      final response = await _invoke('list_phase_7_5_daily_activity', {
        'p_business_date': _formatDate(businessDate),
        'p_limit': limit,
        'p_offset': offset,
      });
      return ActivityFeedPage.fromJson(_asMap(response));
    } catch (error) {
      throw _mapError(error);
    }
  }

  static String? _formatDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static Map<String, dynamic> _asMap(Object? response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return response.cast<String, dynamic>();
    throw const FormatException('Expected an object response');
  }

  DashboardException _mapError(Object error) {
    if (error is DashboardException) return error;
    final message = error.toString().toLowerCase();
    if (message.contains(DashboardException.permissionDenied)) {
      return const DashboardException(DashboardException.permissionDenied);
    }
    if (message.contains(DashboardException.timezoneUnconfigured)) {
      return const DashboardException(DashboardException.timezoneUnconfigured);
    }
    if (message.contains(DashboardException.validationFailed)) {
      return const DashboardException(DashboardException.validationFailed);
    }
    return const DashboardException(DashboardException.unavailable);
  }
}
