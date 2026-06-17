import '../../core/errors/finance_exception.dart';
import 'validation_result.dart';

/// Validates cash/bank account selection for activity views.
class CashBankAccountValidator {
  const CashBankAccountValidator();

  ValidationResult validate(String? accountId) {
    if (accountId == null || accountId.trim().isEmpty) {
      return const ValidationResult(
        codes: [FinanceException.validationAccountRequired],
      );
    }
    return const ValidationResult.valid();
  }
}
