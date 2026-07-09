import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/contracts/domain/contract_permissions.dart';

AppSession _session(Set<String> permissions, {bool isManager = false}) {
  return AppSession(
    userId: 'user-1',
    email: 'user@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tenant-user-1',
    accountType: 'user',
    displayName: 'User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: isManager, permissions: permissions),
  );
}

void main() {
  group('contract_permissions', () {
    test('manager bypasses view gate', () {
      expect(canViewContracts(_session({}, isManager: true)), isTrue);
    });

    test('view requires contracts.view', () {
      expect(canViewContracts(_session({})), isFalse);
      expect(canViewContracts(_session({'contracts.view'})), isTrue);
    });

    test('preview collection uses OR gate', () {
      expect(canPreviewRentalCollection(_session({})), isFalse);
      expect(
        canPreviewRentalCollection(_session({'vouchers.create_receipt'})),
        isTrue,
      );
      expect(
        canPreviewRentalCollection(_session({'invoices.view_sales'})),
        isTrue,
      );
    });

    test('collect rental payment uses AND gate', () {
      expect(canCollectRentalPayment(_session({})), isFalse);
      expect(
        canCollectRentalPayment(_session({'vouchers.create_receipt'})),
        isFalse,
      );
      expect(
        canCollectRentalPayment(_session({'invoices.create_sales'})),
        isFalse,
      );
      expect(
        canCollectRentalPayment(
          _session({'vouchers.create_receipt', 'invoices.create_sales'}),
        ),
        isTrue,
      );
    });

    test('field cost permissions are independent', () {
      expect(canViewContractProfit(_session({})), isFalse);
      expect(
        canViewContractProfit(_session({'contracts.field.snapshot_profit'})),
        isTrue,
      );
    });
  });
}
