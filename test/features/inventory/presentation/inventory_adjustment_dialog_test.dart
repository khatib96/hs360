import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/inventory/presentation/widgets/inventory_adjustment_dialog.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_inventory_repository.dart';
import '../fake_warehouse_repository.dart';
import '../../products/fake_product_repositories.dart';

AppSession _session({required Set<String> permissions}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

Widget _wrapDialog({
  required AppSession session,
  FakeInventoryRepository? inventoryRepository,
  FakeProductRepository? productRepository,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(session)),
      inventoryRepositoryProvider.overrideWith(
        (ref) =>
            inventoryRepository ??
            FakeInventoryRepository(
              balances: [
                InventoryBalance(
                  id: 'b-1',
                  tenantId: 't',
                  warehouseId: 'wh-1',
                  productId: 'p-1',
                  qtyAvailable: Decimal.fromInt(5),
                  qtyRented: Decimal.zero,
                  qtyTrial: Decimal.zero,
                  qtyMaintenance: Decimal.zero,
                  qtyDamaged: Decimal.zero,
                ),
              ],
            ),
      ),
      warehouseRepositoryProvider.overrideWith(
        (ref) => FakeWarehouseRepository(warehouses: [sampleWarehouse()]),
      ),
      productRepositoryProvider.overrideWith(
        (ref) =>
            productRepository ??
            FakeProductRepository(
              productById: sampleProduct(
                id: 'p-1',
              ).copyWith(avgCost: Decimal.fromInt(10)),
            ),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: InventoryAdjustmentDialog(
          languageCode: 'en',
          prefillWarehouseId: 'wh-1',
          prefillProductId: 'p-1',
        ),
      ),
    ),
  );
}

void main() {
  group('InventoryAdjustmentDialog cost gates', () {
    testWidgets('hides stock-in option without cost write permission', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDialog(
          session: _session(
            permissions: {'inventory_movements.create', 'products.view'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Adjustment in'), findsNothing);
      expect(find.text('Adjustment out'), findsOneWidget);
    });

    testWidgets('hides unit cost field without cost write permission', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDialog(
          session: _session(
            permissions: {'inventory_movements.create', 'products.view'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unit cost'), findsNothing);
    });

    testWidgets('hides WAC preview without full cost view permission', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapDialog(
          session: _session(
            permissions: {'inventory_movements.create', 'products.view'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '2');
      await tester.pump();

      expect(
        find.textContaining('Estimated average cost after stock-in'),
        findsNothing,
      );
    });
  });
}
