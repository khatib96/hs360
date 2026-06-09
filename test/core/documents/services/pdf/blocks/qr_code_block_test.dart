import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/pdf/blocks/qr_code_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('qr code block is empty when serial missing', () {
    final context = testContext(kind: DocumentKind.assetTagLabel);
    final ctx = buildPdfContext(context: context);
    const block = TemplateBlock(
      type: 'qr_code',
      id: 'qr',
      payloadField: 'unit.serial',
      captionField: 'unit.serial',
    );
    final widget = const QrCodeBlock().build(ctx, block);
    expect(widget, isA<pw.SizedBox>());
  });

  test('qr code block encodes unit serial', () {
    final context = testContext(kind: DocumentKind.assetTagLabel);
    final ctx = buildPdfContext(
      context: context,
      payloadJson: {
        'unit': {'serial': 'SN-12345'},
      },
    );
    const block = TemplateBlock(
      type: 'qr_code',
      id: 'qr',
      payloadField: 'unit.serial',
      captionField: 'unit.serial',
    );
    final widget = const QrCodeBlock().build(ctx, block);
    expect(widget, isA<pw.Center>());
  });
}
