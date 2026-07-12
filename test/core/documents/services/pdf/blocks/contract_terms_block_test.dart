import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/services/pdf/blocks/contract_terms_block.dart';

import '../test_render_helpers.dart';

void main() {
  test('contract terms block renders widget', () {
    final context = testContext(kind: DocumentKind.contract);
    final block = context.template.body.blocks.firstWhere(
      (b) => b.type == 'contract_terms',
    );
    final pdfContext = buildPdfContext(
      context: context,
      payloadJson: {
        'document': {
          'start_date': '2026-07-01',
          'end_date': '2027-07-01',
          'billing_day': 5,
        },
      },
    );

    final widget = const ContractTermsBlock().build(pdfContext, block);
    expect(widget, isA<pw.Widget>());
  });
}
