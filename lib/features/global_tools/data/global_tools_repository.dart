import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../domain/app_notification.dart';
import '../domain/global_search_result.dart';

final globalToolsRepositoryProvider = Provider<GlobalToolsRepository>((ref) {
  return GlobalToolsRepository(ref.watch(supabaseClientProvider));
});

class GlobalToolsException implements Exception {
  const GlobalToolsException(this.code);

  static const notConfigured = 'supabase_not_configured';
  static const permissionDenied = 'permission_denied';
  static const unavailable = 'unavailable';

  final String code;
}

class GlobalToolsRepository {
  GlobalToolsRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw const GlobalToolsException(GlobalToolsException.notConfigured);
    }
    return client;
  }

  Future<List<GlobalSearchResult>> search(
    AppSession session,
    String query, {
    int limitPerGroup = 5,
  }) async {
    if (query.trim().length < 2) return const [];
    try {
      final response = await _requireClient.rpc(
        'global_navigation_search',
        params: {'p_query': query.trim(), 'p_limit_per_group': limitPerGroup},
      );
      final json = Map<String, dynamic>.from(response as Map);
      final rows = json['items'] as List? ?? const [];
      return rows
          .whereType<Map>()
          .map(
            (row) => GlobalSearchResult.fromJson(row.cast<String, dynamic>()),
          )
          .where(
            (item) =>
                item.entityId.isNotEmpty &&
                item.category.isNotEmpty &&
                item.route.startsWith('/'),
          )
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<AppNotificationPage> listNotifications(
    AppSession session, {
    int limit = 30,
    DateTime? before,
  }) async {
    if (!session.isManager && !session.permissions.can('notifications.view')) {
      throw const GlobalToolsException(GlobalToolsException.permissionDenied);
    }
    try {
      final response = await _requireClient.rpc(
        'list_my_in_app_notifications',
        params: {
          'p_limit': limit,
          'p_before': before?.toUtc().toIso8601String(),
        },
      );
      return AppNotificationPage.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<bool> setNotificationRead(
    AppSession session,
    String notificationId, {
    required bool isRead,
  }) async {
    if (!session.isManager && !session.permissions.can('notifications.view')) {
      throw const GlobalToolsException(GlobalToolsException.permissionDenied);
    }
    try {
      final response = await _requireClient.rpc(
        'set_my_in_app_notification_read',
        params: {'p_notification_id': notificationId, 'p_read': isRead},
      );
      return response == true;
    } catch (error) {
      throw _mapError(error);
    }
  }

  GlobalToolsException _mapError(Object error) {
    if (error is GlobalToolsException) return error;
    final message = error.toString().toLowerCase();
    if (message.contains('permission_denied') ||
        message.contains('permission denied')) {
      return const GlobalToolsException(GlobalToolsException.permissionDenied);
    }
    return const GlobalToolsException(GlobalToolsException.unavailable);
  }
}
