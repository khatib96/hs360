import 'package:hs360/core/documents/data/document_template_repository.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/tenant_document_settings.dart';
import 'package:hs360/core/errors/document_exception.dart';

class FakeDocumentTemplateRepository extends DocumentTemplateRepository {
  FakeDocumentTemplateRepository({
    TenantDocumentSettings? settings,
    this.fetchError,
    this.saveError,
  }) : settings = settings ?? _defaultSettings(),
       super(null);

  TenantDocumentSettings settings;
  final Object? fetchError;
  final Object? saveError;
  Map<String, dynamic>? lastPatch;
  int saveCount = 0;

  static TenantDocumentSettings _defaultSettings() {
    return const TenantDocumentSettings(
      tenantId: 'tenant-1',
      logoUrl: 'https://example.com/logo.png',
      primaryColor: '#112233',
      secondaryColor: '#445566',
      defaultLanguage: DocumentLanguageMode.bilingual,
      invoicePaperKind: PaperKind.a4,
      voucherPaperKind: PaperKind.a4,
      assetLabelPaperKind: PaperKind.labelSheet,
      headerJson: {'text_ar': 'ترويسة', 'text_en': 'Header'},
      footerJson: {'text_ar': 'تذييل', 'text_en': 'Footer'},
      optionalColumnsJson: {
        'sales_invoice': {'line.qty': true},
        'customer_statement': {'line.debit': false},
      },
    );
  }

  @override
  Future<TenantDocumentSettings> fetchTenantDocumentSettings() async {
    final error = fetchError;
    if (error != null) {
      if (error is DocumentException) throw error;
      throw const DocumentException(code: DocumentException.unknown);
    }
    return settings;
  }

  @override
  Future<TenantDocumentSettings> upsertTenantDocumentSettings(
    Map<String, dynamic> patch,
  ) async {
    saveCount++;
    lastPatch = patch;
    final error = saveError;
    if (error != null) {
      if (error is DocumentException) throw error;
      throw const DocumentException(code: DocumentException.unknown);
    }
    settings = TenantDocumentSettings(
      tenantId: settings.tenantId,
      logoUrl: patch['logo_url'] as String? ?? settings.logoUrl,
      primaryColor: patch['primary_color'] as String? ?? settings.primaryColor,
      secondaryColor:
          patch['secondary_color'] as String? ?? settings.secondaryColor,
      defaultLanguage: settings.defaultLanguage,
      invoicePaperKind: settings.invoicePaperKind,
      voucherPaperKind: settings.voucherPaperKind,
      assetLabelPaperKind: settings.assetLabelPaperKind,
      headerJson: Map<String, dynamic>.from(
        patch['header_json'] as Map? ?? settings.headerJson,
      ),
      footerJson: Map<String, dynamic>.from(
        patch['footer_json'] as Map? ?? settings.footerJson,
      ),
      optionalColumnsJson: Map<String, dynamic>.from(
        patch['optional_columns_json'] as Map? ?? settings.optionalColumnsJson,
      ),
    );
    return settings;
  }
}
