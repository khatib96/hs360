import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

class DocumentException extends AppException {
  const DocumentException({required super.code, super.technicalDetail});

  static const tenantNotFound = 'tenant_not_found';
  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
  static const noDefaultTemplate = 'no_default_document_template';
  static const unsupportedDocumentType = 'unsupported_document_type';
  static const statementDateRangeInvalid = 'statement_date_range_invalid';
  static const statementRangeTooLarge = 'statement_range_too_large';
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';

  factory DocumentException.fromSupabase(Object error) {
    if (error is DocumentException) return error;
    final message = _extractMessage(error).toLowerCase();
    if (message.contains('tenant_not_found')) {
      return DocumentException(code: tenantNotFound, technicalDetail: message);
    }
    if (message.contains('permission_denied')) {
      return DocumentException(
        code: permissionDenied,
        technicalDetail: message,
      );
    }
    if (message.contains('no_default_document_template')) {
      return DocumentException(
        code: noDefaultTemplate,
        technicalDetail: message,
      );
    }
    if (message.contains('unsupported_document_type')) {
      return DocumentException(
        code: unsupportedDocumentType,
        technicalDetail: message,
      );
    }
    if (message.contains('statement_date_range_invalid')) {
      return DocumentException(
        code: statementDateRangeInvalid,
        technicalDetail: message,
      );
    }
    if (message.contains('statement_range_too_large')) {
      return DocumentException(
        code: statementRangeTooLarge,
        technicalDetail: message,
      );
    }
    if (message.contains('validation_failed')) {
      return DocumentException(
        code: validationFailed,
        technicalDetail: message,
      );
    }
    return DocumentException(code: unknown, technicalDetail: message);
  }

  factory DocumentException.notConfigured() {
    return const DocumentException(code: supabaseNotConfigured);
  }

  static String _extractMessage(Object error) {
    if (error is PostgrestException) {
      return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    }
    return error.toString();
  }
}
