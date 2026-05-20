import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/products/presentation/widgets/product_list_error_state.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  testWidgets('retry invokes callback', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProductListErrorState(
            message: 'Error',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.retry));
    await tester.pump();

    expect(retried, isTrue);
  });
}
