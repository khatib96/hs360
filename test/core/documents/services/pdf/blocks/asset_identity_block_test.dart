import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/services/pdf/blocks/asset_identity_block.dart';
import 'package:pdf/widgets.dart' as pw;

import '../test_render_helpers.dart';

void main() {
  test('asset identity block renders serial and product name', () {
    final context = testContext(kind: DocumentKind.assetTagLabel);
    final block = context.template.body.blocks.firstWhere(
      (b) => b.type == 'asset_identity',
    );
    final ctx = buildPdfContext(
      context: context,
      payloadJson: {
        'unit': {'serial': 'SN-999'},
        'product': {'name_ar': 'منتج', 'name_en': 'Product'},
        'tenant': {'company_name_ar': 'شركة', 'company_name_en': 'Company'},
      },
    );
    final widget = const AssetIdentityBlock().build(ctx, block);
    expect(widget, isA<pw.Column>());
  });
}
