import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/accounting/domain/chart_account.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/finance_shared/domain/cash_bank_posting_accounts.dart';

void main() {
  group('filterCashBankPostingAccounts', () {
    ChartAccount account({
      required String id,
      String? code,
      String? parentId,
      AccountType type = AccountType.asset,
      bool isActive = true,
      String? relatedEntityId,
    }) {
      return ChartAccount(
        id: id,
        tenantId: 'tenant-1',
        code: code ?? id,
        nameAr: id,
        nameEn: id,
        type: type,
        parentId: parentId,
        isSubaccount: parentId != null,
        relatedEntityId: relatedEntityId,
        isActive: isActive,
        isSystem: false,
      );
    }

    test('keeps active asset leaf accounts not entity-linked', () {
      final accounts = [
        account(id: 'parent'),
        account(id: 'cash', parentId: 'parent'),
        account(id: 'customer', relatedEntityId: 'cust-1'),
        account(id: 'inactive', isActive: false),
        account(id: 'liability', type: AccountType.liability),
      ];

      final filtered = filterCashBankPostingAccounts(accounts);
      expect(filtered.map((a) => a.id).toList(), ['cash']);
    });

    test('invoice cash accounts are limited to main cash and bank', () {
      final accounts = [
        account(id: 'cash', code: '1101'),
        account(id: 'bank', code: '1102'),
        account(id: 'inventory', code: '1301'),
        account(id: 'tax', code: '1151'),
        account(id: 'customer', code: '1201', relatedEntityId: 'cust-1'),
      ];

      final filtered = filterInvoiceCashBankAccounts(accounts);
      expect(filtered.map((a) => a.code).toList(), ['1101', '1102']);
    });
  });

  group('canLoadCashBankPostingAccounts', () {
    AppSession session(Set<String> permissions) {
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

    test('true when chart_of_accounts.view is granted', () {
      expect(
        canLoadCashBankPostingAccounts(session({'chart_of_accounts.view'})),
        isTrue,
      );
    });

    test('false when only cash_bank.view is granted', () {
      expect(
        canLoadCashBankPostingAccounts(session({'cash_bank.view'})),
        isFalse,
      );
    });
  });
}
