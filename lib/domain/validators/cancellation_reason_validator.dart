import '../../core/errors/finance_exception.dart';
import 'validation_result.dart';

/// Validates non-empty cancellation reason with bounded length.
class CancellationReasonValidator {
  const CancellationReasonValidator({this.maxLength = 500});

  final int maxLength;

  ValidationResult validate(String? reason) {
    final trimmed = reason?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const ValidationResult(
        codes: [FinanceException.validationCancellationReasonRequired],
      );
    }
    if (trimmed.length > maxLength) {
      return const ValidationResult(
        codes: [FinanceException.validationCancellationReasonTooLong],
      );
    }
    return const ValidationResult.valid();
  }
}
