import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Finance repository failures with stable [code] values for localization.
class FinanceException extends AppException {
  const FinanceException({required super.code, super.technicalDetail});

  static const tenantNotFound = 'tenant_not_found';
  static const permissionDenied = 'permission_denied';
  static const validationFailed = 'validation_failed';
  static const idempotencyPayloadMismatch = 'idempotency_payload_mismatch';
  static const booksLocked = 'books_locked';
  static const duplicateSerial = 'duplicate_serial';
  static const crossTenantReference = 'cross_tenant_reference';
  static const taxRateNotFound = 'tax_rate_not_found';
  static const taxRateInUse = 'tax_rate_in_use';
  static const notFound = 'not_found';
  static const notAvailable = 'not_available';
  static const supabaseNotConfigured = 'supabaseNotConfigured';
  static const unknown = 'unknown';

  // Client-side validation codes (finance_validation_*).
  static const validationCustomerRequired =
      'finance_validation_customer_required';
  static const validationSupplierRequired =
      'finance_validation_supplier_required';
  static const validationWarehouseRequired =
      'finance_validation_warehouse_required';
  static const validationLinesRequired = 'finance_validation_lines_required';
  static const validationProductRequired =
      'finance_validation_product_required';
  static const validationLineQtyInvalid = 'finance_validation_line_qty_invalid';
  static const validationLinePriceInvalid =
      'finance_validation_line_price_invalid';
  static const validationDiscountOutOfRange =
      'finance_validation_discount_out_of_range';
  static const validationDueDateBeforeInvoiceDate =
      'finance_validation_due_date_before_invoice_date';
  static const validationSerializedUnitRequired =
      'finance_validation_serialized_unit_required';
  static const validationSerialCountMismatch =
      'finance_validation_serial_count_mismatch';
  static const validationOriginalInvoiceRequired =
      'finance_validation_original_invoice_required';
  static const validationReturnReasonRequired =
      'finance_validation_return_reason_required';
  static const validationReturnQtyExceedsReturnable =
      'finance_validation_return_qty_exceeds_returnable';
  static const validationReasonRequired = 'finance_validation_reason_required';
  static const validationCostRequired = 'finance_validation_cost_required';
  static const validationCountedQtyInvalid =
      'finance_validation_counted_qty_invalid';
  static const validationAmountRequired = 'finance_validation_amount_required';
  static const validationAmountInvalid = 'finance_validation_amount_invalid';
  static const validationCashAccountRequired =
      'finance_validation_cash_account_required';
  static const validationAccountRequired =
      'finance_validation_account_required';
  static const validationPartyRequired = 'finance_validation_party_required';
  static const validationAllocationInvoiceRequired =
      'finance_validation_allocation_invoice_required';
  static const validationAllocationTotalMismatch =
      'finance_validation_allocation_total_mismatch';
  static const validationCancellationReasonRequired =
      'finance_validation_cancellation_reason_required';
  static const validationCancellationReasonTooLong =
      'finance_validation_cancellation_reason_too_long';
  static const validationPaymentDestinationRequired =
      'finance_validation_payment_destination_required';
  static const validationReferenceTooLong =
      'finance_validation_reference_too_long';

  factory FinanceException.fromSupabase(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (error is FinanceException) return error;

    final message = _extractMessage(error).toLowerCase();

    if (message.contains('tenant_not_found')) {
      return FinanceException(code: tenantNotFound, technicalDetail: message);
    }
    if (message.contains('permission_denied')) {
      return FinanceException(code: permissionDenied, technicalDetail: message);
    }
    if (message.contains('idempotency_payload_mismatch')) {
      return FinanceException(
        code: idempotencyPayloadMismatch,
        technicalDetail: message,
      );
    }
    if (message.contains('books_locked')) {
      return FinanceException(code: booksLocked, technicalDetail: message);
    }
    if (message.contains('duplicate_serial')) {
      return FinanceException(code: duplicateSerial, technicalDetail: message);
    }
    if (message.contains('cross_tenant_reference')) {
      return FinanceException(
        code: crossTenantReference,
        technicalDetail: message,
      );
    }
    if (message.contains('tax_rate_not_found')) {
      return FinanceException(code: taxRateNotFound, technicalDetail: message);
    }
    if (message.contains('tax_rate_in_use')) {
      return FinanceException(code: taxRateInUse, technicalDetail: message);
    }
    if (message.contains('validation_failed')) {
      return FinanceException(code: validationFailed, technicalDetail: message);
    }

    return FinanceException(code: unknown, technicalDetail: message);
  }

  factory FinanceException.notConfigured() {
    return const FinanceException(code: supabaseNotConfigured);
  }

  factory FinanceException.unavailable() {
    return const FinanceException(code: notAvailable);
  }

  static String _extractMessage(Object error) {
    if (error is PostgrestException) {
      return '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    }
    return error.toString();
  }
}
