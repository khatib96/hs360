@Tags(['manual-prototype'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/document_render_service.dart';
import 'package:hs360/core/documents/services/document_template_json_parser.dart';

/// Manual prototype gate — run with: flutter test test/manual/arabic_pdf_prototype_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Arabic PDF prototype generates bytes', () async {
    final context = EffectiveDocumentContext(
      template: DocumentTemplate(
        id: 'tpl-ar',
        templateKey: 'asset_tag_label',
        documentType: DocumentKind.assetTagLabel,
        languageMode: DocumentLanguageMode.ar,
        paperKind: PaperKind.labelSheet,
        schemaVersion: 1,
        body: const DocumentTemplateJsonParser().parse(
          documentType: DocumentKind.assetTagLabel,
          paperKind: PaperKind.labelSheet,
          raw: {
            'schema_version': 1,
            'settings': {
              'page_margin_mm': {'top': 2, 'right': 2, 'bottom': 2, 'left': 2},
              'base_font_size_pt': 6,
              'line_height': 1.35,
              'show_logo': true,
              'logo_max_height_mm': 5,
              'digit_style': 'western',
              'label_width_mm': 50,
              'label_height_mm': 30,
              'qr_size_mm': 14,
              'label_layout': 'horizontal',
            },
            'blocks': [
              {'type': 'tenant_header', 'id': 'hdr'},
              {
                'type': 'asset_identity',
                'id': 'idn',
                'fields': [
                  'tenant.company_name_ar',
                  'product.name_ar',
                  'unit.serial',
                ],
              },
              {'type': 'qr_code', 'id': 'qr', 'payload_field': 'unit.serial'},
            ],
          },
        ),
        nameAr: 'ملصق أصل',
        nameEn: 'Asset Label',
      ),
      settings: const {'default_language': 'ar'},
      currency: null,
      resolvedLogoUrl: null,
      companyNames: const {'ar': 'شركة العطور', 'en': 'Fragrance Co'},
    );

    final payload = AssetLabelPayload(
      unit: const {
        'serial': 'HS-AR-001',
        'barcode': null,
        'status': 'available',
      },
      product: const {
        'name_ar': 'جهاز عطر',
        'name_en': 'Diffuser',
        'sku': 'DIF-01',
      },
      tenant: const {
        'company_name_ar': 'شركة العطور',
        'company_name_en': 'Fragrance Co',
      },
    );

    final service = DocumentRenderService();
    final result = await service.render(
      context: context,
      payload: payload,
      userLocale: 'ar',
    );

    expect(result.bytes.length, greaterThan(100));
  });
}
