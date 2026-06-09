import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/services/pdf/blocks/divider_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('divider block renders padded divider', () {
    final context = testContext(kind: DocumentKind.salesInvoice);
    final ctx = buildPdfContext(context: context);
    final widget = const DividerBlock().build(ctx);
    expect(widget, isA<pw.Padding>());
  });
}
