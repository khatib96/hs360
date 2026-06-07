import '../../auth/domain/app_session.dart';
import 'product_cost_access.dart';

/// SELECT column lists for [product_units] — cost omitted without permission.
class ProductUnitColumns {
  ProductUnitColumns._();

  static const base =
      'id, tenant_id, product_id, serial_number, barcode, status, '
      'current_warehouse_id, current_customer_id, current_service_location_id, '
      'health_status, total_maintenance_count, acquired_at, notes, '
      'created_at, updated_at';

  static const withCost = '$base, purchase_cost';

  static String forSession(AppSession session) {
    return canViewFullProductCosts(session) ? withCost : base;
  }
}
