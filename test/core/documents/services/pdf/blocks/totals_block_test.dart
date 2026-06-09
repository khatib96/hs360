import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/pdf/blocks/totals_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('totals block renders summary fields', () {
    final context = testContext(kind: DocumentKind.customerStatement);
    final ctx = buildPdfContext(
      context: context,
      payloadJson: {
        'summary': {
          'opening_balance': '100.000',
          'total_debit': '50.000',
          'total_credit': '20.000',
          'closing_balance': '130.000',
        },
      },
    );
    const block = TemplateBlock(
      type: 'totals',
      id: 'totals',
      fields: ['summary.opening_balance', 'summary.closing_balance'],
    );
    final widget = const TotalsBlock().build(ctx, block);
    expect(widget, isA<pw.Column>());
  });
}
