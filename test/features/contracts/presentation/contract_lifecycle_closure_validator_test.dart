import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/domain/validators/contract_lifecycle_validator.dart';
import 'package:hs360/features/contracts/domain/closure_draft.dart';
import 'package:hs360/features/contracts/domain/contract_return_condition.dart';

void main() {
  const validator = ContractLifecycleValidator();

  test('validateClosure rejects close date before contract start', () {
    final result = validator.validateClosure(
      ClosureDraft(
        contractId: 'c-1',
        closureType: ContractClosureType.normal,
        closeReason: 'done',
        returnCondition: ContractReturnCondition.availableUsed,
        closeDate: DateTime(2026, 1, 1),
      ),
      contractStartDate: DateTime(2026, 6, 1),
    );

    expect(result.isValid, isFalse);
  });

  test('validateClosure accepts close date on start date', () {
    final result = validator.validateClosure(
      ClosureDraft(
        contractId: 'c-1',
        closureType: ContractClosureType.normal,
        closeReason: 'done',
        returnCondition: ContractReturnCondition.availableUsed,
        closeDate: DateTime(2026, 6, 1),
      ),
      contractStartDate: DateTime(2026, 6, 1),
    );

    expect(result.isValid, isTrue);
  });
}
