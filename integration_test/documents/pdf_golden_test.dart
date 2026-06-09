import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/data/logo_loader.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/documents/domain/document_template.dart';
import 'package:hs360/core/documents/services/document_render_service.dart';
import 'package:hs360/features/invoices/domain/sales_invoice_document_fixture.dart';
import 'package:hs360/features/vouchers/domain/receipt_voucher_document_fixture.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';

import '../../test/core/documents/goldens/pdf_golden_raster.dart';
import '../../test/core/documents/services/pdf/test_render_helpers.dart';

const _logoFixtureUrl = 'https://example.com/logo_32x32.png';
const _renderTimeout = Duration(minutes: 2);
const _rasterTimeout = Duration(minutes: 2);
const _compareTimeout = Duration(minutes: 1);
const _localeInitializationTimeout = Duration(minutes: 1);
const _driverMode = bool.fromEnvironment('PDF_GOLDEN_DRIVER_MODE');
const _updateGoldens = bool.fromEnvironment('UPDATE_PDF_GOLDENS');

late final IntegrationTestWidgetsFlutterBinding _binding;

String _goldenPlatform() {
  const override = String.fromEnvironment('GOLDEN_PLATFORM');
  if (override.isNotEmpty) {
    return override;
  }
  if (Platform.isAndroid) {
    return 'android';
  }
  if (Platform.isWindows) {
    return 'windows';
  }
  throw UnsupportedError('golden tests: windows or android only');
}

String _goldenPath(String name) {
  return '../../test/core/documents/goldens/${_goldenPlatform()}/$name.png';
}

class _FixtureLogoLoader implements LogoLoader {
  _FixtureLogoLoader(this._bytes);

  final Uint8List _bytes;

  @override
  Future<Uint8List?> loadValidated(String? url) async => _bytes;
}

AssetLabelPayload _labelPayload() {
  return AssetLabelPayload.fromRpc({
    'unit': {'serial': 'SN-12345'},
    'product': {'name_ar': 'منتج', 'name_en': 'Product'},
    'tenant': {'company_name_ar': 'شركة', 'company_name_en': 'Company'},
  });
}

EffectiveDocumentContext _contextWithLogo(
  EffectiveDocumentContext base,
  bool withLogo,
) {
  if (!withLogo) {
    return base;
  }
  return EffectiveDocumentContext(
    template: base.template,
    settings: base.settings,
    currency: base.currency,
    resolvedLogoUrl: _logoFixtureUrl,
    companyNames: base.companyNames,
  );
}

Future<void> _expectPdfGolden({
  required Uint8List pdfBytes,
  required String goldenName,
}) async {
  final png = await PdfGoldenRaster.rasterFirstPageBytes(pdfBytes).timeout(
    _rasterTimeout,
    onTimeout: () => throw TimeoutException(
      'Golden raster timed out for $goldenName',
      _rasterTimeout,
    ),
  );
  if (_driverMode) {
    final reportData = _binding.reportData ??= <String, dynamic>{};
    final encodedGoldens =
        reportData['pdf_goldens'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    encodedGoldens[goldenName] = base64Encode(png);
    reportData['pdf_goldens'] = encodedGoldens;
    reportData['golden_platform'] = _goldenPlatform();
    reportData['update_goldens'] = _updateGoldens;
    return;
  }
  if (Platform.isAndroid) {
    throw UnsupportedError(
      'Android PDF goldens must run through '
      'test_driver/pdf_golden_driver.dart',
    );
  }
  await expectLater(png, matchesGoldenFile(_goldenPath(goldenName))).timeout(
    _compareTimeout,
    onTimeout: () => throw TimeoutException(
      'Golden comparison timed out for $goldenName',
      _compareTimeout,
    ),
  );
}

Future<void> _renderGolden({
  required String goldenName,
  required EffectiveDocumentContext context,
  required DocumentPayload payload,
  required bool withLogo,
  String? previewLanguageOverride,
}) async {
  final logoBytes = withLogo
      ? Uint8List.fromList(
          img.encodePng(
            img.Image(width: 32, height: 32)
              ..clear(img.ColorRgba8(200, 150, 50, 255)),
          ),
        )
      : null;
  final service = DocumentRenderService(
    logoLoader: withLogo ? _FixtureLogoLoader(logoBytes!) : null,
  );
  final result = await service
      .render(
        context: _contextWithLogo(context, withLogo),
        payload: payload,
        userLocale: 'en',
        previewLanguageOverride: previewLanguageOverride,
      )
      .timeout(
        _renderTimeout,
        onTimeout: () => throw TimeoutException(
          'Golden render timed out for $goldenName',
          _renderTimeout,
        ),
      );
  await _expectPdfGolden(
    pdfBytes: Uint8List.fromList(result.bytes),
    goldenName: goldenName,
  );
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en').timeout(
      _localeInitializationTimeout,
      onTimeout: () => throw TimeoutException(
        'English date formatting initialization timed out',
        _localeInitializationTimeout,
      ),
    );
    await initializeDateFormatting('ar').timeout(
      _localeInitializationTimeout,
      onTimeout: () => throw TimeoutException(
        'Arabic date formatting initialization timed out',
        _localeInitializationTimeout,
      ),
    );
  });

  group('pdf goldens (${_goldenPlatform()})', () {
    testWidgets('sales_invoice_a4_no_logo', (tester) async {
      await _renderGolden(
        goldenName: 'sales_invoice_a4_no_logo',
        context: testContext(kind: DocumentKind.salesInvoice),
        payload: salesInvoiceDocumentFixture(),
        withLogo: false,
      );
    });

    testWidgets('sales_invoice_a4_with_logo', (tester) async {
      await _renderGolden(
        goldenName: 'sales_invoice_a4_with_logo',
        context: testContext(kind: DocumentKind.salesInvoice),
        payload: salesInvoiceDocumentFixture(),
        withLogo: true,
      );
    });

    testWidgets('customer_statement_a4_no_logo', (tester) async {
      await _renderGolden(
        goldenName: 'customer_statement_a4_no_logo',
        context: testContext(kind: DocumentKind.customerStatement),
        payload: arabicStatementPayload(),
        withLogo: false,
      );
    });

    testWidgets('customer_statement_a4_with_logo', (tester) async {
      await _renderGolden(
        goldenName: 'customer_statement_a4_with_logo',
        context: testContext(kind: DocumentKind.customerStatement),
        payload: arabicStatementPayload(),
        withLogo: true,
      );
    });

    testWidgets('customer_statement_a4_ar', (tester) async {
      await _renderGolden(
        goldenName: 'customer_statement_a4_ar',
        context: testContext(kind: DocumentKind.customerStatement),
        payload: arabicStatementPayload(),
        withLogo: true,
        previewLanguageOverride: 'ar',
      );
    });

    testWidgets('receipt_voucher_thermal_no_logo', (tester) async {
      await _renderGolden(
        goldenName: 'receipt_voucher_thermal_no_logo',
        context: testContext(
          kind: DocumentKind.receiptVoucher,
          paper: PaperKind.thermal80mm,
        ),
        payload: receiptVoucherDocumentFixture(
          paperKind: PaperKind.thermal80mm,
        ),
        withLogo: false,
      );
    });

    testWidgets('receipt_voucher_thermal_with_logo', (tester) async {
      await _renderGolden(
        goldenName: 'receipt_voucher_thermal_with_logo',
        context: testContext(
          kind: DocumentKind.receiptVoucher,
          paper: PaperKind.thermal80mm,
        ),
        payload: receiptVoucherDocumentFixture(
          paperKind: PaperKind.thermal80mm,
        ),
        withLogo: true,
      );
    });

    testWidgets('asset_tag_label_no_logo', (tester) async {
      await _renderGolden(
        goldenName: 'asset_tag_label_no_logo',
        context: testContext(kind: DocumentKind.assetTagLabel),
        payload: _labelPayload(),
        withLogo: false,
      );
    });

    testWidgets('asset_tag_label_with_logo', (tester) async {
      await _renderGolden(
        goldenName: 'asset_tag_label_with_logo',
        context: testContext(kind: DocumentKind.assetTagLabel),
        payload: _labelPayload(),
        withLogo: true,
      );
    });

    testWidgets('asset_tag_label_ar', (tester) async {
      await _renderGolden(
        goldenName: 'asset_tag_label_ar',
        context: testContext(kind: DocumentKind.assetTagLabel),
        payload: _labelPayload(),
        withLogo: true,
        previewLanguageOverride: 'ar',
      );
    });
  });
}
