import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/services/pdf/blocks/tenant_header_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('tenant header block renders company name row', () {
    final context = testContext(kind: DocumentKind.salesInvoice);
    final ctx = buildPdfContext(context: context);
    final widget = const TenantHeaderBlock().build(ctx);
    expect(widget, isA<pw.Row>());
  });
}
