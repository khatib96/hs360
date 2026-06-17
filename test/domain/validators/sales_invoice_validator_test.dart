import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/domain/validators/sales_invoice_validator.dart';
import 'package:hs360/features/invoices/domain/invoice_draft.dart';
import 'package:hs360/features/invoices/domain/invoice_form_state.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';

void main() {
  group('SalesInvoiceValidator', () {
    const validator = SalesInvoiceValidator();

    test('valid sales draft passes', () {
      final result = validator.validate(
        InvoiceFormState(
          draft: InvoiceDraft(
            type: InvoiceType.sales,
            customerId: 'cust-1',
            warehouseId: 'wh-1',
            date: DateTime(2026, 6, 1),
            dueDate: DateTime(2026, 6, 15),
            lines: [
              InvoiceDraftLine(
                lineOrder: 1,
                productId: 'prod-1',
                qty: Decimal.parse('2'),
                unitPrice: Decimal.parse('10'),
                discountPct: Decimal.zero,
              ),
            ],
          ),
        ),
      );

      expect(result.isValid, isTrue);
    });

    test('missing customer fails with stable code', () {
      final result = validator.validate(
        InvoiceFormState(
          draft: InvoiceDraft(
            type: InvoiceType.sales,
            warehouseId: 'wh-1',
            date: DateTime(2026, 6, 1),
            lines: const [],
          ),
        ),
      );

      expect(
        result.codes,
        contains(FinanceException.validationCustomerRequired),
      );
      expect(result.codes, contains(FinanceException.validationLinesRequired));
    });

    test('due date before invoice date fails', () {
      final result = validator.validate(
        InvoiceFormState(
          draft: InvoiceDraft(
            type: InvoiceType.sales,
            customerId: 'cust-1',
            warehouseId: 'wh-1',
            date: DateTime(2026, 6, 15),
            dueDate: DateTime(2026, 6, 1),
            lines: [
              InvoiceDraftLine(
                lineOrder: 1,
                productId: 'prod-1',
                qty: Decimal.one,
                unitPrice: Decimal.one,
                discountPct: Decimal.zero,
              ),
            ],
          ),
        ),
      );

      expect(
        result.codes,
        contains(FinanceException.validationDueDateBeforeInvoiceDate),
      );
    });

    test('serialized line requires product unit id', () {
      final result = validator.validate(
        InvoiceFormState(
          draft: InvoiceDraft(
            type: InvoiceType.sales,
            customerId: 'cust-1',
            warehouseId: 'wh-1',
            date: DateTime(2026, 6, 1),
            lines: [
              InvoiceDraftLine(
                lineOrder: 1,
                productId: 'prod-serial',
                qty: Decimal.one,
                unitPrice: Decimal.one,
                discountPct: Decimal.zero,
              ),
            ],
          ),
        ),
        serializedByProductId: const {'prod-serial': true},
      );

      expect(
        result.codes,
        contains(FinanceException.validationSerializedUnitRequired),
      );
    });
  });
}
