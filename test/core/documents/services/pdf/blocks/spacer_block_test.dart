import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/pdf/blocks/spacer_block.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('spacer block uses default height when height_mm absent', () {
    final context = testContext(kind: DocumentKind.salesInvoice);
    final ctx = buildPdfContext(context: context);
    const block = TemplateBlock(type: 'spacer', id: 'sp');
    final widget = const SpacerBlock().build(ctx, block);
    expect(widget, isA<pw.SizedBox>());
    expect((widget as pw.SizedBox).height, 4 * PdfPageFormat.mm);
  });

  test('spacer block respects custom height_mm', () {
    final context = testContext(kind: DocumentKind.salesInvoice);
    final ctx = buildPdfContext(context: context);
    const block = TemplateBlock(type: 'spacer', id: 'sp', heightMm: 8);
    final widget = const SpacerBlock().build(ctx, block);
    expect((widget as pw.SizedBox).height, 8 * PdfPageFormat.mm);
  });
}
