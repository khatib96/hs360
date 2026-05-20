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
  static const rentalPriceRequired = 'rental_price_required';
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
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';

  factory ProductsException.fromSupabase(Object error, [StackTrace? stackTrace]) {
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
    if (message.contains('23505') || message.contains('unique')) {
      if (message.contains('sku')) {
        return ProductsException(code: duplicateSku, technicalDetail: message);
      }
      if (message.contains('barcode')) {
        return ProductsException(
          code: duplicateBarcode,
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
