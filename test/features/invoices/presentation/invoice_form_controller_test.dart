import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/domain/finance/tax_class.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/warehouse.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/invoices/domain/invoice_detail.dart';
import 'package:hs360/features/invoices/domain/invoice_line.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/domain/returnable_invoice_line.dart';
import 'package:hs360/features/invoices/presentation/invoice_form_controller.dart';

import '../fake_invoice_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

class FakeWarehouseRepository extends WarehouseRepository {
  FakeWarehouseRepository() : super(null);

  @override
  Future<List<Warehouse>> fetchWarehouses({bool activeOnly = true}) async =>
      const [];
}

void main() {
  group('InvoiceFormController safe validation', () {
    test('submit with missing party does not crash', () async {
      final repo = FakeInvoiceRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
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
          warehouseRepositoryProvider.overrideWith(
            (ref) => FakeWarehouseRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final code = await container
          .read(invoiceFormControllerProvider(InvoiceType.sales).notifier)
          .submit();

      expect(code, isNotNull);
      expect(repo.lastRecordForm, isNull);
    });
  });

  group('InvoiceFormController linked returns', () {
    test(
      'initializes linked return with returnable quantities selected',
      () async {
        final repo = FakeInvoiceRepository();
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => TestAuthController(
                _session({'invoices.create_sales_return'}),
              ),
            ),
            invoiceRepositoryProvider.overrideWith((ref) => repo),
            warehouseRepositoryProvider.overrideWith(
              (ref) => FakeWarehouseRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          invoiceFormControllerProvider(InvoiceType.salesReturn).notifier,
        );
        await controller.initializeReturn(
          originalInvoiceId: 'inv-1',
          originalDetail: _detailWithLine(),
          returnableLines: [
            ReturnableInvoiceLine(
              originalLineId: 'line-1',
              lineOrder: 1,
              productId: 'prod-1',
              originalQty: Decimal.parse('3.000'),
              returnedQty: Decimal.one,
              returnableQty: Decimal.parse('2.000'),
              unitPrice: Decimal.parse('10.000'),
              discountPct: Decimal.zero,
              costPrice: Decimal.parse('5.000'),
              isSerialized: false,
            ),
          ],
        );

        final state = container.read(
          invoiceFormControllerProvider(InvoiceType.salesReturn),
        );
        expect(state.returnableLines, hasLength(1));
        expect(state.returnDraft?.lines, hasLength(1));
        expect(state.returnDraft?.lines.single.qty, Decimal.parse('2.000'));
      },
    );

    test(
      'falls back to original detail lines when returnable RPC is empty',
      () async {
        final repo = FakeInvoiceRepository();
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => TestAuthController(
                _session({'invoices.create_sales_return'}),
              ),
            ),
            invoiceRepositoryProvider.overrideWith((ref) => repo),
            warehouseRepositoryProvider.overrideWith(
              (ref) => FakeWarehouseRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          invoiceFormControllerProvider(InvoiceType.salesReturn).notifier,
        );
        await controller.initializeReturn(
          originalInvoiceId: 'inv-1',
          originalDetail: _detailWithLine(),
          returnableLines: const [],
        );

        final state = container.read(
          invoiceFormControllerProvider(InvoiceType.salesReturn),
        );
        expect(state.returnableLines, hasLength(1));
        expect(state.returnableLines.single.originalLineId, 'line-1');
        expect(state.returnDraft?.lines.single.qty, Decimal.parse('3.000'));
      },
    );
  });
}

AppSession _session(Set<String> permissions) {
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

InvoiceDetail _detailWithLine() {
  return InvoiceDetail(
    id: 'inv-1',
    invoiceNumber: 'SI-001',
    type: InvoiceType.sales,
    status: InvoiceStatus.confirmed,
    date: DateTime(2026, 6, 26),
    warehouse: const InvoiceWarehouseRef(
      id: 'wh-1',
      nameAr: 'المخزن',
      nameEn: 'Warehouse',
    ),
    subtotal: Decimal.parse('30.000'),
    discountAmount: Decimal.zero,
    taxAmount: Decimal.zero,
    total: Decimal.parse('30.000'),
    paidAmount: Decimal.zero,
    outstanding: Decimal.parse('30.000'),
    lines: [
      InvoiceLine(
        id: 'line-1',
        lineOrder: 1,
        productId: 'prod-1',
        description: 'Product',
        qty: Decimal.parse('3.000'),
        unitPrice: Decimal.parse('10.000'),
        discountPct: Decimal.zero,
        grossAmount: Decimal.parse('30.000'),
        discountAmount: Decimal.zero,
        beforeTaxAmount: Decimal.parse('30.000'),
        taxRate: Decimal.zero,
        taxClass: ProductTaxClass.nonTaxable,
        taxableAmount: Decimal.zero,
        taxAmount: Decimal.zero,
        afterTaxAmount: Decimal.parse('30.000'),
        lineTotal: Decimal.parse('30.000'),
        costPrice: Decimal.parse('5.000'),
      ),
    ],
  );
}
