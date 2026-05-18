import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/app.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  testWidgets('HS360 app loads login screen on boot', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l10n.loginTitle), findsOneWidget);
    expect(find.text(l10n.signIn), findsOneWidget);
  });
}
