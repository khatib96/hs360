import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/vouchers/domain/voucher_form_state.dart';
import 'validation_result.dart';

class VoucherAllocationValidator {
  const VoucherAllocationValidator();

  ValidationResult validateManualAllocations({
    required Decimal voucherAmount,
    required List<VoucherAllocationInput> allocations,
  }) {
    if (allocations.isEmpty) {
      return const ValidationResult(
        codes: [FinanceException.validationAllocationInvoiceRequired],
      );
    }

    final codes = <String>[];
    var total = Decimal.zero;

    for (final allocation in allocations) {
      if (allocation.invoiceId.trim().isEmpty) {
        codes.add(FinanceException.validationAllocationInvoiceRequired);
      }
      if (allocation.allocatedAmount <= Decimal.zero) {
        codes.add(FinanceException.validationAmountInvalid);
      }
      total += allocation.allocatedAmount;
    }

    if (total > voucherAmount) {
      codes.add(FinanceException.validationAllocationTotalMismatch);
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
