import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/finance_exception.dart';

/// Resolves a user-facing message for a finance/validation [code].
///
/// Known [FinanceException] codes always map to a specific, translated reason.
/// Only a truly unknown code falls back to the generic message; when a
/// [technicalDetail] is available it is surfaced as a short, diagnostic-safe
/// reference so support can trace the failure without leaking sensitive data.
String financeErrorMessage(
  AppLocalizations l10n,
  String code, {
  String? technicalDetail,
}) {
  return switch (code) {
    FinanceException.tenantNotFound => l10n.financeErrorTenantNotFound,
    FinanceException.permissionDenied => l10n.financeErrorPermissionDenied,
    FinanceException.validationFailed => l10n.financeErrorValidationFailed,
    FinanceException.belowMinProfit => l10n.financeErrorBelowMinProfit,
    FinanceException.manualWarehouseResolutionRequired =>
      l10n.contractErrorManualWarehouseResolutionRequired,
    FinanceException.consumableScheduleConflict =>
      l10n.contractErrorConsumableScheduleConflict,
    FinanceException.idempotencyPayloadMismatch =>
      l10n.financeErrorIdempotencyPayloadMismatch,
    FinanceException.booksLocked => l10n.financeErrorBooksLocked,
    FinanceException.duplicateSerial => l10n.financeErrorDuplicateSerial,
    FinanceException.crossTenantReference =>
      l10n.financeErrorCrossTenantReference,
    FinanceException.taxRateNotFound => l10n.financeErrorTaxRateNotFound,
    FinanceException.taxRateInUse => l10n.financeErrorTaxRateInUse,
    FinanceException.notFound => l10n.financeErrorNotFound,
    FinanceException.notAvailable => l10n.financeErrorNotAvailable,
    FinanceException.insufficientStock => l10n.inventoryErrorInsufficientStock,
    FinanceException.correctionDocumentRequired =>
      l10n.financeErrorCorrectionDocumentRequired,
    FinanceException.returnDocumentRequired =>
      l10n.financeErrorReturnDocumentRequired,
    FinanceException.serializedAdjustmentNotSupported =>
      l10n.financeErrorSerializedAdjustmentNotSupported,
    FinanceException.backendMigrationRequired =>
      l10n.financeErrorBackendMigrationRequired,
    FinanceException.validationCustomerRequired =>
      l10n.financeValidationCustomerRequired,
    FinanceException.validationSupplierRequired =>
      l10n.financeValidationSupplierRequired,
    FinanceException.validationWarehouseRequired =>
      l10n.financeValidationWarehouseRequired,
    FinanceException.validationPartyRequired =>
      l10n.financeValidationPartyRequired,
    FinanceException.validationLinesRequired =>
      l10n.financeValidationLinesRequired,
    FinanceException.validationProductRequired =>
      l10n.financeValidationProductRequired,
    FinanceException.validationLineQtyInvalid =>
      l10n.financeValidationLineQtyInvalid,
    FinanceException.validationLinePriceInvalid =>
      l10n.financeValidationLinePriceInvalid,
    FinanceException.validationDiscountOutOfRange =>
      l10n.financeValidationDiscountOutOfRange,
    FinanceException.validationDueDateBeforeInvoiceDate =>
      l10n.financeValidationDueDateBeforeInvoiceDate,
    FinanceException.validationSerializedUnitRequired =>
      l10n.financeValidationSerializedUnitRequired,
    FinanceException.validationSerialCountMismatch =>
      l10n.financeValidationSerialCountMismatch,
    FinanceException.validationOriginalInvoiceRequired =>
      l10n.financeValidationOriginalInvoiceRequired,
    FinanceException.validationReturnReasonRequired =>
      l10n.financeValidationReturnReasonRequired,
    FinanceException.validationReturnQtyExceedsReturnable =>
      l10n.financeValidationReturnQtyExceedsReturnable,
    FinanceException.validationCashAccountRequired =>
      l10n.financeValidationCashAccountRequired,
    FinanceException.validationAccountRequired =>
      l10n.financeValidationAccountRequired,
    FinanceException.validationCancellationReasonRequired =>
      l10n.financeValidationCancellationReasonRequired,
    FinanceException.validationCancellationReasonTooLong =>
      l10n.financeValidationCancellationReasonTooLong,
    FinanceException.validationNotesRequired =>
      l10n.financeValidationNotesRequired,
    FinanceException.validationGainReasonRequired =>
      l10n.financeValidationGainReasonRequired,
    FinanceException.validationLossReasonRequired =>
      l10n.financeValidationLossReasonRequired,
    FinanceException.validationSerializedNotSupported =>
      l10n.inventoryDocumentSerializedNotSupportedYet,
    FinanceException.validationSerializedQtyIntegerRequired =>
      l10n.financeValidationSerializedQtyIntegerRequired,
    FinanceException.validationServiceLocationRequired =>
      l10n.financeValidationPartyRequired,
    FinanceException.validationAssetLinesRequired =>
      l10n.financeValidationLinesRequired,
    FinanceException.validationMonthlyRentalInvalid =>
      l10n.financeValidationLinePriceInvalid,
    FinanceException.validationBillingDayInvalid =>
      l10n.financeErrorValidationFailed,
    FinanceException.validationRefillDayInvalid =>
      l10n.financeErrorValidationFailed,
    FinanceException.validationOverrideReasonRequired =>
      l10n.financeValidationReturnReasonRequired,
    FinanceException.validationTrialEndDateInvalid =>
      l10n.financeValidationDueDateBeforeInvoiceDate,
    FinanceException.validationReturnConditionRequired =>
      l10n.financeValidationReturnReasonRequired,
    FinanceException.validationClosureTypeRequired =>
      l10n.financeErrorValidationFailed,
    FinanceException.validationCoverageMonthsRequired =>
      l10n.financeValidationLinesRequired,
    FinanceException.supabaseNotConfigured =>
      l10n.authErrorSupabaseNotConfigured,
    _ => _unknownMessage(l10n, code, technicalDetail),
  };
}

String _unknownMessage(
  AppLocalizations l10n,
  String code,
  String? technicalDetail,
) {
  final reference = financeDiagnosticReference(code, technicalDetail);
  if (reference == null) return l10n.financeErrorUnknown;
  return l10n.financeErrorUnknownWithCode(reference);
}

/// Builds a short, diagnostic-safe reference from an unmapped finance error.
///
/// Returns null when there is nothing meaningful to surface (so callers show
/// the plain generic message instead). The output is trimmed, whitespace
/// collapsed and capped so raw backend payloads are never dumped to the UI.
String? financeDiagnosticReference(String code, String? technicalDetail) {
  final source = (technicalDetail == null || technicalDetail.trim().isEmpty)
      ? (code == FinanceException.unknown ? null : code)
      : technicalDetail;
  if (source == null) return null;
  final collapsed = source.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return null;
  return collapsed.length <= 120
      ? collapsed
      : '${collapsed.substring(0, 117)}…';
}

String financeErrorMessages(AppLocalizations l10n, List<String> codes) {
  if (codes.isEmpty) return l10n.financeErrorUnknown;
  return codes.map((code) => financeErrorMessage(l10n, code)).join('\n');
}
