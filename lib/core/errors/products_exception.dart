import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Product repository failures with stable [code] values.
class ProductsException extends AppException {
  const ProductsException({required super.code, super.technicalDetail});

  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
  static const skuRequired = 'sku_required';
  static const nameArRequired = 'name_ar_required';
  static const nameEnRequired = 'name_en_required';
  static const groupRequired = 'group_required';
  static const conversionFactorInvalid = 'conversion_factor_invalid';
  static const salePriceBelowMin = 'sale_price_below_min';
  static const productModeRequired = 'product_mode_required';
  static const expectedLifespanInvalid = 'expected_lifespan_invalid';
  static const serializedRequiresPiece = 'serialized_requires_piece';
  static const negativeValue = 'negative_value';
  static const invalidDecimal = 'invalid_decimal';
  static const productGroupsPermissionRequired =
      'product_groups_permission_required';
  static const imageTypeInvalid = 'image_type_invalid';
  static const imageTooLarge = 'image_too_large';
  static const fieldNotSupported = 'field_not_supported';
  static const duplicateSku = 'duplicate_sku';
  static const duplicateBarcode = 'duplicate_barcode';
  static const duplicateSerial = 'duplicate_serial';
  static const notSerializedProduct = 'not_serialized_product';
  static const unitNotEditable = 'unit_not_editable';
  static const bulkLimitExceeded = 'bulk_limit_exceeded';
  static const warehouseAgentRequired = 'warehouse_agent_required';
  static const duplicateActiveVanWarehouse = 'duplicate_active_van_warehouse';
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';

  factory ProductsException.fromSupabase(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (error is ProductsException) return error;

    final message = _extractMessage(error).toLowerCase();

    if (message.contains('duplicate') && message.contains('sku')) {
      return ProductsException(code: duplicateSku, technicalDetail: message);
    }
    if (message.contains('duplicate') && message.contains('barcode')) {
      return ProductsException(
        code: duplicateBarcode,
        technicalDetail: message,
      );
    }
    if (message.contains('duplicate_serial')) {
      return ProductsException(code: duplicateSerial, technicalDetail: message);
    }
    if (message.contains('not_serialized_product')) {
      return ProductsException(
        code: notSerializedProduct,
        technicalDetail: message,
      );
    }
    if (message.contains('unit_not_editable')) {
      return ProductsException(code: unitNotEditable, technicalDetail: message);
    }
    if (message.contains('23505') || message.contains('unique')) {
      if (message.contains('ux_warehouses_active_van_agent')) {
        return ProductsException(
          code: duplicateActiveVanWarehouse,
          technicalDetail: message,
        );
      }
      if (message.contains('sku')) {
        return ProductsException(code: duplicateSku, technicalDetail: message);
      }
      if (message.contains('barcode')) {
        return ProductsException(
          code: duplicateBarcode,
          technicalDetail: message,
        );
      }
      if (message.contains('serial')) {
        return ProductsException(
          code: duplicateSerial,
          technicalDetail: message,
        );
      }
    }

    return ProductsException(code: unknown, technicalDetail: message);
  }

  factory ProductsException.notConfigured() {
    return const ProductsException(code: supabaseNotConfigured);
  }

  static String _extractMessage(Object error) {
    if (error is PostgrestException) {
      return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    }
    return error.toString();
  }
}
