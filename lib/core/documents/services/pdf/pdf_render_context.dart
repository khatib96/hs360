import 'dart:typed_data';

import '../../domain/document_kind.dart';
import '../../domain/document_optional_columns.dart';
import '../../domain/document_template.dart';
import '../../domain/tenant_currency_format.dart';
import 'pdf_field_resolver.dart';
import 'pdf_page_layout.dart';

/// Immutable rendering context passed to block renderers.
class PdfRenderContext {
  const PdfRenderContext({
    required this.documentType,
    required this.paperKind,
    required this.languageCode,
    required this.body,
    required this.tenantSettings,
    required this.companyNames,
    required this.payload,
    required this.currency,
    required this.layout,
    required this.resolver,
    this.logoBytes,
    this.signatureBytes,
    this.rtl = false,
  });

  final DocumentKind documentType;
  final PaperKind paperKind;
  final String languageCode;
  final TemplateBody body;
  final Map<String, dynamic> tenantSettings;
  final Map<String, String> companyNames;
  final Map<String, dynamic> payload;
  final TenantCurrencyFormat currency;
  final PdfPageLayout layout;
  final PdfFieldResolver resolver;
  final Uint8List? logoBytes;
  final Uint8List? signatureBytes;
  final bool rtl;

  List<TemplateColumn> visibleColumns(TemplateBlock block) {
    return block.columns
        .where(
          (column) => DocumentOptionalColumns.isVisible(
            documentType: documentType,
            field: column.field,
            tenantSettings: tenantSettings,
          ),
        )
        .toList(growable: false);
  }

  factory PdfRenderContext.fromDto({
    required String documentType,
    required String paperKind,
    required String languageCode,
    required Map<String, dynamic> templateBodyJson,
    required Map<String, dynamic> tenantSettings,
    required Map<String, String> companyNames,
    required Map<String, dynamic> payloadJson,
    required Map<String, dynamic>? currencyJson,
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) {
    final kind = DocumentKind.fromDocumentType(documentType)!;
    final paper = PaperKind.fromValue(paperKind)!;
    final body = TemplateBody.fromJson(templateBodyJson);
    final layout = PdfPageLayout(paperKind: paper, settings: body.settings);
    final currency = TenantCurrencyFormat.fromRpc(currencyJson);
    final resolver = PdfFieldResolver(
      payload: payloadJson,
      currency: currency,
      languageCode: languageCode,
    );

    return PdfRenderContext(
      documentType: kind,
      paperKind: paper,
      languageCode: languageCode,
      body: body,
      tenantSettings: tenantSettings,
      companyNames: companyNames,
      payload: payloadJson,
      currency: currency,
      layout: layout,
      resolver: resolver,
      logoBytes: logoBytes,
      signatureBytes: signatureBytes,
      rtl: languageCode == 'ar',
    );
  }
}
