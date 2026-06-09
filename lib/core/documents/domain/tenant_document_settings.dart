import 'document_kind.dart';

/// Tenant document branding and paper defaults from RPC.
class TenantDocumentSettings {
  const TenantDocumentSettings({
    required this.tenantId,
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    required this.defaultLanguage,
    required this.invoicePaperKind,
    required this.voucherPaperKind,
    required this.assetLabelPaperKind,
    this.headerJson = const {},
    this.footerJson = const {},
    this.optionalColumnsJson = const {},
  });

  final String tenantId;
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final DocumentLanguageMode defaultLanguage;
  final PaperKind invoicePaperKind;
  final PaperKind voucherPaperKind;
  final PaperKind assetLabelPaperKind;
  final Map<String, dynamic> headerJson;
  final Map<String, dynamic> footerJson;
  final Map<String, dynamic> optionalColumnsJson;

  factory TenantDocumentSettings.fromRpc(Map<String, dynamic> json) {
    final tenantId = json['tenant_id'];
    if (tenantId is! String || tenantId.isEmpty) {
      throw const TenantDocumentSettingsException('validation_failed');
    }

    final defaultLanguageRaw = json['default_language'] as String?;
    if (defaultLanguageRaw == null ||
        !{'ar', 'en', 'bilingual'}.contains(defaultLanguageRaw)) {
      throw const TenantDocumentSettingsException('validation_failed');
    }

    final invoicePaper = PaperKind.fromValue(
      json['invoice_paper_kind'] as String?,
    );
    if (invoicePaper != PaperKind.a4) {
      throw const TenantDocumentSettingsException('validation_failed');
    }

    final voucherPaper = PaperKind.fromValue(
      json['voucher_paper_kind'] as String?,
    );
    if (voucherPaper != PaperKind.a4 && voucherPaper != PaperKind.thermal80mm) {
      throw const TenantDocumentSettingsException('validation_failed');
    }

    final assetPaper = PaperKind.fromValue(
      json['asset_label_paper_kind'] as String?,
    );
    if (assetPaper != PaperKind.labelSheet) {
      throw const TenantDocumentSettingsException('validation_failed');
    }

    final headerRaw = json['header_json'];
    final footerRaw = json['footer_json'];
    final optionalRaw = json['optional_columns_json'];
    if (headerRaw is! Map || footerRaw is! Map || optionalRaw is! Map) {
      throw const TenantDocumentSettingsException('validation_failed');
    }

    final headerJson = Map<String, dynamic>.from(headerRaw);
    final footerJson = Map<String, dynamic>.from(footerRaw);
    final optionalColumnsJson = Map<String, dynamic>.from(optionalRaw);

    _validateTextJson(headerJson);
    _validateTextJson(footerJson);
    _validateOptionalColumnsJson(optionalColumnsJson);

    return TenantDocumentSettings(
      tenantId: tenantId,
      logoUrl: json['logo_url'] as String?,
      primaryColor: json['primary_color'] as String?,
      secondaryColor: json['secondary_color'] as String?,
      defaultLanguage: DocumentLanguageMode.fromValue(defaultLanguageRaw),
      invoicePaperKind: PaperKind.a4,
      voucherPaperKind: voucherPaper!,
      assetLabelPaperKind: assetPaper!,
      headerJson: headerJson,
      footerJson: footerJson,
      optionalColumnsJson: optionalColumnsJson,
    );
  }

  static void _validateTextJson(Map<String, dynamic> json) {
    for (final key in json.keys) {
      if (!{'text_ar', 'text_en'}.contains(key)) {
        throw const TenantDocumentSettingsException('validation_failed');
      }
      final value = json[key];
      if (value is! String) {
        throw const TenantDocumentSettingsException('validation_failed');
      }
      if (value.length > 1000) {
        throw const TenantDocumentSettingsException('validation_failed');
      }
      if (_hasControlChars(value)) {
        throw const TenantDocumentSettingsException('validation_failed');
      }
    }
  }

  static void _validateOptionalColumnsJson(Map<String, dynamic> json) {
    const allowedDocTypes = {
      'sales_invoice',
      'purchase_invoice',
      'customer_statement',
    };
    const allowedFields = {
      'sales_invoice': {'line.qty', 'line.unit_price'},
      'purchase_invoice': {'line.qty', 'line.unit_price'},
      'customer_statement': {'line.debit', 'line.credit'},
    };
    const mandatoryFields = {
      'sales_invoice': {'line.description', 'line.total'},
      'purchase_invoice': {'line.description', 'line.total'},
      'customer_statement': {'line.date', 'line.description', 'line.balance'},
    };

    for (final docType in json.keys) {
      if (!allowedDocTypes.contains(docType)) {
        throw const TenantDocumentSettingsException('validation_failed');
      }
      final fieldsRaw = json[docType];
      if (fieldsRaw is! Map) {
        throw const TenantDocumentSettingsException('validation_failed');
      }
      final fields = Map<String, dynamic>.from(fieldsRaw);
      if (fields.length > 4) {
        throw const TenantDocumentSettingsException('validation_failed');
      }
      for (final field in fields.keys) {
        if (!allowedFields[docType]!.contains(field)) {
          throw const TenantDocumentSettingsException('validation_failed');
        }
        final value = fields[field];
        if (value is! bool) {
          throw const TenantDocumentSettingsException('validation_failed');
        }
        if (mandatoryFields[docType]!.contains(field) && value == false) {
          throw const TenantDocumentSettingsException('validation_failed');
        }
      }
    }
  }

  static bool _hasControlChars(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit == 0x09 || codeUnit == 0x0A) continue;
      if (codeUnit >= 0x00 && codeUnit <= 0x1F) return true;
      if (codeUnit == 0x7F) return true;
    }
    return false;
  }

  Map<String, dynamic> toPatch({
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    DocumentLanguageMode? defaultLanguage,
    PaperKind? voucherPaperKind,
  }) {
    final patch = <String, dynamic>{};
    if (logoUrl != null) patch['logo_url'] = logoUrl;
    if (primaryColor != null) patch['primary_color'] = primaryColor;
    if (secondaryColor != null) patch['secondary_color'] = secondaryColor;
    if (defaultLanguage != null) {
      patch['default_language'] = defaultLanguage.value;
    }
    if (voucherPaperKind != null) {
      patch['voucher_paper_kind'] = voucherPaperKind.value;
    }
    return patch;
  }
}

class TenantDocumentSettingsException implements Exception {
  const TenantDocumentSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}
