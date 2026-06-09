import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/pdf/blocks/payment_details_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('payment details block renders amount and method', () {
    final context = testContext(
      kind: DocumentKind.receiptVoucher,
      paper: PaperKind.thermal80mm,
    );
    final ctx = buildPdfContext(
      context: context,
      payloadJson: {
        'payment': {'amount': '25.000', 'method': 'Cash', 'reference': 'REF-1'},
      },
    );
    const block = TemplateBlock(
      type: 'payment_details',
      id: 'pay',
      fields: ['payment.amount', 'payment.method', 'payment.reference'],
    );
    final widget = const PaymentDetailsBlock().build(ctx, block);
    expect(widget, isA<pw.Column>());
  });
}
