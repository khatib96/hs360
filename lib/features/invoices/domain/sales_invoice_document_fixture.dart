import 'package:decimal/decimal.dart';

import '../../../core/documents/domain/document_kind.dart';
import '../../../core/documents/domain/document_payload.dart';

/// Minimal sales invoice payload for renderer smoke tests.
InvoicePayload salesInvoiceDocumentFixture() {
  return InvoicePayload(
    documentType: DocumentKind.salesInvoice,
    document: {
      'number': 'SI-00042',
      'date': '2026-06-01',
      'due_date': '2026-06-15',
    },
    party: {
      'name_ar': 'عميل تجريبي',
      'name_en': 'Sample Customer',
      'code': 'C-001',
    },
    lines: [
      {
        'description': 'Diffuser refill service',
        'qty': '2',
        'unit_price': Decimal.parse('12.500'),
        'total': Decimal.parse('25.000'),
      },
      {
        'description': 'Premium fragrance oil',
        'qty': '1',
        'unit_price': Decimal.parse('8.750'),
        'total': Decimal.parse('8.750'),
      },
    ],
    totals: {
      'subtotal': Decimal.parse('33.750'),
      'discount': Decimal.parse('0.000'),
      'tax': Decimal.parse('0.000'),
      'total': Decimal.parse('33.750'),
    },
  );
}
