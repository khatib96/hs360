import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/invoices/domain/invoice_line.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_summary.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/domain/party_credit.dart';
import 'package:hs360/features/invoices/domain/returnable_invoice_line.dart';

void main() {
  group('InvoiceType', () {
    test('round-trips db values', () {
      expect(InvoiceType.sales.toDb(), 'sales');
      expect(InvoiceType.fromDb('purchase_return'), InvoiceType.purchaseReturn);
    });
  });

  group('InvoiceStatus', () {
    test('parses partially_paid', () {
      expect(
        InvoiceStatus.fromDb('partially_paid'),
        InvoiceStatus.partiallyPaid,
      );
    });
  });

  group('InvoiceSummary', () {
    test('parses sales list row with currency metadata', () {
      final summary = InvoiceSummary.fromSalesListRow({
        'id': 'inv-1',
        'invoice_number': 'SI-001',
        'customer_id': 'cust-1',
        'customer_name_ar': 'عميل',
        'customer_name_en': 'Customer',
        'status': 'confirmed',
        'date': '2026-06-01',
        'due_date': '2026-06-15',
        'subtotal': '100.000',
        'discount_amount': '0.000',
        'tax_amount': '15.000',
        'total': '115.000',
        'paid_amount': '50.000',
        'outstanding': '65.000',
        'currency_code': 'KWD',
        'currency_symbol': 'د.ك',
        'currency_decimal_places': 3,
        'cancelled_at': null,
      });

      expect(summary.type, InvoiceType.sales);
      expect(summary.status, InvoiceStatus.confirmed);
      expect(summary.total, Decimal.parse('115.000'));
      expect(summary.currency?.currencyCode, 'KWD');
      expect(summary.party?.customerId, 'cust-1');
    });
  });

  group('InvoiceLine', () {
    test('parses detail line JSON with decimals', () {
      final line = InvoiceLine.fromRpcJson({
        'id': 'line-1',
        'line_order': 1,
        'product_id': 'prod-1',
        'qty': '2.000',
        'unit_price': '10.000',
        'discount_pct': '0.00',
        'gross_amount': '20.000',
        'discount_amount': '0.000',
        'before_tax_amount': '20.000',
        'tax_rate_id': null,
        'tax_rate': '0',
        'tax_class': 'non_taxable',
        'taxable_amount': '0.000',
        'tax_amount': '0.000',
        'after_tax_amount': '20.000',
        'line_total': '20.000',
      });

      expect(line.qty, Decimal.parse('2.000'));
      expect(line.lineTotal, Decimal.parse('20.000'));
    });
  });

  group('ReturnableInvoiceLine', () {
    test('parses returnable qty row', () {
      final line = ReturnableInvoiceLine.fromListRow({
        'original_line_id': 'line-1',
        'line_order': 1,
        'product_id': 'prod-1',
        'product_unit_id': null,
        'original_qty': '5.000',
        'returned_qty': '2.000',
        'returnable_qty': '3.000',
        'unit_price': '10.000',
        'discount_pct': '0.00',
        'cost_price': '6.000',
        'is_serialized': false,
      });

      expect(line.returnableQty, Decimal.parse('3.000'));
    });
  });

  group('PartyCredit', () {
    test('parses available credit row', () {
      final credit = PartyCredit.fromListRow({
        'return_invoice_id': 'ret-1',
        'return_invoice_number': 'SR-001',
        'return_type': 'sales_return',
        'return_date': '2026-06-10',
        'original_invoice_id': 'inv-1',
        'original_invoice_number': 'SI-001',
        'total': '50.000',
        'credit_remaining': '25.000',
      });

      expect(credit.returnType, InvoiceType.salesReturn);
      expect(credit.creditRemaining, Decimal.parse('25.000'));
    });
  });
}
