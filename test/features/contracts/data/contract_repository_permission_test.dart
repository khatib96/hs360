import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/contract_draft.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';
import 'package:hs360/features/contracts/domain/rental_collection_draft.dart';
import 'package:hs360/features/finance_shared/domain/payment_method.dart';

AppSession _session(Set<String> permissions) {
  return AppSession(
    userId: 'user-1',
    email: 'user@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tenant-user-1',
    accountType: 'user',
    displayName: 'User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

void main() {
  group('ContractRepository permissions', () {
    final repo = ContractRepository(null);
    final draft = ContractDraft(
      type: ContractType.rental,
      customerId: 'cust-1',
      serviceLocationId: 'loc-1',
      startDate: DateTime(2026, 7, 1),
      monthlyRentalValue: Decimal.parse('100.000'),
      assetLines: const [],
    );
    final collectionDraft = RentalCollectionDraft(
      contractId: 'contract-1',
      date: DateTime(2026, 7, 1),
      amount: Decimal.parse('100.000'),
      paymentMethod: PaymentMethod.cash,
      cashAccountId: 'cash-1',
      coverageMonths: const ['2026-07'],
    );

    test('create denies without contracts.create', () {
      expect(
        () => repo.createRentalContract(_session({}), draft, 'idem-1'),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.permissionDenied,
          ),
        ),
      );
    });

    test('preview collection allows receipt creators', () {
      expect(
        () => repo.previewRentalCollection(
          _session({'vouchers.create_receipt'}),
          collectionDraft,
        ),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.supabaseNotConfigured,
          ),
        ),
      );
    });

    test('collect denies with only vouchers.create_receipt', () {
      expect(
        () => repo.collectRentalPayment(
          _session({'vouchers.create_receipt'}),
          collectionDraft,
          'idem-1',
        ),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.permissionDenied,
          ),
        ),
      );
    });

    test('collect denies with only invoices.create_sales', () {
      expect(
        () => repo.collectRentalPayment(
          _session({'invoices.create_sales'}),
          collectionDraft,
          'idem-1',
        ),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.permissionDenied,
          ),
        ),
      );
    });

    test('collect passes permission gate with both finance permissions', () {
      expect(
        () => repo.collectRentalPayment(
          _session({'vouchers.create_receipt', 'invoices.create_sales'}),
          collectionDraft,
          'idem-1',
        ),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.supabaseNotConfigured,
          ),
        ),
      );
    });
  });
}
