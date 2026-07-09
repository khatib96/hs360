import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/contracts/domain/contract_draft.dart';
import '../../features/contracts/domain/contract_type.dart';
import 'serialized_line_validator.dart';
import 'validation_result.dart';

class ContractValidator {
  const ContractValidator({SerializedLineValidator? serializedLineValidator})
    : _serializedLineValidator =
          serializedLineValidator ?? const SerializedLineValidator();

  final SerializedLineValidator _serializedLineValidator;

  ValidationResult validate(
    ContractDraft draft, {
    Map<String, bool> serializedByProductId = const {},
  }) {
    final codes = <String>[];

    if (draft.customerId == null || draft.customerId!.trim().isEmpty) {
      codes.add(FinanceException.validationCustomerRequired);
    }
    if (draft.serviceLocationId == null ||
        draft.serviceLocationId!.trim().isEmpty) {
      codes.add(FinanceException.validationServiceLocationRequired);
    }
    if (draft.assetLines.isEmpty) {
      codes.add(FinanceException.validationAssetLinesRequired);
    }

    for (final line in draft.assetLines) {
      if (line.productId.trim().isEmpty) {
        codes.add(FinanceException.validationProductRequired);
      }
      final isSerialized = serializedByProductId[line.productId] ?? true;
      codes.addAll(
        _serializedLineValidator
            .validateSalesLine(
              qty: Decimal.one,
              isSerialized: isSerialized,
              productUnitId: line.productUnitId,
            )
            .codes,
      );
    }

    for (final line in draft.consumableLines) {
      if (line.productId.trim().isEmpty) {
        codes.add(FinanceException.validationProductRequired);
      }
      if (line.qtyPerRefill <= Decimal.zero) {
        codes.add(FinanceException.validationLineQtyInvalid);
      }
      if (line.refillFrequencyMonths < 1) {
        codes.add(FinanceException.validationLineQtyInvalid);
      }
    }

    if (draft.billingDay != null &&
        (draft.billingDay! < 1 || draft.billingDay! > 28)) {
      codes.add(FinanceException.validationBillingDayInvalid);
    }
    if (draft.refillDay != null &&
        (draft.refillDay! < 1 || draft.refillDay! > 28)) {
      codes.add(FinanceException.validationRefillDayInvalid);
    }

    if (draft.type == ContractType.trial) {
      if (draft.trialDays != null && draft.trialDays! < 1) {
        codes.add(FinanceException.validationTrialEndDateInvalid);
      }
      if (draft.endDate != null && draft.endDate!.isBefore(draft.startDate)) {
        codes.add(FinanceException.validationTrialEndDateInvalid);
      }
    }

    if (draft.type == ContractType.rental) {
      final monthly = draft.monthlyRentalValue;
      if (monthly == null || monthly <= Decimal.zero) {
        codes.add(FinanceException.validationMonthlyRentalInvalid);
      }
      if (draft.requestOverride &&
          (draft.overrideReason == null ||
              draft.overrideReason!.trim().isEmpty)) {
        codes.add(FinanceException.validationOverrideReasonRequired);
      }
      if (draft.endDate != null && draft.endDate!.isBefore(draft.startDate)) {
        codes.add(FinanceException.validationTrialEndDateInvalid);
      }
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
