import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/contracts/domain/consumable_change_draft.dart';
import '../../features/contracts/domain/closure_draft.dart';
import '../../features/contracts/domain/rental_collection_draft.dart';
import '../../features/contracts/domain/trial_conversion_draft.dart';
import '../../features/contracts/domain/trial_extension_draft.dart';
import '../../features/contracts/domain/trial_return_draft.dart';
import 'validation_result.dart';

class ContractLifecycleValidator {
  const ContractLifecycleValidator();

  ValidationResult validateConversion(TrialConversionDraft draft) {
    final codes = <String>[];
    if (draft.trialContractId.trim().isEmpty) {
      codes.add(FinanceException.validationFailed);
    }
    if (draft.monthlyRentalValue <= Decimal.zero) {
      codes.add(FinanceException.validationMonthlyRentalInvalid);
    }
    if (draft.requestOverride &&
        (draft.overrideReason == null ||
            draft.overrideReason!.trim().isEmpty)) {
      codes.add(FinanceException.validationOverrideReasonRequired);
    }
    if (draft.billingDay != null &&
        (draft.billingDay! < 1 || draft.billingDay! > 28)) {
      codes.add(FinanceException.validationBillingDayInvalid);
    }
    if (draft.refillDay != null &&
        (draft.refillDay! < 1 || draft.refillDay! > 28)) {
      codes.add(FinanceException.validationRefillDayInvalid);
    }
    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  ValidationResult validateExtension(
    TrialExtensionDraft draft, {
    DateTime? currentTrialEndDate,
  }) {
    final codes = <String>[];
    if (draft.trialContractId.trim().isEmpty) {
      codes.add(FinanceException.validationFailed);
    }
    if (draft.reason.trim().isEmpty) {
      codes.add(FinanceException.validationReasonRequired);
    }
    final currentEnd = currentTrialEndDate == null
        ? null
        : DateTime(
            currentTrialEndDate.year,
            currentTrialEndDate.month,
            currentTrialEndDate.day,
          );
    final nextEnd = DateTime(
      draft.newTrialEndDate.year,
      draft.newTrialEndDate.month,
      draft.newTrialEndDate.day,
    );
    if (currentEnd != null && !nextEnd.isAfter(currentEnd)) {
      codes.add(FinanceException.validationTrialEndDateInvalid);
    }
    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  ValidationResult validateReturn(TrialReturnDraft draft) {
    final codes = <String>[];
    if (draft.trialContractId.trim().isEmpty) {
      codes.add(FinanceException.validationFailed);
    }
    if (draft.reason.trim().isEmpty) {
      codes.add(FinanceException.validationReasonRequired);
    }
    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  ValidationResult validateClosure(
    ClosureDraft draft, {
    DateTime? contractStartDate,
  }) {
    final codes = <String>[];
    if (draft.contractId.trim().isEmpty) {
      codes.add(FinanceException.validationFailed);
    }
    if (draft.closeReason.trim().isEmpty) {
      codes.add(FinanceException.validationReasonRequired);
    }
    final closeDate = draft.closeDate;
    final startDate = contractStartDate == null
        ? null
        : DateTime(
            contractStartDate.year,
            contractStartDate.month,
            contractStartDate.day,
          );
    if (closeDate != null && startDate != null) {
      final normalizedClose = DateTime(
        closeDate.year,
        closeDate.month,
        closeDate.day,
      );
      if (normalizedClose.isBefore(startDate)) {
        codes.add(FinanceException.validationFailed);
      }
    }
    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  ValidationResult validateConsumableChange(
    ConsumableChangeDraft draft, {
    DateTime? contractStartDate,
    DateTime? lineScheduledEffectiveFrom,
  }) {
    final codes = <String>[];
    if (draft.contractId.trim().isEmpty ||
        draft.contractLineId.trim().isEmpty ||
        draft.newProductId.trim().isEmpty) {
      codes.add(FinanceException.validationFailed);
    }
    if (draft.reason.trim().isEmpty) {
      codes.add(FinanceException.validationReasonRequired);
    }
    if (draft.qtyPerRefill <= Decimal.zero) {
      codes.add(FinanceException.validationLineQtyInvalid);
    }
    final today = DateTime.now();
    final effective = DateTime(
      draft.effectiveDate.year,
      draft.effectiveDate.month,
      draft.effectiveDate.day,
    );
    final todayDate = DateTime(today.year, today.month, today.day);
    if (effective.isBefore(todayDate)) {
      codes.add(FinanceException.validationFailed);
    }
    if (contractStartDate != null) {
      final start = DateTime(
        contractStartDate.year,
        contractStartDate.month,
        contractStartDate.day,
      );
      if (effective.isBefore(start)) {
        codes.add(FinanceException.validationFailed);
      }
    }
    if (lineScheduledEffectiveFrom != null) {
      codes.add(FinanceException.consumableScheduleConflict);
    }
    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  ValidationResult validateRentalCollection(RentalCollectionDraft draft) {
    final codes = <String>[];
    if (draft.contractId.trim().isEmpty) {
      codes.add(FinanceException.validationFailed);
    }
    if (draft.cashAccountId.trim().isEmpty) {
      codes.add(FinanceException.validationCashAccountRequired);
    }
    if (draft.amount <= Decimal.zero) {
      codes.add(FinanceException.validationAmountInvalid);
    }
    final hasMonths = draft.coverageMonths.isNotEmpty;
    final hasRange = draft.coverageStart != null && draft.coverageEnd != null;
    if (!hasMonths && !hasRange) {
      codes.add(FinanceException.validationCoverageMonthsRequired);
    }
    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
