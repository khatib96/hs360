import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/auth_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../data/auth_repository.dart';
import '../domain/app_permissions.dart';
import '../domain/app_session.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  FutureOr<AppSession?> build() async {
    final session = ref.watch(supabaseSessionProvider);
    if (session == null) return null;
    return ref.read(authRepositoryProvider).loadCurrentAppSession();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithPassword(email: email, password: password);
      return repo.loadCurrentAppSession();
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      return null;
    });
  }

  Future<void> requestPasswordReset({required String email}) async {
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
    } catch (e, st) {
      Error.throwWithStackTrace(
        e is AuthException ? e : AuthException.fromSupabase(e, st),
        st,
      );
    }
  }

  Future<void> refreshSession() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(authRepositoryProvider).loadCurrentAppSession,
    );
  }
}

@Riverpod(keepAlive: true)
AppPermissions? appPermissions(Ref ref) {
  return ref.watch(authControllerProvider).valueOrNull?.permissions;
}
