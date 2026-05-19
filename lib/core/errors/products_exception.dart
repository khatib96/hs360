import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Product repository failures with stable [code] values.
class ProductsException extends AppException {
  const ProductsException({required super.code, super.technicalDetail});

  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
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
