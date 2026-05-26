import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Inventory RPC and validation failures with stable [code] values.
class InventoryException extends AppException {
  const InventoryException({required super.code, super.technicalDetail});

  static const tenantNotFound = 'tenant_not_found';
  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
  static const insufficientStock = 'insufficient_stock';
  static const serializedAdjustmentNotSupported =
      'serialized_adjustment_not_supported';
  static const warehouseRequired = 'inventory_warehouse_required';
  static const productRequired = 'inventory_product_required';
  static const unknown = 'unknown';

  factory InventoryException.fromSupabase(Object error, [StackTrace? stackTrace]) {
    if (error is InventoryException) return error;

    final message = _extractMessage(error).toLowerCase();

    if (message.contains('tenant_not_found')) {
      return InventoryException(code: tenantNotFound, technicalDetail: message);
    }
    if (message.contains('permission_denied')) {
      return InventoryException(
        code: permissionDenied,
        technicalDetail: message,
      );
    }
    if (message.contains('insufficient_stock')) {
      return InventoryException(
        code: insufficientStock,
        technicalDetail: message,
      );
    }
    if (message.contains('serialized_adjustment_not_supported')) {
      return InventoryException(
        code: serializedAdjustmentNotSupported,
        technicalDetail: message,
      );
    }
    if (message.contains('validation_failed')) {
      return InventoryException(
        code: validationFailed,
        technicalDetail: message,
      );
    }

    return InventoryException(code: unknown, technicalDetail: message);
  }

  static String _extractMessage(Object error) {
    if (error is PostgrestException) return error.message;
    return error.toString();
  }
}
