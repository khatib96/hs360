import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/invoices/domain/invoice_detail.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/presentation/invoice_form_mapper.dart';

void main() {
  group('purchaseDetailToInvoiceFormState', () {
    test('maps purchase draft detail into editable form state', () {
      final detail = InvoiceDetail(
        id: 'pi-draft',
        type: InvoiceType.purchase,
        status: InvoiceStatus.draft,
        date: DateTime(2026, 6, 1),
        supplier: const PartyReference(
          supplierId: 'sup-1',
          nameAr: 'مورد',
          nameEn: 'Supplier',
        ),
        warehouse: const InvoiceWarehouseRef(
          id: 'wh-1',
          nameAr: 'مستودع',
          nameEn: 'Warehouse',
        ),
        notes: 'note',
        subtotal: Decimal.parse('10'),
        discountAmount: Decimal.zero,
        taxAmount: Decimal.zero,
        total: Decimal.parse('10'),
        paidAmount: Decimal.zero,
        outstanding: Decimal.parse('10'),
        lines: const [],
      );

      final form = purchaseDetailToInvoiceFormState(detail);

      expect(form.draft.invoiceId, 'pi-draft');
      expect(form.draft.supplierId, 'sup-1');
      expect(form.draft.warehouseId, 'wh-1');
      expect(form.draft.notes, 'note');
    });
  });

  group('estimateReturnLineCredit', () {
    test('uses frozen unit price and discount', () {
      final credit = estimateReturnLineCredit(
        ReturnableLineEstimateInput(
          qty: Decimal.parse('2'),
          unitPrice: Decimal.parse('100'),
          discountPct: Decimal.parse('10'),
        ),
      );
      expect(credit, Decimal.parse('180'));
    });
  });
}
