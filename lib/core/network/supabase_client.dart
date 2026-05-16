import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Wraps Supabase initialization for local dev placeholders only.
abstract final class SupabaseClientProvider {
  static final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient? get clientOrNull {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  /// Initializes Supabase with local placeholder env. Does not block the app
  /// if the local stack is not running yet.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
      _initialized = true;
      _log.i('Supabase client configured for ${Env.supabaseUrl}');
    } catch (e, st) {
      _log.w(
        'Supabase init skipped (local placeholder — start local stack later)',
        error: e,
        stackTrace: st,
      );
    }
  }
}
