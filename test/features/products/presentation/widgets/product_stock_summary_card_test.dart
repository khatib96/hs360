import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_stock_summary.dart';
import 'package:hs360/features/products/presentation/widgets/product_stock_summary_card.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../fake_product_repositories.dart';

void main() {
  testWidgets('shows total and per-warehouse rows', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final product = sampleProduct(id: 'p-1');
    final stock = ProductStockSummary(
      productId: 'p-1',
      totalQtyAvailable: Decimal.fromInt(12),
      balances: [
        InventoryBalance(
          id: 'b-1',
          tenantId: 't',
          warehouseId: 'wh-1',
          productId: 'p-1',
          qtyAvailable: Decimal.fromInt(12),
          qtyRented: Decimal.zero,
          qtyTrial: Decimal.zero,
          qtyMaintenance: Decimal.zero,
          qtyDamaged: Decimal.zero,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProductStockSummaryCard(
            stock: stock,
            product: product,
            warehouses: const [],
            languageCode: 'en',
            l10n: l10n,
          ),
        ),
      ),
    );

    expect(find.textContaining('12'), findsWidgets);
    expect(find.text(l10n.productDetailStockByWarehouse), findsOneWidget);
    expect(
      find.textContaining(l10n.inventoryBalanceNameUnavailable),
      findsOneWidget,
    );
  });

  testWidgets('shows low stock warning when below reorder point', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final base = sampleProduct(id: 'p-1');
    final product = Product(
      id: base.id,
      tenantId: base.tenantId,
      sku: base.sku,
      nameAr: base.nameAr,
      nameEn: base.nameEn,
      groupId: base.groupId,
      productType: base.productType,
      canBeSold: base.canBeSold,
      canBeRented: base.canBeRented,
      unitPrimary: base.unitPrimary,
      conversionFactor: base.conversionFactor,
      salePrice: base.salePrice,
      isSerialized: base.isSerialized,
      trackableForMaintenance: base.trackableForMaintenance,
      reorderPoint: Decimal.fromInt(20),
      isActive: base.isActive,
    );
    final stock = ProductStockSummary(
      productId: 'p-1',
      totalQtyAvailable: Decimal.fromInt(5),
      balances: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProductStockSummaryCard(
            stock: stock,
            product: product,
            warehouses: const [],
            languageCode: 'en',
            l10n: l10n,
          ),
        ),
      ),
    );

    expect(find.text(l10n.productDetailStockLowWarning), findsOneWidget);
  });
}
