import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/contract_detail.dart';
import 'package:hs360/features/contracts/domain/contract_line.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';
import 'package:hs360/features/contracts/presentation/widgets/contract_consumable_change_dialog.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../products/fake_product_repositories.dart';
import '../fake_contract_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

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
      permissions: const {'contracts.oil_change', 'contracts.view'},
    ),
  );
}

Product _consumableProduct({required String id, required String nameEn}) {
  return Product(
    id: id,
    tenantId: 't',
    sku: 'OIL-$id',
    nameAr: nameEn,
    nameEn: nameEn,
    groupId: 'g-oil',
    productType: ProductType.consumableRental,
    canBeSold: false,
    canBeRented: true,
    unitPrimary: UnitOfMeasure.ml,
    conversionFactor: Decimal.one,
    salePrice: Decimal.zero,
    isSerialized: false,
    trackableForMaintenance: false,
    isActive: true,
  );
}

ContractDetail _detail({bool scheduled = false}) {
  return ContractDetail(
    id: 'rental-1',
    type: ContractType.rental,
    status: ContractStatus.active,
    startDate: DateTime(2026, 1, 1),
    monthlyRentalValue: Decimal.fromInt(100),
    consumableLines: [
      ContractConsumableLine(
        id: 'line-1',
        productId: 'oil-a',
        productNameEn: 'Oil A',
        qtyPerRefill: Decimal.fromInt(500),
        currentOilProductNameEn: 'Oil A',
        scheduledEffectiveFrom: scheduled ? DateTime(2026, 8, 1) : null,
      ),
    ],
  );
}

class _DialogLauncher extends ConsumerWidget {
  const _DialogLauncher({required this.detail});

  final ContractDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () =>
          showContractConsumableChangeDialog(context, ref, detail: detail),
      child: const Text('open'),
    );
  }
}

Widget _wrap({
  required Widget child,
  required FakeProductRepository productRepo,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuthController(_session())),
      productRepositoryProvider.overrideWith((ref) => productRepo),
      contractRepositoryProvider.overrideWith(
        (ref) => FakeContractRepository(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('scheduled-change banner disables submit', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      _wrap(
        productRepo: FakeProductRepository(),
        child: _DialogLauncher(detail: _detail(scheduled: true)),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.contractConsumableScheduledBanner('2026-08-01')),
      findsOneWidget,
    );
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('consumable-change-submit')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('product picker searches active consumable rental products', (
    tester,
  ) async {
    final productRepo = FakeProductRepository(
      products: [_consumableProduct(id: 'oil-b', nameEn: 'Oil B')],
    );

    await tester.pumpWidget(
      _wrap(
        productRepo: productRepo,
        child: _DialogLauncher(detail: _detail()),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('consumable-change-product-picker')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('consumable-product-search')),
      'Oil',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(productRepo.lastFilters?.productType, ProductType.consumableRental);
    expect(productRepo.lastFilters?.isActive, isTrue);
    expect(find.byKey(const Key('consumable-product-oil-b')), findsOneWidget);
  });
}
