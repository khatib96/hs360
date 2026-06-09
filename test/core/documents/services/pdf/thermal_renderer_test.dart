import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_render_result.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/document_render_worker.dart';
import 'package:hs360/core/documents/services/document_template_json_parser.dart';
import 'package:hs360/features/vouchers/domain/receipt_voucher_document_fixture.dart';

import 'test_render_helpers.dart';

TemplateBody _oversizedThermalBody() {
  return const DocumentTemplateJsonParser().parse(
    documentType: DocumentKind.receiptVoucher,
    paperKind: PaperKind.thermal80mm,
    raw: {
      'schema_version': 1,
      'settings': {
        'page_margin_mm': {'top': 4, 'right': 4, 'bottom': 4, 'left': 4},
        'base_font_size_pt': 9,
        'line_height': 1.35,
        'show_logo': false,
        'logo_max_height_mm': 12,
        'digit_style': 'western',
        'thermal_content_width_mm': 72,
      },
      'blocks': [
        {'type': 'tenant_header', 'id': 'hdr'},
        {
          'type': 'document_meta',
          'id': 'meta',
          'fields': ['document.number', 'document.date'],
        },
        {'type': 'spacer', 'id': 's1', 'height_mm': 200},
        {'type': 'spacer', 'id': 's2', 'height_mm': 200},
        {'type': 'spacer', 'id': 's3', 'height_mm': 200},
        {'type': 'spacer', 'id': 's4', 'height_mm': 200},
        {'type': 'spacer', 'id': 's5', 'height_mm': 200},
        {'type': 'spacer', 'id': 's6', 'height_mm': 200},
        {'type': 'spacer', 'id': 's7', 'height_mm': 200},
        {
          'type': 'payment_details',
          'id': 'pay',
          'fields': ['payment.amount', 'payment.method', 'payment.reference'],
        },
        {'type': 'footer', 'id': 'ftr', 'source': 'tenant_footer'},
      ],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('thermal rejects measured height above 1200mm', () async {
    final context = testContext(
      kind: DocumentKind.receiptVoucher,
      paper: PaperKind.thermal80mm,
      bodyOverride: _oversizedThermalBody(),
    );
    final dto = await buildTestDto(
      context: context,
      payload: receiptVoucherDocumentFixture(paperKind: PaperKind.thermal80mm),
    );

    expect(
      () => documentRenderWorker(dto),
      throwsA(
        predicate(
          (e) =>
              e is DocumentRenderException &&
              e.code == DocumentRenderException.thermalContentTooLarge,
        ),
      ),
    );
  });

  test('thermal success returns measured height metadata', () async {
    final context = testContext(
      kind: DocumentKind.receiptVoucher,
      paper: PaperKind.thermal80mm,
    );
    final dto = await buildTestDto(
      context: context,
      payload: receiptVoucherDocumentFixture(paperKind: PaperKind.thermal80mm),
    );

    final result = await documentRenderWorker(dto);
    expect(result.thermalHeightMm, isNotNull);
    expect(result.thermalHeightMm!, lessThanOrEqualTo(1200));
    expect(result.thermalHeightMm!, greaterThan(0));
    expect(result.materializePdfBytes(), isNotEmpty);
  });
}
