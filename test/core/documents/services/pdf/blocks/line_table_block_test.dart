import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/pdf/blocks/line_table_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('line table block renders table for statement lines', () {
    final context = testContext(kind: DocumentKind.customerStatement);
    final block = context.template.body.blocks.firstWhere(
      (b) => b.type == 'line_table',
    );
    final ctx = buildPdfContext(
      context: context,
      payloadJson: {
        'lines': [
          {
            'date': '2026-02-01',
            'description': 'Invoice',
            'debit': '50.000',
            'credit': '0.000',
            'balance': '150.000',
          },
        ],
      },
    );
    final widget = const LineTableBlock().build(ctx, block);
    expect(widget, isA<pw.Widget>());
  });

  test('optional columns default visible and explicit false hides them', () {
    final base = testContext(kind: DocumentKind.customerStatement);
    final block = base.template.body.blocks.firstWhere(
      (b) => b.type == 'line_table',
    );

    final defaultContext = buildPdfContext(context: base);
    expect(defaultContext.visibleColumns(block), hasLength(5));

    final hiddenContext = buildPdfContext(
      context: EffectiveDocumentContext(
        template: base.template,
        settings: const {
          'optional_columns_json': {
            'customer_statement': {'line.debit': false, 'line.credit': true},
          },
        },
        currency: base.currency,
        resolvedLogoUrl: base.resolvedLogoUrl,
        companyNames: base.companyNames,
      ),
    );

    expect(hiddenContext.visibleColumns(block).map((column) => column.field), [
      'line.date',
      'line.description',
      'line.credit',
      'line.balance',
    ]);
  });
}
