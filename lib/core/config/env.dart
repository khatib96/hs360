/// Local development placeholders. No production cloud URLs.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'local-dev-anon-key-placeholder',
  );

  static const String defaultLocale = 'ar';
}
