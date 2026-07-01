import 'dart:async';

import 'package:decimal/decimal.dart';
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
import 'package:hs360/features/invoices/presentation/invoice_form_draft_builder.dart';
import 'package:hs360/features/invoices/presentation/invoice_form_state.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';

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

Product _product(String id, String price) => Product(
  id: id,
  tenantId: 't',
  sku: id,
  nameAr: id,
  nameEn: id,
  groupId: 'g',
  productType: ProductType.saleOnly,
  canBeSold: true,
  canBeRented: false,
  unitPrimary: UnitOfMeasure.piece,
  conversionFactor: Decimal.one,
  salePrice: Decimal.parse(price),
  isSerialized: false,
  trackableForMaintenance: false,
  isActive: true,
);

InvoiceFormLineUiState _line(String price, String qty) =>
    InvoiceFormLineUiState(
      product: _product('p-$price', price),
      qty: Decimal.parse(qty),
      unitPrice: Decimal.parse(price),
    );

ProviderContainer _container(FakeInvoiceRepository repo) {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(
        () => _Auth(
          AppSession(
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
          ),
        ),
      ),
      invoiceRepositoryProvider.overrideWith((ref) => repo),
      warehouseRepositoryProvider.overrideWith((ref) => _FakeWarehouseRepo()),
    ],
  );
  return container;
}

void main() {
  group('computeEstimateTotals does not throw on invalid lines', () {
    test('cleared / zero qty line is ignored, no crash', () {
      final totals = computeEstimateTotals(
        lines: [_line('85', '0')],
        decimalPlaces: 3,
        taxEnabled: false,
      );
      expect(totals, isNull);
    });

    test('negative qty line is ignored, no crash', () {
      final totals = computeEstimateTotals(
        lines: [_line('85', '-3')],
        decimalPlaces: 3,
        taxEnabled: false,
      );
      expect(totals, isNull);
    });

    test('out-of-range discount line is ignored, no crash', () {
      final totals = computeEstimateTotals(
        lines: [
          InvoiceFormLineUiState(
            product: _product('p', '85'),
            qty: Decimal.fromInt(2),
            unitPrice: Decimal.parse('85'),
            discountPct: Decimal.fromInt(150),
          ),
        ],
        decimalPlaces: 3,
        taxEnabled: false,
      );
      expect(totals, isNull);
    });

    test('totals still calculate for valid remaining lines', () {
      final totals = computeEstimateTotals(
        lines: [_line('85', '2'), _line('45', '0')],
        decimalPlaces: 3,
        taxEnabled: false,
      );
      expect(totals, isNotNull);
      expect(totals!.subtotal, Decimal.fromInt(170));
      expect(totals.total, Decimal.fromInt(170));
    });

    test('safe form ignores trailing empty entry line', () {
      final form = buildSafeInvoiceFormState(
        type: InvoiceType.sales,
        invoiceId: null,
        customerId: null,
        supplierId: null,
        cashAccountId: 'cash-1',
        warehouseId: 'warehouse-1',
        date: DateTime(2026, 6, 26),
        dueDate: null,
        notes: null,
        lines: [_line('60', '1'), InvoiceFormLineUiState()],
      );

      expect(form.draft.lines, hasLength(1));
      expect(form.draft.lines.single.productId, 'p-60');
      expect(form.draft.lines.single.lineOrder, 1);
    });
  });

  group('InvoiceFormController editing does not crash', () {
    test('clearing qty to zero keeps computedEstimateTotals safe', () {
      final container = _container(FakeInvoiceRepository());
      addTearDown(container.dispose);
      final controller = container.read(
        invoiceFormControllerProvider(InvoiceType.sales).notifier,
      );

      controller.selectProduct(0, _product('p1', '85'));
      controller.setLineQty(0, Decimal.fromInt(2));
      expect(
        container
            .read(invoiceFormControllerProvider(InvoiceType.sales))
            .computedEstimateTotals!
            .subtotal,
        Decimal.fromInt(170),
      );

      controller.setLineQty(0, Decimal.zero);
      expect(
        container
            .read(invoiceFormControllerProvider(InvoiceType.sales))
            .computedEstimateTotals,
        isNull,
      );
    });

    test('deleting a line does not crash and removes its state', () {
      final container = _container(FakeInvoiceRepository());
      addTearDown(container.dispose);
      final controller = container.read(
        invoiceFormControllerProvider(InvoiceType.sales).notifier,
      );

      controller.selectProduct(0, _product('p1', '85'));
      controller.setLineQty(0, Decimal.fromInt(2));
      controller.addLine();
      controller.selectProduct(1, _product('p2', '45'));
      controller.setLineQty(1, Decimal.zero);

      controller.removeLine(1);
      final state = container.read(
        invoiceFormControllerProvider(InvoiceType.sales),
      );
      expect(state.lines.length, 1);
      expect(state.computedEstimateTotals!.subtotal, Decimal.fromInt(170));
    });

    test('confirm with zero qty is rejected by validation', () async {
      final repo = FakeInvoiceRepository();
      final container = _container(repo);
      addTearDown(container.dispose);
      final controller = container.read(
        invoiceFormControllerProvider(InvoiceType.sales).notifier,
      );

      controller.selectProduct(0, _product('p1', '85'));
      controller.setLineQty(0, Decimal.zero);

      final code = await controller.submit();
      expect(code, isNotNull);
      expect(repo.lastRecordForm, isNull);
    });
  });
}
