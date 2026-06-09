import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/pdf/blocks/footer_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('footer block is empty when tenant footer missing', () {
    final context = testContext(kind: DocumentKind.salesInvoice);
    final ctx = buildPdfContext(context: context);
    final widget = const FooterBlock().build(ctx);
    expect(widget, isA<pw.SizedBox>());
  });

  test('footer block renders localized footer text', () {
    final context = testContext(kind: DocumentKind.salesInvoice);
    final ctx = buildPdfContext(
      context: EffectiveDocumentContext(
        template: context.template,
        settings: const {
          'default_language': 'en',
          'footer_json': {'text_en': 'Thank you', 'text_ar': 'شكراً'},
        },
        currency: context.currency,
        resolvedLogoUrl: null,
        companyNames: context.companyNames,
      ),
    );
    final widget = const FooterBlock().build(ctx);
    expect(widget, isA<pw.Padding>());
  });
}
