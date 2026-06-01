import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Supplier repository failures with stable [code] values.
class SupplierException extends AppException {
  const SupplierException({required super.code, super.technicalDetail});

  static const tenantNotFound = 'tenant_not_found';
  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
  static const nameArRequired = 'name_ar_required';
  static const emailInvalid = 'email_invalid';
  static const apParentMissing = 'ap_parent_missing';
  static const accountAlreadyLinked = 'account_already_linked';
  static const immutableColumn = 'immutable_column';
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';

  factory SupplierException.fromSupabase(Object error, [StackTrace? stackTrace]) {
    if (error is SupplierException) return error;

    final message = _extractMessage(error).toLowerCase();

    if (message.contains('tenant_not_found')) {
      return SupplierException(code: tenantNotFound, technicalDetail: message);
    }
    if (message.contains('permission_denied')) {
      return SupplierException(code: permissionDenied, technicalDetail: message);
    }
    if (message.contains('ap_parent_missing')) {
      return SupplierException(code: apParentMissing, technicalDetail: message);
    }
    if (message.contains('account_already_linked')) {
      return SupplierException(
        code: accountAlreadyLinked,
        technicalDetail: message,
      );
    }
    if (message.contains('immutable_column')) {
      return SupplierException(code: immutableColumn, technicalDetail: message);
    }
    if (message.contains('validation_failed')) {
      return SupplierException(code: validationFailed, technicalDetail: message);
    }

    return SupplierException(code: unknown, technicalDetail: message);
  }

  factory SupplierException.notConfigured() {
    return const SupplierException(code: supabaseNotConfigured);
  }

  static String _extractMessage(Object error) {
    if (error is PostgrestException) {
      return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    }
    return error.toString();
  }
}
