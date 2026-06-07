import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/products/domain/product_cost_access.dart';
import 'package:hs360/features/products/domain/product_form_state.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';

AppSession _userSession() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'ar',
    permissions: AppPermissions(
      isManager: false,
      permissions: {'products.view'},
    ),
  );
}

ProductFormState _baseForm({Decimal? avgCost, Decimal? minRentalPrice}) {
  return ProductFormState(
    nameAr: 'اسم',
    nameEn: 'Name',
    groupId: 'g',
    productType: ProductType.saleOnly,
    unitPrimary: UnitOfMeasure.piece,
    avgCost: avgCost,
    minRentalPrice: minRentalPrice,
  );
}

void main() {
  group('validateProductCostWrite', () {
    test('unauthorized user with avgCost gets permission_denied', () {
      final result = validateProductCostWrite(
        _userSession(),
        _baseForm(avgCost: Decimal.one),
      );
      expect(result.isValid, isFalse);
      expect(result.codes, contains(ProductsException.permissionDenied));
    });

    test('any user with minRentalPrice gets field_not_supported', () {
      final managerSession = AppSession(
        userId: 'u',
        email: 'e@test.com',
        tenantId: 't',
        tenantUserId: 'tu',
        accountType: 'manager',
        displayName: 'Test',
        preferredLocale: 'ar',
        permissions: AppPermissions.manager,
      );
      final result = validateProductCostWrite(
        managerSession,
        _baseForm(minRentalPrice: Decimal.one),
      );
      expect(result.isValid, isFalse);
      expect(result.codes, contains(ProductsException.fieldNotSupported));
    });
  });
}
