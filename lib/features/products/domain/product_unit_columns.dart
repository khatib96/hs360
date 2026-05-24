import '../../auth/domain/app_session.dart';
import 'product_cost_access.dart';

/// SELECT column lists for [product_units] — cost omitted without permission.
class ProductUnitColumns {
  ProductUnitColumns._();

  static const base =
      'id, tenant_id, product_id, serial_number, barcode, status, '
      'current_warehouse_id, health_status, acquired_at, notes, '
      'created_at, updated_at';

  static const withCost = '$base, purchase_cost';

  static String forSession(AppSession session) {
    return canViewFullProductCosts(session) ? withCost : base;
  }
}
