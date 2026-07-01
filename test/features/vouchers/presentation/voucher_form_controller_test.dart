import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/accounting/domain/chart_account.dart';
import 'package:hs360/features/accounting/data/chart_account_repository.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';
import 'package:hs360/features/suppliers/data/supplier_repository.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';
import 'package:hs360/features/vouchers/domain/voucher_type.dart';
import 'package:hs360/features/vouchers/presentation/voucher_form_controller.dart';

import '../../accounting/fake_chart_account_repository.dart';
import '../../customers/fake_customer_repository.dart';
import '../../suppliers/fake_supplier_repository.dart';
import '../fake_voucher_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

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

List<ChartAccount> _cashChartAccounts() {
  return [
    sampleChartAccount(
      id: 'parent',
      code: '1000',
      type: AccountType.asset,
      nameEn: 'Assets',
    ),
    sampleChartAccount(
      id: 'cash-1',
      code: '1101',
      parentId: 'parent',
      type: AccountType.asset,
      nameEn: 'Cash',
      nameAr: 'نقد',
    ),
    sampleChartAccount(
      id: 'exp-1',
      code: '5000',
      type: AccountType.expense,
      nameEn: 'Expense',
    ),
  ];
}

ProviderContainer _container({
  required VoucherType type,
  required Set<String> permissions,
  FakeVoucherRepository? voucherRepo,
}) {
  final repo = voucherRepo ?? FakeVoucherRepository();
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(
        () => TestAuthController(_session(permissions: permissions)),
      ),
      voucherRepositoryProvider.overrideWith((ref) => repo),
      chartAccountRepositoryProvider.overrideWith(
        (ref) => FakeChartAccountRepository(accounts: _cashChartAccounts()),
      ),
      customerRepositoryProvider.overrideWith(
        (ref) => FakeCustomerRepository(),
      ),
      supplierRepositoryProvider.overrideWith(
        (ref) => FakeSupplierRepository(),
      ),
    ],
  );
}

void main() {
  group('VoucherFormController', () {
    test(
      'submit without cash account returns validation and does not crash',
      () async {
        final repo = FakeVoucherRepository();
        final container = _container(
          type: VoucherType.receipt,
          permissions: {'vouchers.create_receipt', 'chart_of_accounts.view'},
          voucherRepo: repo,
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          voucherFormControllerProvider(VoucherType.receipt).notifier,
        );
        await notifier.loadMeta();
        notifier.selectCustomer(
          sampleCustomer(id: 'cust-1', customerType: CustomerType.individual),
        );
        notifier.setCashAccountId(null);
        notifier.setAmount(Decimal.parse('25.000'));

        final code = await notifier.submit();

        expect(code, FinanceException.validationAccountRequired);
        expect(repo.lastRecordForm, isNull);
      },
    );

    test(
      'fifo receipt submit records form without manual allocations',
      () async {
        final repo = FakeVoucherRepository(
          openCustomerInvoices: [sampleOpenInvoice()],
        );
        final container = _container(
          type: VoucherType.receipt,
          permissions: {'vouchers.create_receipt', 'chart_of_accounts.view'},
          voucherRepo: repo,
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          voucherFormControllerProvider(VoucherType.receipt).notifier,
        );
        await notifier.loadMeta();
        notifier.selectCustomer(
          sampleCustomer(id: 'cust-1', customerType: CustomerType.individual),
        );
        await _waitForOpenInvoices(container, VoucherType.receipt);
        notifier.setCashAccountId('cash-1');
        notifier.setAmount(Decimal.parse('40.000'));
        notifier.setAllocationMode('fifo');

        final code = await notifier.submit();

        expect(code, isNull);
        expect(repo.lastRecordForm?.allocationMode, 'fifo');
        expect(repo.lastRecordForm?.allocations, isEmpty);
      },
    );

    test('direct account receipt records without customer', () async {
      final repo = FakeVoucherRepository();
      final container = _container(
        type: VoucherType.receipt,
        permissions: {'vouchers.create_receipt', 'chart_of_accounts.view'},
        voucherRepo: repo,
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        voucherFormControllerProvider(VoucherType.receipt).notifier,
      );
      await notifier.loadMeta();
      notifier.setCashAccountId('cash-1');
      notifier.setAccountId('exp-1');
      notifier.setAmount(Decimal.parse('15.000'));

      final code = await notifier.submit();

      expect(code, isNull);
      expect(repo.lastRecordForm?.customerId, isNull);
      expect(repo.lastRecordForm?.accountId, 'exp-1');
    });

    test(
      'source account defaults to cash but allows any posting account',
      () async {
        final container = _container(
          type: VoucherType.payment,
          permissions: {'vouchers.create_payment', 'chart_of_accounts.view'},
        );
        addTearDown(container.dispose);

        final notifier = container.read(
          voucherFormControllerProvider(VoucherType.payment).notifier,
        );
        await notifier.loadMeta();

        var state = container.read(
          voucherFormControllerProvider(VoucherType.payment),
        );
        expect(state.form.cashAccountId, 'cash-1');
        expect(
          state.cashBankAccounts.map((account) => account.id),
          contains('exp-1'),
        );

        notifier.setCashAccountId('exp-1');

        state = container.read(
          voucherFormControllerProvider(VoucherType.payment),
        );
        expect(state.form.cashAccountId, 'exp-1');
      },
    );

    test('manual receipt submit includes allocation rows', () async {
      final repo = FakeVoucherRepository(
        openCustomerInvoices: [sampleOpenInvoice(id: 'inv-1')],
      );
      final container = _container(
        type: VoucherType.receipt,
        permissions: {'vouchers.create_receipt', 'chart_of_accounts.view'},
        voucherRepo: repo,
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        voucherFormControllerProvider(VoucherType.receipt).notifier,
      );
      await notifier.loadMeta();
      notifier.selectCustomer(
        sampleCustomer(id: 'cust-1', customerType: CustomerType.individual),
      );
      await _waitForOpenInvoices(container, VoucherType.receipt);
      notifier.setCashAccountId('cash-1');
      notifier.setAmount(Decimal.parse('40.000'));
      notifier.setAllocationMode('manual');
      notifier.updateManualAllocation('inv-1', Decimal.parse('40.000'));

      final code = await notifier.submit();

      expect(code, isNull);
      expect(repo.lastRecordForm?.allocations, hasLength(1));
      expect(repo.lastRecordForm?.allocations.first.invoiceId, 'inv-1');
    });

    test('direct account payment records account destination', () async {
      final repo = FakeVoucherRepository();
      final container = _container(
        type: VoucherType.payment,
        permissions: {'vouchers.create_payment', 'chart_of_accounts.view'},
        voucherRepo: repo,
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        voucherFormControllerProvider(VoucherType.payment).notifier,
      );
      await notifier.loadMeta();
      notifier.setAccountId('exp-1');
      notifier.setCashAccountId('cash-1');
      notifier.setAmount(Decimal.parse('15.000'));

      final code = await notifier.submit();

      expect(code, isNull);
      expect(repo.lastRecordForm?.paymentDestination, 'account');
      expect(repo.lastRecordForm?.accountId, 'exp-1');
      expect(repo.lastRecordForm?.supplierId, isNull);
    });

    test('buildSafeForm without chart access does not throw', () async {
      final container = _container(
        type: VoucherType.receipt,
        permissions: {'vouchers.create_receipt'},
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        voucherFormControllerProvider(VoucherType.receipt).notifier,
      );
      await notifier.loadMeta();

      expect(() => notifier.buildSafeForm(), returnsNormally);
      expect(
        container
            .read(voucherFormControllerProvider(VoucherType.receipt))
            .canLoadCashAccounts,
        isFalse,
      );
    });
  });
}

Future<void> _waitForOpenInvoices(
  ProviderContainer container,
  VoucherType type,
) async {
  for (var i = 0; i < 50; i++) {
    final state = container.read(voucherFormControllerProvider(type));
    if (!state.isLoadingOpenInvoices) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for open invoices');
}
