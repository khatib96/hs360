import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/products/domain/product_unit.dart';
import 'package:hs360/features/products/domain/product_unit_columns.dart';

AppSession _session(Set<String> permissions) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'ar',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

void main() {
  test('columns omit purchase_cost without full cost permissions', () {
    final session = _session({'product_units.view'});
    expect(ProductUnitColumns.forSession(session), isNot(contains('purchase_cost')));
  });

  test('columns include purchase_cost with all field permissions', () {
    final session = _session({
      'products.field.avg_cost',
      'products.field.last_purchase_cost',
      'products.field.min_sale_price',
      'products.field.min_rental_price',
    });
    expect(ProductUnitColumns.forSession(session), contains('purchase_cost'));
  });

  test('fromRow ignores purchase_cost when key absent', () {
    final unit = ProductUnit.fromRow({
      'id': 'id',
      'tenant_id': 't',
      'product_id': 'p',
      'serial_number': 'S1',
      'status': 'available_new',
      'health_status': 'good',
      'acquired_at': '2026-01-01',
    });
    expect(unit.purchaseCost, isNull);
  });
}
