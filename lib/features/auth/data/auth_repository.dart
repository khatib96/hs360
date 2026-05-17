import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../core/errors/auth_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../domain/app_permissions.dart';
import '../domain/app_session.dart';
import '../domain/tenant_user_profile.dart';
import 'jwt_claims.dart';

part 'auth_repository.g.dart';

const _tenantUserColumns =
    'id, tenant_id, account_type, display_name, preferred_locale, is_active';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw AuthException.notConfigured();
    return client;
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _requireClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e, st) {
      throw AuthException.fromSupabase(e, st);
    }
  }

  Future<void> signOut() async {
    try {
      await _requireClient.auth.signOut();
    } catch (e, st) {
      throw AuthException.fromSupabase(e, st);
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _requireClient.auth.resetPasswordForEmail(email);
    } catch (e, st) {
      throw AuthException.fromSupabase(e, st);
    }
  }

  Future<AppPermissions> loadMyPermissions() async {
    try {
      final response = await _requireClient.rpc('get_my_permissions');
      return AppPermissions.fromRpc(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e, st) {
      throw AuthException.fromSupabase(e, st);
    }
  }

  Future<TenantUserProfile> loadTenantUserProfile(String userId) async {
    try {
      final active = await _requireClient
          .from('tenant_users')
          .select(_tenantUserColumns)
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('joined_at')
          .limit(1)
          .maybeSingle();

      if (active != null) {
        return TenantUserProfile.fromRow(Map<String, dynamic>.from(active));
      }

      final any = await _requireClient
          .from('tenant_users')
          .select(_tenantUserColumns)
          .eq('user_id', userId)
          .order('joined_at')
          .limit(1)
          .maybeSingle();

      if (any == null) {
        throw AuthException.noTenantUser();
      }

      if (any['is_active'] != true) {
        throw AuthException.inactiveTenantUser();
      }

      throw AuthException.noTenantUser();
    } on AuthException {
      rethrow;
    } catch (e, st) {
      throw AuthException.fromSupabase(e, st);
    }
  }

  Future<AppSession?> loadCurrentAppSession() async {
    final client = _client;
    if (client == null) return null;

    final user = client.auth.currentUser;
    if (user == null) return null;

    final session = client.auth.currentSession;
    final Map<String, dynamic> claims = session != null
        ? decodeJwtClaims(session.accessToken)
        : const {};

    final profile = await loadTenantUserProfile(user.id);
    final permissions = await loadMyPermissions();

    final tenantId = _claimString(claims, 'tenant_id') ?? profile.tenantId;
    final tenantUserId =
        _claimString(claims, 'tenant_user_id') ?? profile.tenantUserId;
    final accountType =
        _claimString(claims, 'account_type') ?? profile.accountType;

    return AppSession(
      userId: user.id,
      email: user.email ?? '',
      tenantId: tenantId,
      tenantUserId: tenantUserId,
      accountType: accountType,
      displayName: profile.displayName,
      preferredLocale: profile.preferredLocale,
      permissions: permissions,
    );
  }

  String? _claimString(Map<String, dynamic> claims, String key) {
    final value = claims[key];
    if (value == null) return null;
    return value.toString();
  }
}
