import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/products/presentation/widgets/product_list_empty_state.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  testWidgets('shows New Product CTA when canCreateProduct', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: ProductListEmptyState(canCreateProduct: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.productsNew), findsOneWidget);
  });

  testWidgets('hides New Product CTA when cannot create', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: ProductListEmptyState(canCreateProduct: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.productsNew), findsNothing);
    expect(find.text(l10n.productsListEmpty), findsOneWidget);
  });
}
