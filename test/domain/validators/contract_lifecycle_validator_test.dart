import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/domain/validators/contract_lifecycle_validator.dart';
import 'package:hs360/features/contracts/domain/closure_draft.dart';
import 'package:hs360/features/contracts/domain/contract_return_condition.dart';
import 'package:hs360/features/contracts/domain/rental_collection_draft.dart';
import 'package:hs360/features/contracts/domain/trial_conversion_draft.dart';
import 'package:hs360/features/contracts/domain/trial_extension_draft.dart';
import 'package:hs360/features/contracts/domain/trial_return_draft.dart';
import 'package:hs360/features/finance_shared/domain/payment_method.dart';

void main() {
  const validator = ContractLifecycleValidator();

  test('valid conversion passes', () {
    final result = validator.validateConversion(
      TrialConversionDraft(
        trialContractId: 'trial-1',
        monthlyRentalValue: Decimal.fromInt(120),
      ),
    );
    expect(result.isValid, isTrue);
  });

  test('conversion override without reason fails', () {
    final result = validator.validateConversion(
      TrialConversionDraft(
        trialContractId: 'trial-1',
        monthlyRentalValue: Decimal.fromInt(120),
        requestOverride: true,
      ),
    );
    expect(
      result.codes,
      contains(FinanceException.validationOverrideReasonRequired),
    );
  });

  test('extension without reason fails', () {
    final result = validator.validateExtension(
      TrialExtensionDraft(
        trialContractId: 'trial-1',
        newTrialEndDate: DateTime(2026, 8, 1),
        reason: ' ',
      ),
    );
    expect(result.codes, contains(FinanceException.validationReasonRequired));
  });

  test('return without reason fails', () {
    final result = validator.validateReturn(
      const TrialReturnDraft(
        trialContractId: 'trial-1',
        returnCondition: ContractReturnCondition.availableUsed,
        reason: '',
      ),
    );
    expect(result.codes, contains(FinanceException.validationReasonRequired));
  });

  test('closure without reason fails', () {
    final result = validator.validateClosure(
      const ClosureDraft(
        contractId: 'contract-1',
        closureType: ContractClosureType.normal,
        closeReason: '',
        returnCondition: ContractReturnCondition.availableUsed,
      ),
    );
    expect(result.codes, contains(FinanceException.validationReasonRequired));
  });

  test('collection without coverage months fails', () {
    final result = validator.validateRentalCollection(
      RentalCollectionDraft(
        contractId: 'contract-1',
        date: DateTime(2026, 7, 1),
        amount: Decimal.parse('100.000'),
        paymentMethod: PaymentMethod.cash,
        cashAccountId: 'cash-1',
      ),
    );
    expect(
      result.codes,
      contains(FinanceException.validationCoverageMonthsRequired),
    );
  });
}
