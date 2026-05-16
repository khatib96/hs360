/// Local development placeholders. No production cloud URLs.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  /// Pass at runtime from `npx supabase status -o env` (do not commit real keys).
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String defaultLocale = 'ar';
}
