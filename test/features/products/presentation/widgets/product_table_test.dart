import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/products/presentation/widgets/product_table.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../fake_product_repositories.dart';

void main() {
  Widget wrap(Widget child, {Size size = const Size(1200, 800)}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    );
  }

  final product = sampleProduct();

  testWidgets('shows cost columns when canViewCosts is true', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      wrap(
        ProductTable(
          products: [product],
          stockByProductId: const {},
          groupLabelFor: (_) => 'Group',
          canViewCosts: true,
          canViewStock: false,
          languageCode: 'en',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.productColumnAvgCost), findsOneWidget);
    expect(find.text(l10n.productColumnLastPurchaseCost), findsOneWidget);
    expect(find.text(l10n.productColumnMinSalePrice), findsOneWidget);
  });

  testWidgets('hides cost columns when canViewCosts is false', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      wrap(
        ProductTable(
          products: [product],
          stockByProductId: const {},
          groupLabelFor: (_) => 'Group',
          canViewCosts: false,
          canViewStock: false,
          languageCode: 'en',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.productColumnAvgCost), findsNothing);
    expect(find.text(l10n.productColumnLastPurchaseCost), findsNothing);
    expect(find.text(l10n.productColumnMinSalePrice), findsNothing);
    expect(find.text(l10n.productColumnStock), findsOneWidget);
  });
}
