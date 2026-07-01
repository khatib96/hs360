import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/vouchers/domain/voucher_form_state.dart';
import '../../features/vouchers/domain/voucher_type.dart';
import 'cash_bank_account_validator.dart';
import 'validation_result.dart';

class VoucherValidator {
  const VoucherValidator({
    CashBankAccountValidator? cashBankAccountValidator,
    this.referenceMaxLength = 100,
  }) : _cashBankAccountValidator =
           cashBankAccountValidator ?? const CashBankAccountValidator();

  final CashBankAccountValidator _cashBankAccountValidator;
  final int referenceMaxLength;

  ValidationResult validate(VoucherFormState form) {
    final codes = <String>[];

    codes.addAll(_validateParty(form).codes);
    codes.addAll(_cashBankAccountValidator.validate(form.cashAccountId).codes);

    if (form.amount <= Decimal.zero) {
      codes.add(FinanceException.validationAmountInvalid);
    }

    final reference = form.referenceNo?.trim();
    if (reference != null &&
        reference.isNotEmpty &&
        reference.length > referenceMaxLength) {
      codes.add(FinanceException.validationReferenceTooLong);
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  ValidationResult _validateParty(VoucherFormState form) {
    return switch (form.type) {
      VoucherType.receipt => _validateReceiptParty(form),
      VoucherType.payment => _validatePaymentParty(form),
    };
  }

  ValidationResult _validateReceiptParty(VoucherFormState form) {
    if (form.customerId != null && form.customerId!.trim().isNotEmpty) {
      return const ValidationResult.valid();
    }
    if (form.accountId != null && form.accountId!.trim().isNotEmpty) {
      return const ValidationResult.valid();
    }
    return const ValidationResult(
      codes: [FinanceException.validationAccountRequired],
    );
  }

  ValidationResult _validatePaymentParty(VoucherFormState form) {
    final destination = form.paymentDestination ?? 'supplier';
    if (destination == 'supplier') {
      if (form.supplierId == null || form.supplierId!.trim().isEmpty) {
        return const ValidationResult(
          codes: [FinanceException.validationSupplierRequired],
        );
      }
      return const ValidationResult.valid();
    }
    if (form.accountId == null || form.accountId!.trim().isEmpty) {
      return const ValidationResult(
        codes: [FinanceException.validationAccountRequired],
      );
    }
    return const ValidationResult.valid();
  }
}
