import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/domain/transfer_product_option.dart';
import 'package:hs360/features/inventory/domain/transfer_warehouse_option.dart';
import 'package:hs360/features/inventory/presentation/inventory_transfers_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_inventory_repository.dart';

AppSession _session() {
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
      permissions: {'inventory_movements.create'},
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
          data: MediaQuery.of(context).copyWith(size: const Size(1600, 900)),
          child: appChild!,
        );
      },
      home: child,
    ),
  );
}

void main() {
  group('InventoryTransfersScreen', () {
    testWidgets('smoke renders transfer form fields', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrap(const InventoryTransfersScreen(), [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          inventoryRepositoryProvider.overrideWith(
            (ref) => FakeInventoryRepository(
              transferWarehouses: const [
                TransferWarehouseOption(
                  id: 'w1',
                  nameAr: 'رئيسي',
                  nameEn: 'Main',
                  type: 'main',
                ),
                TransferWarehouseOption(
                  id: 'w2',
                  nameAr: 'فرع',
                  nameEn: 'Branch',
                  type: 'branch',
                ),
              ],
            ),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.inventoryTransferTitle), findsWidgets);
      expect(find.text(l10n.inventoryTransferSourceWarehouse), findsOneWidget);
      expect(
        find.text(l10n.inventoryTransferDestinationWarehouse),
        findsOneWidget,
      );
      expect(find.text(l10n.inventoryTransferSelectProduct), findsOneWidget);
    });

    testWidgets('submit without warehouses shows source required', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrap(const InventoryTransfersScreen(), [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          inventoryRepositoryProvider.overrideWith(
            (ref) => FakeInventoryRepository(
              transferWarehouses: const [
                TransferWarehouseOption(
                  id: 'w1',
                  nameAr: 'رئيسي',
                  nameEn: 'Main',
                  type: 'main',
                ),
              ],
            ),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.inventoryTransferTitle),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.inventorySourceWarehouseRequired), findsOneWidget);
    });

    testWidgets('serialized result clears previous product selection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final inventoryRepo = FakeInventoryRepository(
        transferSourceQty: Decimal.fromInt(10),
        transferWarehouses: const [
          TransferWarehouseOption(
            id: 'w1',
            nameAr: 'رئيسي',
            nameEn: 'Main',
            type: 'main',
          ),
          TransferWarehouseOption(
            id: 'w2',
            nameAr: 'فرع',
            nameEn: 'Branch',
            type: 'branch',
          ),
        ],
        transferProducts: const [
          TransferProductOption(
            id: 'p-normal',
            sku: 'NORMAL',
            nameAr: 'عادي',
            nameEn: 'Normal',
            isSerialized: false,
            unitPrimary: 'piece',
          ),
          TransferProductOption(
            id: 'p-ser',
            sku: 'SER',
            nameAr: 'مسلسل',
            nameEn: 'Serialized',
            isSerialized: true,
            unitPrimary: 'piece',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(const InventoryTransfersScreen(), [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          inventoryRepositoryProvider.overrideWith((ref) => inventoryRepo),
        ]),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.enterText(find.byType(TextFormField).first, 'NORMAL');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('NORMAL').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'SER');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('SER').last);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.inventoryErrorSerializedTransferNotSupported),
        findsOneWidget,
      );
      final productField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(productField.controller?.text, isEmpty);
      expect(inventoryRepo.transferCallCount, 0);
    });
  });
}
