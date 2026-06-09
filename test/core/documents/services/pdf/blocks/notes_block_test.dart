import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/pdf/blocks/notes_block.dart';
import 'package:hs360/core/documents/services/pdf/pdf_render_context.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('notes block is empty when payload.notes is null', () {
    final context = testContext(kind: DocumentKind.customerStatement);
    final ctx = PdfRenderContext.fromDto(
      documentType: context.template.documentType.documentType,
      paperKind: context.template.paperKind.value,
      languageCode: 'en',
      templateBodyJson: {
        'schema_version': 1,
        'settings': context.template.body.settings,
        'blocks': context.template.body.blocks
            .map((b) => {'type': b.type, 'id': b.id, 'fields': b.fields})
            .toList(),
      },
      tenantSettings: context.settings,
      companyNames: context.companyNames,
      payloadJson: {'notes': null, 'summary': {}, 'lines': []},
      currencyJson: context.currency,
    );

    final block = context.template.body.blocks.firstWhere(
      (b) => b.type == 'notes',
    );
    final widget = const NotesBlock().build(ctx, block);
    expect(widget, isA<pw.SizedBox>());
  });

  test('notes block renders payload.notes text', () {
    final context = testContext(kind: DocumentKind.customerStatement);
    final ctx = PdfRenderContext.fromDto(
      documentType: context.template.documentType.documentType,
      paperKind: context.template.paperKind.value,
      languageCode: 'en',
      templateBodyJson: {
        'schema_version': 1,
        'settings': context.template.body.settings,
        'blocks': [],
      },
      tenantSettings: context.settings,
      companyNames: context.companyNames,
      payloadJson: {
        'notes': 'Payment terms: Net 30',
        'summary': {},
        'lines': [],
      },
      currencyJson: context.currency,
    );

    final block = const TemplateBlock(
      type: 'notes',
      id: 'notes',
      fields: ['document.notes'],
    );
    final widget = const NotesBlock().build(ctx, block);
    expect(widget, isA<pw.Padding>());
  });
}
