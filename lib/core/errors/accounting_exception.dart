import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Chart-of-accounts repository failures with stable [code] values.
class AccountingException extends AppException {
  const AccountingException({required super.code, super.technicalDetail});

  static const tenantNotFound = 'tenant_not_found';
  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
  static const codeRequired = 'code_required';
  static const nameArRequired = 'name_ar_required';
  static const nameEnRequired = 'name_en_required';
  static const typeRequired = 'type_required';
  static const parentTypeMismatch = 'parent_type_mismatch';
  static const duplicateCode = 'duplicate_code';
  static const accountProtected = 'account_protected';
  static const accountTypeChangeUnsafe = 'account_type_change_unsafe';
  static const immutableColumn = 'immutable_column';
  static const accountHasActiveChildren = 'account_has_active_children';
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';

  factory AccountingException.fromSupabase(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (error is AccountingException) return error;

    final message = _extractMessage(error).toLowerCase();

    if (message.contains('tenant_not_found')) {
      return AccountingException(code: tenantNotFound, technicalDetail: message);
    }
    if (message.contains('permission_denied')) {
      return AccountingException(
        code: permissionDenied,
        technicalDetail: message,
      );
    }
    if (message.contains('duplicate_code')) {
      return AccountingException(code: duplicateCode, technicalDetail: message);
    }
    if (message.contains('parent_type_mismatch')) {
      return AccountingException(
        code: parentTypeMismatch,
        technicalDetail: message,
      );
    }
    if (message.contains('account_has_active_children')) {
      return AccountingException(
        code: accountHasActiveChildren,
        technicalDetail: message,
      );
    }
    if (message.contains('account_protected')) {
      return AccountingException(code: accountProtected, technicalDetail: message);
    }
    if (message.contains('account_type_change_unsafe')) {
      return AccountingException(
        code: accountTypeChangeUnsafe,
        technicalDetail: message,
      );
    }
    if (message.contains('immutable_column')) {
      return AccountingException(code: immutableColumn, technicalDetail: message);
    }
    if (message.contains('validation_failed')) {
      return AccountingException(
        code: validationFailed,
        technicalDetail: message,
      );
    }

    return AccountingException(code: unknown, technicalDetail: message);
  }

  factory AccountingException.notConfigured() {
    return const AccountingException(code: supabaseNotConfigured);
  }

  static String _extractMessage(Object error) {
    if (error is PostgrestException) {
      return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    }
    return error.toString();
  }
}
