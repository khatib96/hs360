import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/invoices/data/invoice_rpc_mapper.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';

void main() {
  group('invoice_rpc_mapper', () {
    test(
      'cancelReturnInvoiceParams uses SQL return invoice parameter name',
      () {
        final params = cancelReturnInvoiceParams(
          returnInvoiceId: 'ret-1',
          reason: ' Damaged ',
          idempotencyKey: 'idem-1',
        );

        expect(params['p_return_invoice_id'], 'ret-1');
        expect(params['p_invoice_id'], isNull);
        expect(params['p_reason'], 'Damaged');
        expect(params['p_idempotency_key'], 'idem-1');
      },
    );

    test('mapSalesInvoiceDetail parses header, party, and lines', () {
      final detail = mapSalesInvoiceDetail({
        'id': 'inv-1',
        'invoice_number': 'SI-001',
        'status': 'confirmed',
        'customer': {
          'id': 'cust-1',
          'code': 'C001',
          'name_ar': 'عميل',
          'name_en': 'Customer',
          'account_id': 'acct-1',
        },
        'warehouse': {'id': 'wh-1', 'name_ar': 'مخزن', 'name_en': 'Warehouse'},
        'date': '2026-06-01',
        'due_date': '2026-06-15',
        'notes': null,
        'subtotal': '100.000',
        'discount_amount': '0.000',
        'tax_amount': '15.000',
        'total': '115.000',
        'paid_amount': '0.000',
        'outstanding': '115.000',
        'currency': {'code': 'KWD', 'symbol': 'د.ك', 'decimal_places': 3},
        'journal_entry_id': 'je-1',
        'reversal_journal_entry_id': null,
        'confirmed_at': '2026-06-01T10:00:00Z',
        'cancelled_at': null,
        'lines': [
          {
            'id': 'line-1',
            'line_order': 1,
            'product_id': 'prod-1',
            'product_unit_id': null,
            'serial_number': null,
            'description': 'Item',
            'qty': '1.000',
            'unit_price': '100.000',
            'discount_pct': '0.00',
            'gross_amount': '100.000',
            'discount_amount': '0.000',
            'before_tax_amount': '100.000',
            'tax_rate_id': 'tax-1',
            'tax_rate': '15.000',
            'tax_class': 'taxable',
            'taxable_amount': '100.000',
            'tax_amount': '15.000',
            'after_tax_amount': '115.000',
            'line_total': '115.000',
            'cost_price': '60.000',
          },
        ],
      });

      expect(detail.type, InvoiceType.sales);
      expect(detail.status, InvoiceStatus.confirmed);
      expect(detail.customer?.customerId, 'cust-1');
      expect(detail.total, Decimal.parse('115.000'));
      expect(detail.lines, hasLength(1));
      expect(detail.lines.first.costPrice, Decimal.parse('60.000'));
    });

    test('mapReturnInvoiceDetail parses credit allocations', () {
      final detail = mapReturnInvoiceDetail({
        'id': 'ret-1',
        'invoice_number': 'SR-001',
        'type': 'sales_return',
        'status': 'confirmed',
        'date': '2026-06-10',
        'return_reason': 'Damaged',
        'notes': null,
        'subtotal': '50.000',
        'discount_amount': '0.000',
        'tax_amount': '0.000',
        'total': '50.000',
        'credit_remaining': '25.000',
        'original_invoice': {
          'id': 'inv-1',
          'invoice_number': 'SI-001',
          'date': '2026-06-01',
          'total': '115.000',
        },
        'customer': {
          'id': 'cust-1',
          'code': 'C001',
          'name_ar': 'عميل',
          'name_en': 'Customer',
        },
        'supplier': null,
        'warehouse': null,
        'currency': {'code': 'KWD', 'symbol': 'د.ك', 'decimal_places': 3},
        'journal_entry_id': 'je-2',
        'reversal_journal_entry_id': null,
        'confirmed_at': '2026-06-10T10:00:00Z',
        'cancelled_at': null,
        'lines': [],
        'credit_allocations': [
          {
            'id': 'alloc-1',
            'allocation_kind': 'invoice',
            'target_invoice_id': 'inv-2',
            'target_invoice_number': 'SI-002',
            'voucher_id': null,
            'voucher_number': null,
            'allocated_amount': '25.000',
            'is_reversed': false,
            'reversed_at': null,
            'created_at': '2026-06-11T10:00:00Z',
          },
        ],
      });

      expect(detail.type, InvoiceType.salesReturn);
      expect(detail.creditRemaining, Decimal.parse('25.000'));
      expect(detail.creditAllocations, hasLength(1));
      expect(detail.originalInvoice?.invoiceNumber, 'SI-001');
    });
  });
}
