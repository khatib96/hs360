import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/presentation/invoice_list_controller.dart';

import '../fake_invoice_repository.dart';

AppSession _session({Set<String> permissions = const {'invoices.view_sales'}}) {
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
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

ProviderContainer _container(
  FakeInvoiceRepository repo, {
  Set<String> permissions = const {'invoices.view_sales'},
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(
        () => TestAuthController(_session(permissions: permissions)),
      ),
      invoiceRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
}

void main() {
  group('InvoiceListController', () {
    test('loads sales invoices for permitted user', () async {
      final repo = FakeInvoiceRepository(
        salesInvoices: [sampleInvoiceSummary()],
      );
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(invoiceListControllerProvider.notifier).refresh();

      final state = container.read(invoiceListControllerProvider);
      expect(state.invoices, hasLength(1));
      expect(state.isLoading, isFalse);
      expect(state.errorCode, isNull);
      expect(repo.lastSalesFilters, isNotNull);
    });

    test('fetch error sets error code', () async {
      final repo = FakeInvoiceRepository(
        fetchError: const FinanceException(code: FinanceException.unknown),
      );
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(invoiceListControllerProvider.notifier).refresh();

      expect(
        container.read(invoiceListControllerProvider).errorCode,
        FinanceException.unknown,
      );
    });

    test('denied without view permission yields empty state', () async {
      final repo = FakeInvoiceRepository(
        salesInvoices: [sampleInvoiceSummary()],
      );
      final container = _container(repo, permissions: {});
      addTearDown(container.dispose);

      await container.read(invoiceListControllerProvider.notifier).refresh();

      expect(container.read(invoiceListControllerProvider).invoices, isEmpty);
    });

    test('setType switches to purchase list', () async {
      final repo = FakeInvoiceRepository(
        purchaseInvoices: [
          sampleInvoiceSummary(id: 'pi-1', type: InvoiceType.purchase),
        ],
      );
      final container = _container(
        repo,
        permissions: {'invoices.view_sales', 'invoices.view_purchase'},
      );
      addTearDown(container.dispose);

      final controller = container.read(invoiceListControllerProvider.notifier);
      await controller.refresh();
      controller.setType(InvoiceType.purchase);
      await Future<void>.value();

      expect(repo.lastPurchaseFilters, isNotNull);
      expect(
        container.read(invoiceListControllerProvider).invoices.first.type,
        InvoiceType.purchase,
      );
    });
  });
}
