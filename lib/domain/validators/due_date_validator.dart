import '../../core/errors/finance_exception.dart';
import 'validation_result.dart';

/// Validates invoice due date relative to invoice date.
class DueDateValidator {
  const DueDateValidator();

  ValidationResult validate({
    required DateTime invoiceDate,
    DateTime? dueDate,
  }) {
    if (dueDate == null) return const ValidationResult.valid();

    final invoiceDay = _dateOnly(invoiceDate);
    final dueDay = _dateOnly(dueDate);
    if (dueDay.isBefore(invoiceDay)) {
      return const ValidationResult(
        codes: [FinanceException.validationDueDateBeforeInvoiceDate],
      );
    }
    return const ValidationResult.valid();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
