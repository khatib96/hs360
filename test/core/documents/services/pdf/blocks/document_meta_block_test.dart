import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/pdf/blocks/document_meta_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('document meta block renders invoice number', () {
    final context = testContext(kind: DocumentKind.salesInvoice);
    final ctx = buildPdfContext(
      context: context,
      payloadJson: {
        'document': {
          'number': 'INV-001',
          'date': '2026-06-01',
          'due_date': '2026-06-15',
        },
      },
    );
    const block = TemplateBlock(
      type: 'document_meta',
      id: 'meta',
      fields: ['document.number', 'document.date'],
    );
    final widget = const DocumentMetaBlock().build(ctx, block);
    expect(widget, isA<pw.Column>());
  });

  test('document meta block is empty when all fields missing', () {
    final context = testContext(kind: DocumentKind.salesInvoice);
    final ctx = buildPdfContext(context: context);
    const block = TemplateBlock(
      type: 'document_meta',
      id: 'meta',
      fields: ['document.number'],
    );
    final widget = const DocumentMetaBlock().build(ctx, block);
    expect(widget, isA<pw.SizedBox>());
  });
}
