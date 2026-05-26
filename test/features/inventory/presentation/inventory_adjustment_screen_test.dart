import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:decimal/decimal.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/inventory/presentation/inventory_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_inventory_repository.dart';
import '../../products/fake_product_repositories.dart';
import '../fake_warehouse_repository.dart';

AppSession _session({Set<String> permissions = const {'inventory.view'}}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: permissions,
    ),
  );
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

Widget _wrap(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, appChild) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(1600, 900),
          ),
          child: appChild!,
        );
      },
      home: child,
    ),
  );
}

void main() {
  group('InventoryScreen manual adjustment', () {
    testWidgets('hides manual adjustment without create permission', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrap(
          const InventoryScreen(),
          [
            authControllerProvider.overrideWith(
              () => TestAuthController(
                _session(
                  permissions: {
                    'inventory.view',
                    'inventory_movements.view',
                  },
                ),
              ),
            ),
            inventoryRepositoryProvider.overrideWith(
              (ref) => FakeInventoryRepository(),
            ),
            warehouseRepositoryProvider.overrideWith(
              (ref) => FakeWarehouseRepository(),
            ),
            productRepositoryProvider.overrideWith(
              (ref) => FakeProductRepository(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Manual adjustment'), findsNothing);
    });

    testWidgets('shows manual adjustment with create permission', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrap(
          const InventoryScreen(),
          [
            authControllerProvider.overrideWith(
              () => TestAuthController(
                _session(
                  permissions: {
                    'inventory.view',
                    'inventory_movements.create',
                    'products.view',
                    'warehouses.view',
                  },
                ),
              ),
            ),
            inventoryRepositoryProvider.overrideWith(
              (ref) => FakeInventoryRepository(
                balances: [
                  InventoryBalance(
                    id: 'b-1',
                    tenantId: 't',
                    warehouseId: 'wh-1',
                    productId: 'p-1',
                    qtyAvailable: Decimal.fromInt(10),
                    qtyRented: Decimal.zero,
                    qtyTrial: Decimal.zero,
                    qtyMaintenance: Decimal.zero,
                    qtyDamaged: Decimal.zero,
                  ),
                ],
              ),
            ),
            warehouseRepositoryProvider.overrideWith(
              (ref) => FakeWarehouseRepository(),
            ),
            productRepositoryProvider.overrideWith(
              (ref) => FakeProductRepository(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Manual adjustment'), findsOneWidget);
    });
  });
}
