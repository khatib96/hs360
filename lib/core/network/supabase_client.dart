import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Wraps Supabase initialization for local development.
abstract final class SupabaseClientProvider {
  static final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient? get clientOrNull {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  /// Initializes Supabase when URL and a public API key are provided.
  /// Does not block the app if the local stack is down or keys are missing.
  static Future<void> initialize() async {
    if (_initialized) return;

    if (Env.supabaseAnonKey.isEmpty) {
      _log.w(
        'Supabase anon key missing. Run with:\n'
        '  flutter run --dart-define=SUPABASE_ANON_KEY=<from supabase status -o env>\n'
        'Or use scripts/run-local.sh / scripts/run-local.ps1',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      _initialized = true;
      _log.i('Supabase client configured for ${Env.supabaseUrl}');
    } catch (e, st) {
      _log.w(
        'Supabase init skipped — is local stack running? (npx supabase start)',
        error: e,
        stackTrace: st,
      );
    }
  }
}
