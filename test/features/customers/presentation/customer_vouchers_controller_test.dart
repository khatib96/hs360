import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/presentation/customer_vouchers_controller.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/finance_shared/domain/payment_method.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';
import 'package:hs360/features/vouchers/domain/voucher_status.dart';
import 'package:hs360/features/vouchers/domain/voucher_summary.dart';
import 'package:hs360/features/vouchers/domain/voucher_type.dart';

import '../../vouchers/fake_voucher_repository.dart';

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
    required FakeVoucherRepository repo,
    required AppSession appSession,
  }) {
    return ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(appSession),
        ),
        voucherRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
  }

  test('load scopes receipt vouchers for customer', () async {
    final repo = FakeVoucherRepository(
      vouchers: [
        sampleVoucherSummary(),
        VoucherSummary(
          id: 'v-pay',
          voucherNumber: 'PV-001',
          type: VoucherType.payment,
          status: VoucherStatus.confirmed,
          date: DateTime(2026, 6, 1),
          amount: Decimal.parse('50.000'),
          paymentMethod: PaymentMethod.cash,
          supplier: const PartyReference(
            supplierId: 'cust-1',
            nameAr: 'مورد',
            nameEn: 'Supplier',
          ),
          allocatedAmount: Decimal.zero,
          unallocatedAmount: Decimal.parse('50.000'),
        ),
      ],
    );
    final c = container(
      repo: repo,
      appSession: session(permissions: {'vouchers.view'}),
    );
    addTearDown(c.dispose);

    await c.read(customerVouchersControllerProvider('cust-1').notifier).load();

    expect(repo.lastFilters?.type, VoucherType.receipt);
    expect(repo.lastFilters?.partyId, 'cust-1');
    expect(
      c.read(customerVouchersControllerProvider('cust-1')).vouchers,
      hasLength(1),
    );
    expect(
      c.read(customerVouchersControllerProvider('cust-1')).vouchers.first.type,
      VoucherType.receipt,
    );
  });
}

class _TestAuthController extends AuthController {
  _TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}
