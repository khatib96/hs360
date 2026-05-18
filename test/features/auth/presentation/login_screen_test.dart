import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/network/supabase_providers.dart';
import 'package:hs360/features/auth/presentation/login_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    );
  }

  testWidgets(
    'shows config banner and disables sign in when anon key missing',
    (WidgetTester tester) async {
      final l10n = lookupAppLocalizations(const Locale('ar'));

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text(l10n.authMissingAnonKey), findsOneWidget);

      final signInButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l10n.signIn),
      );
      expect(signInButton.onPressed, isNull);
    },
  );

  testWidgets('shows validation errors when fields empty and config ready', (
    WidgetTester tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('ar'));

    await tester.pumpWidget(
      buildTestApp(
        overrides: [
          supabaseConfigStatusProvider.overrideWithValue(
            SupabaseConfigStatus.ready,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final signInButton = find.widgetWithText(FilledButton, l10n.signIn);
    expect(tester.widget<FilledButton>(signInButton).onPressed, isNotNull);

    await tester.ensureVisible(signInButton);
    await tester.pumpAndSettle();
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text(l10n.validationEmailRequired), findsOneWidget);
    expect(find.text(l10n.validationPasswordRequired), findsOneWidget);
  });
}
