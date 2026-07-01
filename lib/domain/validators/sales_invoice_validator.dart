import 'package:decimal/decimal.dart';

import '../../core/errors/finance_exception.dart';
import '../../features/invoices/domain/invoice_draft.dart';
import '../../features/invoices/domain/invoice_form_state.dart';
import 'discount_validator.dart';
import 'due_date_validator.dart';
import 'serialized_line_validator.dart';
import 'validation_result.dart';

class SalesInvoiceValidator {
  const SalesInvoiceValidator({
    DueDateValidator? dueDateValidator,
    DiscountValidator? discountValidator,
    SerializedLineValidator? serializedLineValidator,
  }) : _dueDateValidator = dueDateValidator ?? const DueDateValidator(),
       _discountValidator = discountValidator ?? const DiscountValidator(),
       _serializedLineValidator =
           serializedLineValidator ?? const SerializedLineValidator();

  final DueDateValidator _dueDateValidator;
  final DiscountValidator _discountValidator;
  final SerializedLineValidator _serializedLineValidator;

  ValidationResult validate(
    InvoiceFormState form, {
    Map<String, bool> serializedByProductId = const {},
    bool customerRequired = true,
    bool cashAccountRequired = false,
  }) {
    final draft = form.draft;
    final codes = <String>[];

    if (customerRequired &&
        (draft.customerId == null || draft.customerId!.trim().isEmpty)) {
      codes.add(FinanceException.validationCustomerRequired);
    }
    if (cashAccountRequired &&
        (draft.cashAccountId == null || draft.cashAccountId!.trim().isEmpty)) {
      codes.add(FinanceException.validationCashAccountRequired);
    }
    if (draft.warehouseId.trim().isEmpty) {
      codes.add(FinanceException.validationWarehouseRequired);
    }
    if (draft.lines.isEmpty) {
      codes.add(FinanceException.validationLinesRequired);
    }

    codes.addAll(
      _dueDateValidator
          .validate(invoiceDate: draft.date, dueDate: draft.dueDate)
          .codes,
    );

    for (final line in draft.lines) {
      codes.addAll(_validateLine(line, serializedByProductId).codes);
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  ValidationResult _validateLine(
    InvoiceDraftLine line,
    Map<String, bool> serializedByProductId,
  ) {
    final codes = <String>[];
    if (line.productId.trim().isEmpty) {
      codes.add(FinanceException.validationProductRequired);
    }
    if (line.qty <= Decimal.zero) {
      codes.add(FinanceException.validationLineQtyInvalid);
    }
    if (line.unitPrice < Decimal.zero) {
      codes.add(FinanceException.validationLinePriceInvalid);
    }
    codes.addAll(_discountValidator.validate(line.discountPct).codes);
    codes.addAll(
      _serializedLineValidator
          .validateSalesLine(
            qty: line.qty,
            isSerialized: serializedByProductId[line.productId] ?? false,
            productUnitId: line.productUnitId,
          )
          .codes,
    );
    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
