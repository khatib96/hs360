import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/network/supabase_providers.dart';

void main() {
  test('resolveSupabaseConfigStatus returns missingAnonKey when key empty', () {
    // Env.supabaseAnonKey is compile-time; in CI/test without dart-define it is empty.
    expect(
      resolveSupabaseConfigStatus(),
      SupabaseConfigStatus.missingAnonKey,
    );
  });
}
