import 'package:flutter_test/flutter_test.dart';
import 'dart:isolate';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/domain/document_render_result.dart';
import 'package:hs360/core/documents/services/document_render_service.dart';
import 'package:hs360/features/invoices/domain/sales_invoice_document_fixture.dart';
import 'package:hs360/features/vouchers/domain/receipt_voucher_document_fixture.dart';

import 'pdf/test_render_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('payment_voucher rejected before isolate', () async {
    final service = DocumentRenderService();
    final context = EffectiveDocumentContext(
      template: DocumentTemplate(
        id: 'tpl-pv',
        templateKey: 'payment_voucher_a4',
        documentType: DocumentKind.paymentVoucher,
        languageMode: DocumentLanguageMode.en,
        paperKind: PaperKind.a4,
        schemaVersion: 1,
        body: TemplateBody(
          schemaVersion: 1,
          settings: a4Settings(),
          blocks: const [TemplateBlock(type: 'tenant_header', id: 'hdr')],
        ),
        nameAr: 'سند',
        nameEn: 'Voucher',
      ),
      settings: const {},
      currency: null,
      resolvedLogoUrl: null,
      companyNames: const {'ar': '', 'en': ''},
    );
    final payload = VoucherPayload(
      documentType: DocumentKind.paymentVoucher,
      document: const {'number': 'PV-1'},
      party: const {},
      payment: const {},
    );

    expect(
      () =>
          service.render(context: context, payload: payload, userLocale: 'en'),
      throwsA(
        predicate(
          (e) =>
              e is DocumentRenderException &&
              e.code == DocumentRenderException.unsupportedKind,
        ),
      ),
    );
  });

  test('DTO serializes money as decimal strings', () async {
    final context = testContext(kind: DocumentKind.customerStatement);
    final payload = arabicStatementPayload(notes: 'Test note');
    final dto = await buildTestDto(context: context, payload: payload);

    final summary = dto.payloadJson['summary'] as Map;
    expect(summary['opening_balance'], '100.000');
    expect(summary['total_debit'], '50.000');
    expect(summary['closing_balance'], '130.000');

    final lines = dto.payloadJson['lines'] as List;
    final line = lines.first as Map;
    expect(line['debit'], '50.000');
    expect(line['credit'], '0');
    expect(line['running_balance'], '150.000');

    for (final value in summary.values) {
      expect(value, isA<String>());
    }
    expect(dto.fontBundle.regularLatin, isA<TransferableTypedData>());
  });

  test('render via isolate produces PDF bytes', () async {
    final service = DocumentRenderService();
    final context = testContext(kind: DocumentKind.salesInvoice);
    final result = await service.render(
      context: context,
      payload: salesInvoiceDocumentFixture(),
      userLocale: 'en',
    );

    expect(result.bytes, isNotEmpty);
    expect(result.pageCount, greaterThanOrEqualTo(1));
    expect(result.title, isNotEmpty);
  });

  test('thermal receipt renders via isolate', () async {
    final service = DocumentRenderService();
    final context = testContext(
      kind: DocumentKind.receiptVoucher,
      paper: PaperKind.thermal80mm,
    );
    final result = await service.render(
      context: context,
      payload: receiptVoucherDocumentFixture(paperKind: PaperKind.thermal80mm),
      userLocale: 'en',
    );

    expect(result.bytes, isNotEmpty);
    expect(result.pageCount, 1);
  });
}
