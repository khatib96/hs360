import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'supabase_client.dart';

part 'supabase_providers.g.dart';

/// Local Supabase configuration state for controlled UI when keys are missing.
enum SupabaseConfigStatus { missingAnonKey, initFailed, ready }

SupabaseConfigStatus resolveSupabaseConfigStatus() {
  if (Env.supabaseAnonKey.isEmpty) {
    return SupabaseConfigStatus.missingAnonKey;
  }
  if (!SupabaseClientProvider.isInitialized) {
    return SupabaseConfigStatus.initFailed;
  }
  return SupabaseConfigStatus.ready;
}

@Riverpod(keepAlive: true)
SupabaseConfigStatus supabaseConfigStatus(Ref ref) {
  return resolveSupabaseConfigStatus();
}

@Riverpod(keepAlive: true)
SupabaseClient? supabaseClient(Ref ref) {
  ref.watch(supabaseConfigStatusProvider);
  return SupabaseClientProvider.clientOrNull;
}

@Riverpod(keepAlive: true)
Stream<AuthState> supabaseAuthChanges(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return const Stream<AuthState>.empty();
  }
  return client.auth.onAuthStateChange;
}

@Riverpod(keepAlive: true)
Session? supabaseSession(Ref ref) {
  ref.watch(supabaseAuthChangesProvider);
  return ref.watch(supabaseClientProvider)?.auth.currentSession;
}
