import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../domain/permission_catalog.dart';
import '../domain/tenant_user_account.dart';

typedef UsersRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);
typedef UsersFunctionInvoker =
    Future<dynamic> Function(Map<String, dynamic> body);
typedef PermissionCatalogLoader = Future<List<dynamic>> Function();

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(supabaseClientProvider));
});

class UsersException implements Exception {
  const UsersException(this.code);

  static const notConfigured = 'supabase_not_configured';
  static const permissionDenied = 'permission_denied';
  static const managerRequired = 'manager_required';
  static const permissionNotHeld = 'permission_not_held';
  static const cannotModifySelf = 'cannot_modify_self';
  static const loginTaken = 'login_taken';
  static const weakPassword = 'weak_password';
  static const unavailable = 'unavailable';
  static const unknown = 'unknown';

  static const _known = {
    permissionDenied,
    managerRequired,
    permissionNotHeld,
    cannotModifySelf,
    loginTaken,
    weakPassword,
    'invalid_login',
    'validation_failed',
    'user_not_found',
    'target_is_manager',
    'last_manager',
    'login_not_fresh',
    'login_already_member',
    'tenant_not_found',
    'not_authenticated',
  };

  final String code;

  static UsersException fromCode(String? raw) {
    final value = raw?.trim() ?? '';
    for (final code in _known) {
      if (value == code || value.contains(code)) return UsersException(code);
    }
    return const UsersException(unknown);
  }

  @override
  String toString() => 'UsersException($code)';
}

/// Users & Permissions data access. Membership/permission writes go through
/// RPCs; login creation and passwords go through the `admin-users` function.
class UsersRepository {
  UsersRepository(
    this._client, {
    UsersRpcInvoker? rpcInvoker,
    UsersFunctionInvoker? functionInvoker,
    PermissionCatalogLoader? catalogLoader,
  }) : _rpcInvoker = rpcInvoker,
       _functionInvoker = functionInvoker,
       _catalogLoader = catalogLoader;

  static const functionName = 'admin-users';

  final SupabaseClient? _client;
  final UsersRpcInvoker? _rpcInvoker;
  final UsersFunctionInvoker? _functionInvoker;
  final PermissionCatalogLoader? _catalogLoader;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw const UsersException(UsersException.notConfigured);
    }
    return client;
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    try {
      final invoker = _rpcInvoker;
      if (invoker != null) return await invoker(name, params);
      return await _requireClient.rpc(name, params: params);
    } on UsersException {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const UsersException(UsersException.permissionDenied);
      }
      throw UsersException.fromCode(error.message);
    } catch (error) {
      throw UsersException.fromCode(error.toString());
    }
  }

  Future<void> _function(Map<String, dynamic> body) async {
    try {
      final invoker = _functionInvoker;
      if (invoker != null) {
        await invoker(body);
        return;
      }
      await _requireClient.functions.invoke(functionName, body: body);
    } on UsersException {
      rethrow;
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error']?.toString() : null;
      if (code == null && (error.status == 404 || error.status >= 500)) {
        throw const UsersException(UsersException.unavailable);
      }
      throw UsersException.fromCode(code);
    } catch (error) {
      throw UsersException.fromCode(error.toString());
    }
  }

  Future<List<TenantUserAccount>> listUsers() async {
    final response = await _rpc('list_tenant_users', const {});
    if (response is! List) return const [];
    return [
      for (final row in response)
        if (row is Map)
          TenantUserAccount.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<PermissionCatalogEntry>> loadPermissionCatalog() async {
    try {
      final loader = _catalogLoader;
      final rows = loader != null
          ? await loader()
          : await _requireClient
                .from('permissions')
                .select(
                  'id, category, label_ar, label_en, is_sensitive, sort_order',
                );
      return [
        for (final row in rows)
          if (row is Map)
            PermissionCatalogEntry.fromJson(Map<String, dynamic>.from(row)),
      ];
    } on UsersException {
      rethrow;
    } catch (error) {
      throw UsersException.fromCode(error.toString());
    }
  }

  Future<void> setPermissions(
    String tenantUserId,
    Set<String> permissionIds,
  ) async {
    await _rpc('set_tenant_user_permissions', {
      'p_tenant_user_id': tenantUserId,
      'p_permission_ids': (permissionIds.toList()..sort()),
    });
  }

  Future<void> setActive(String tenantUserId, bool isActive) async {
    await _rpc('set_tenant_user_active', {
      'p_tenant_user_id': tenantUserId,
      'p_is_active': isActive,
    });
  }

  Future<void> createUser({
    required String login,
    required String password,
    required String displayName,
    required bool asManager,
  }) {
    return _function({
      'action': 'create_user',
      'login': login.trim(),
      'password': password,
      'display_name': displayName.trim(),
      'account_type': asManager ? 'manager' : 'user',
    });
  }

  Future<void> resetPassword({
    required String tenantUserId,
    required String password,
  }) {
    return _function({
      'action': 'reset_password',
      'tenant_user_id': tenantUserId,
      'password': password,
    });
  }

  Future<void> changeOwnPassword(String password) {
    return _function({'action': 'change_own_password', 'password': password});
  }
}
