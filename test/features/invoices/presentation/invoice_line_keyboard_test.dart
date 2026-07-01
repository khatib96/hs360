import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/warehouse.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/presentation/invoice_form_controller.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';
import 'package:hs360/features/invoices/presentation/widgets/invoice_line_table.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_invoice_repository.dart';

class _Auth extends AuthController {
  _Auth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

class _FakeWarehouseRepo extends WarehouseRepository {
  _FakeWarehouseRepo() : super(null);
  @override
  Future<List<Warehouse>> fetchWarehouses({bool activeOnly = true}) async =>
      const [];
}

Product _product() => Product(
  id: 'p-1',
  tenantId: 't',
  sku: 'SKU-1',
  nameAr: 'منتج',
  nameEn: 'Product',
  groupId: 'g',
  productType: ProductType.saleOnly,
  canBeSold: true,
  canBeRented: false,
  unitPrimary: UnitOfMeasure.piece,
  conversionFactor: Decimal.one,
  salePrice: Decimal.parse('10'),
  isSerialized: false,
  trackableForMaintenance: false,
  isActive: true,
);

AppSession _session() => AppSession(
  userId: 'u',
  email: 'e@test.com',
  tenantId: 't',
  tenantUserId: 'tu',
  accountType: 'user',
  displayName: 'Test',
  preferredLocale: 'en',
  permissions: AppPermissions(
    isManager: false,
    permissions: {'invoices.create_sales'},
  ),
);

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => _Auth(_session())),
      invoiceRepositoryProvider.overrideWith((ref) => FakeInvoiceRepository()),
      warehouseRepositoryProvider.overrideWith((ref) => _FakeWarehouseRepo()),
    ],
  );
}

void main() {
  group('InvoiceFormController keyboard line advance', () {
    late ProviderContainer container;

    setUp(() async {
      container = _container();
      final notifier = container.read(
        invoiceFormControllerProvider(InvoiceType.sales).notifier,
      );
      await notifier.loadMeta();
    });

    tearDown(() {
      container.dispose();
    });

    test('addLineAndFocusProduct adds a line and requests product focus', () {
      final controller = container.read(
        invoiceFormControllerProvider(InvoiceType.sales).notifier,
      );
      controller.addLineAndFocusProduct();
      final state = container.read(
        invoiceFormControllerProvider(InvoiceType.sales),
      );
      expect(state.lines.length, 2);
      expect(state.productFocusRequestIndex, 1);
    });

    test('selectProduct with advanceLine on last line adds a new line', () {
      final controller = container.read(
        invoiceFormControllerProvider(InvoiceType.sales).notifier,
      );
      controller.selectProduct(0, _product(), advanceLine: true);
      final state = container.read(
        invoiceFormControllerProvider(InvoiceType.sales),
      );
      expect(state.lines.length, 2);
      expect(state.productFocusRequestIndex, 1);
    });

    test('selectProduct advanceLine preserves qty on the completed line', () {
      final controller = container.read(
        invoiceFormControllerProvider(InvoiceType.sales).notifier,
      );
      controller.selectProduct(0, _product());
      controller.setLineQty(0, Decimal.fromInt(3));
      controller.setLineUnitPrice(0, Decimal.parse('12.5'));

      var state = container.read(
        invoiceFormControllerProvider(InvoiceType.sales),
      );
      expect(state.lines.first.qty, Decimal.fromInt(3));

      controller.selectProduct(0, _product(), advanceLine: true);

      state = container.read(invoiceFormControllerProvider(InvoiceType.sales));
      expect(state.lines.length, 2);
      expect(state.lines.first.qty, Decimal.fromInt(3));
      expect(state.lines.first.unitPrice, Decimal.parse('10'));
      expect(state.productFocusRequestIndex, 1);
    });
  });

  testWidgets('Enter on last line discount adds a line and focuses product cell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _container();
    addTearDown(container.dispose);

    final controller = container.read(
      invoiceFormControllerProvider(InvoiceType.sales).notifier,
    );
    await controller.loadMeta();
    controller.selectProduct(0, _product());
    controller.setLineQty(0, Decimal.fromInt(2));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(
                  invoiceFormControllerProvider(InvoiceType.sales),
                );
                return InvoiceLineTable(
                  invoiceType: InvoiceType.sales,
                  lines: state.lines,
                  languageCode: 'en',
                  decimalPlaces: 3,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final discountField = find.byType(TextField).last;
    await tester.tap(discountField);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    final state = container.read(invoiceFormControllerProvider(InvoiceType.sales));
    expect(state.lines.length, 2);
    expect(state.lines.first.qty, Decimal.fromInt(2));
    expect(state.lines.first.unitPrice, Decimal.parse('10'));

    expect(find.byKey(const Key('invoice-line-product-1')), findsOneWidget);
  });
}
