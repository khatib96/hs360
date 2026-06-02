import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Customer repository failures with stable [code] values.
class CustomerException extends AppException {
  const CustomerException({required super.code, super.technicalDetail});

  static const tenantNotFound = 'tenant_not_found';
  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
  static const nameArRequired = 'name_ar_required';
  static const phonePrimaryRequired = 'phone_primary_required';
  static const emailInvalid = 'email_invalid';
  static const arParentMissing = 'ar_parent_missing';
  static const accountAlreadyLinked = 'account_already_linked';
  static const immutableColumn = 'immutable_column';
  static const serviceLocationNameRequired = 'service_location_name_required';
  static const locationInUse = 'location_in_use';
  static const primaryRequired = 'primary_required';
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';

  factory CustomerException.fromSupabase(Object error, [StackTrace? stackTrace]) {
    if (error is CustomerException) return error;

    final message = _extractMessage(error).toLowerCase();

    if (message.contains('tenant_not_found')) {
      return CustomerException(code: tenantNotFound, technicalDetail: message);
    }
    if (message.contains('permission_denied')) {
      return CustomerException(code: permissionDenied, technicalDetail: message);
    }
    if (message.contains('ar_parent_missing')) {
      return CustomerException(code: arParentMissing, technicalDetail: message);
    }
    if (message.contains('account_already_linked')) {
      return CustomerException(
        code: accountAlreadyLinked,
        technicalDetail: message,
      );
    }
    if (message.contains('immutable_column')) {
      return CustomerException(code: immutableColumn, technicalDetail: message);
    }
    if (message.contains('validation_failed')) {
      return CustomerException(code: validationFailed, technicalDetail: message);
    }
    if (message.contains('location_in_use')) {
      return CustomerException(code: locationInUse, technicalDetail: message);
    }
    if (message.contains('primary_required')) {
      return CustomerException(code: primaryRequired, technicalDetail: message);
    }

    return CustomerException(code: unknown, technicalDetail: message);
  }

  factory CustomerException.notConfigured() {
    return const CustomerException(code: supabaseNotConfigured);
  }

  static String _extractMessage(Object error) {
    if (error is PostgrestException) {
      return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    }
    return error.toString();
  }
}
