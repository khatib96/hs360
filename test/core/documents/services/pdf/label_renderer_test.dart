import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/document_render_worker.dart';
import 'package:hs360/core/documents/services/document_template_validator.dart';

import 'test_render_helpers.dart';

AssetLabelPayload _labelPayload() {
  return AssetLabelPayload.fromRpc({
    'unit': {'serial': 'SN-12345'},
    'product': {'name_ar': 'منتج', 'name_en': 'Product'},
    'tenant': {'company_name_ar': 'شركة', 'company_name_en': 'Company'},
  });
}

TemplateBody _insufficientLabelBody() {
  return TemplateBody.fromJson({
    'schema_version': 1,
    'settings': labelSettings(width: 30, height: 12, qrSize: 8),
    'blocks': [
      {'type': 'tenant_header', 'id': 'hdr'},
      {
        'type': 'asset_identity',
        'id': 'idn',
        'fields': ['tenant.company_name_ar', 'unit.serial'],
      },
      {'type': 'qr_code', 'id': 'qr', 'payload_field': 'unit.serial'},
    ],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('label renders horizontal layout with valid geometry', () async {
    final context = testContext(kind: DocumentKind.assetTagLabel);
    final dto = await buildTestDto(context: context, payload: _labelPayload());

    final result = await documentRenderWorker(dto);
    expect(result.pageWidthMm, 50);
    expect(result.pageHeightMm, 30);
    expect(result.materializePdfBytes(), isNotEmpty);
  });

  test('label rejects insufficient usable area at render time', () async {
    final context = testContext(
      kind: DocumentKind.assetTagLabel,
      bodyOverride: _insufficientLabelBody(),
    );
    final dto = await buildTestDto(context: context, payload: _labelPayload());

    expect(
      () => documentRenderWorker(dto),
      throwsA(
        predicate(
          (e) =>
              e is DocumentTemplateValidationException &&
              e.message.contains('usable width'),
        ),
      ),
    );
  });

  test('default label seed meets min usable 18x10mm', () {
    final settings = labelSettings();
    final left = 2.0;
    final right = 2.0;
    final top = 2.0;
    final bottom = 2.0;
    final qr = settings['qr_size_mm'] as num;
    final width = settings['label_width_mm'] as num;
    final height = settings['label_height_mm'] as num;

    final usableWidth = width - left - right - qr - 1;
    final usableHeight = height - top - bottom;

    expect(usableWidth, greaterThanOrEqualTo(18));
    expect(usableHeight, greaterThanOrEqualTo(10));
  });
}
