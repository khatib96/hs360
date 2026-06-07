import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

class ScanException extends AppException {
  const ScanException({required super.code, super.technicalDetail});

  static const permissionDenied = 'permission_denied';
  static const scanNotFound = 'scan_not_found';
  static const scanAmbiguous = 'scan_ambiguous';
  static const validationFailed = 'validation_failed';
  static const tenantNotFound = 'tenant_not_found';
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';

  factory ScanException.notConfigured() {
    return const ScanException(code: supabaseNotConfigured);
  }

  factory ScanException.fromSupabase(Object error, [StackTrace? stackTrace]) {
    if (error is ScanException) return error;

    final message = _extractMessage(error).toLowerCase();

    if (message.contains('scan_ambiguous')) {
      return ScanException(code: scanAmbiguous, technicalDetail: message);
    }
    if (message.contains('scan_not_found')) {
      return ScanException(code: scanNotFound, technicalDetail: message);
    }
    if (message.contains('permission_denied')) {
      return ScanException(code: permissionDenied, technicalDetail: message);
    }
    if (message.contains('tenant_not_found')) {
      return ScanException(code: tenantNotFound, technicalDetail: message);
    }
    if (message.contains('validation_failed')) {
      return ScanException(code: validationFailed, technicalDetail: message);
    }

    return ScanException(code: unknown, technicalDetail: message);
  }

  static String _extractMessage(Object error) {
    if (error is PostgrestException) {
      return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    }
    return error.toString();
  }
}
