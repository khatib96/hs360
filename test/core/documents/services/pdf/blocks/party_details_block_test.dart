import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/services/pdf/blocks/party_details_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('renders a bilingual party name once plus the party code', () {
    final context = testContext(kind: DocumentKind.customerStatement);
    final block = context.template.body.blocks.firstWhere(
      (block) => block.type == 'party_details',
    );
    final renderContext = buildPdfContext(
      context: context,
      payloadJson: const {
        'party': {'name_ar': 'عميل', 'name_en': 'Customer', 'code': 'C-001'},
      },
      languageCode: 'bilingual',
    );

    final widget = const PartyDetailsBlock().build(renderContext, block);

    expect(widget, isA<pw.Column>());
    expect((widget as pw.Column).children, hasLength(2));
  });
}
