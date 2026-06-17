import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';

void main() {
  group('VoucherRepository open invoice permissions', () {
    test(
      'customer open invoices allow receipt creators without vouchers.view',
      () {
        final repo = VoucherRepository(null);

        expect(
          () => repo.listOpenCustomerInvoices(
            _session({'vouchers.create_receipt'}),
            'customer-1',
          ),
          throwsA(
            isA<FinanceException>().having(
              (e) => e.code,
              'code',
              FinanceException.supabaseNotConfigured,
            ),
          ),
        );
      },
    );

    test(
      'supplier open invoices allow payment creators without vouchers.view',
      () {
        final repo = VoucherRepository(null);

        expect(
          () => repo.listOpenSupplierInvoices(
            _session({'vouchers.create_payment'}),
            'supplier-1',
          ),
          throwsA(
            isA<FinanceException>().having(
              (e) => e.code,
              'code',
              FinanceException.supabaseNotConfigured,
            ),
          ),
        );
      },
    );

    test('open invoice lists deny users without finance permissions', () {
      final repo = VoucherRepository(null);

      expect(
        () => repo.listOpenCustomerInvoices(_session({}), 'customer-1'),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.permissionDenied,
          ),
        ),
      );
    });
  });
}

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
