import 'package:decimal/decimal.dart';

import '../../../core/documents/domain/document_kind.dart';
import '../../../core/documents/domain/document_payload.dart';

/// Minimal receipt voucher payload for renderer smoke tests.
VoucherPayload receiptVoucherDocumentFixture({
  PaperKind paperKind = PaperKind.a4,
}) {
  return VoucherPayload(
    documentType: DocumentKind.receiptVoucher,
    document: {
      'number': 'RV-00018',
      'date': '2026-06-01',
      'paper_kind': paperKind.value,
    },
    party: {'name_ar': 'عميل تجريبي', 'name_en': 'Sample Customer'},
    payment: {
      'amount': Decimal.parse('150.000'),
      'method': 'Cash',
      'reference': 'REF-001',
      'collected_by': 'Cashier',
    },
  );
}

VoucherPayload thermalReceiptVoucherFixture() {
  return receiptVoucherDocumentFixture(paperKind: PaperKind.thermal80mm);
}
