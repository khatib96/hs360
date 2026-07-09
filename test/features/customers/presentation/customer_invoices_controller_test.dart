import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/presentation/customer_invoices_controller.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_summary.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';

import '../../invoices/fake_invoice_repository.dart';

void main() {
  AppSession session({Set<String> permissions = const {}}) {
    return AppSession(
      userId: 'user-1',
      email: 'test@example.com',
      tenantId: 'tenant-1',
      tenantUserId: 'tu-1',
      accountType: 'user',
      displayName: 'Test User',
      preferredLocale: 'en',
      permissions: AppPermissions(isManager: false, permissions: permissions),
    );
  }

  ProviderContainer container({
    required FakeInvoiceRepository repo,
    required AppSession appSession,
  }) {
    return ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(appSession),
        ),
        invoiceRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
  }

  InvoiceSummary sampleInvoice() {
    return InvoiceSummary(
      id: 'inv-1',
      invoiceNumber: 'SI-001',
      type: InvoiceType.sales,
      status: InvoiceStatus.confirmed,
      date: DateTime(2026, 6, 1),
      party: const PartyReference(
        customerId: 'cust-1',
        nameAr: 'عميل',
        nameEn: 'Customer',
      ),
      total: Decimal.parse('100'),
    );
  }

  test('load uses sales invoices scoped to customer', () async {
    final repo = FakeInvoiceRepository(salesInvoices: [sampleInvoice()]);
    final c = container(
      repo: repo,
      appSession: session(permissions: {'invoices.view_sales'}),
    );
    addTearDown(c.dispose);

    final notifier = c.read(
      customerInvoicesControllerProvider('cust-1').notifier,
    );
    await notifier.load();

    expect(repo.lastSalesFilters?.partyId, 'cust-1');
    expect(
      c.read(customerInvoicesControllerProvider('cust-1')).invoices,
      hasLength(1),
    );
  });

  test('permission denied without sales invoice permission', () async {
    final repo = FakeInvoiceRepository();
    final c = container(repo: repo, appSession: session());
    addTearDown(c.dispose);

    await c.read(customerInvoicesControllerProvider('cust-1').notifier).load();

    expect(repo.lastSalesFilters, isNull);
    final state = c.read(customerInvoicesControllerProvider('cust-1'));
    expect(state.permissionDenied, isTrue);
    expect(state.hasLoaded, isTrue);
  });
}

class _TestAuthController extends AuthController {
  _TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
