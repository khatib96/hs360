import '../../../core/documents/domain/document_kind.dart';
import '../../../core/documents/domain/tenant_document_settings.dart';

class TemplateSettingsState {
  const TemplateSettingsState({
    this.isLoading = false,
    this.isSaving = false,
    this.permissionDenied = false,
    this.canEdit = false,
    this.errorCode,
    this.saveErrorCode,
    this.saveSuccess = false,
    this.settings,
    this.logoUrl = '',
    this.primaryColor = '',
    this.secondaryColor = '',
    this.defaultLanguage = DocumentLanguageMode.bilingual,
    this.invoicePaperKind = PaperKind.a4,
    this.voucherPaperKind = PaperKind.a4,
    this.assetLabelPaperKind = PaperKind.labelSheet,
    this.headerTextAr = '',
    this.headerTextEn = '',
    this.footerTextAr = '',
    this.footerTextEn = '',
    this.optionalColumns = const {},
  });

  final bool isLoading;
  final bool isSaving;
  final bool permissionDenied;
  final bool canEdit;
  final String? errorCode;
  final String? saveErrorCode;
  final bool saveSuccess;
  final TenantDocumentSettings? settings;
  final String logoUrl;
  final String primaryColor;
  final String secondaryColor;
  final DocumentLanguageMode defaultLanguage;
  final PaperKind invoicePaperKind;
  final PaperKind voucherPaperKind;
  final PaperKind assetLabelPaperKind;
  final String headerTextAr;
  final String headerTextEn;
  final String footerTextAr;
  final String footerTextEn;
  final Map<String, Map<String, bool>> optionalColumns;

  bool optionalColumnEnabled(String docType, String field) {
    return optionalColumns[docType]?[field] ?? true;
  }

  TemplateSettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? permissionDenied,
    bool? canEdit,
    String? errorCode,
    bool clearError = false,
    String? saveErrorCode,
    bool clearSaveError = false,
    bool? saveSuccess,
    TenantDocumentSettings? settings,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    DocumentLanguageMode? defaultLanguage,
    PaperKind? invoicePaperKind,
    PaperKind? voucherPaperKind,
    PaperKind? assetLabelPaperKind,
    String? headerTextAr,
    String? headerTextEn,
    String? footerTextAr,
    String? footerTextEn,
    Map<String, Map<String, bool>>? optionalColumns,
  }) {
    return TemplateSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      canEdit: canEdit ?? this.canEdit,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      saveErrorCode: clearSaveError
          ? null
          : (saveErrorCode ?? this.saveErrorCode),
      saveSuccess: saveSuccess ?? this.saveSuccess,
      settings: settings ?? this.settings,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      invoicePaperKind: invoicePaperKind ?? this.invoicePaperKind,
      voucherPaperKind: voucherPaperKind ?? this.voucherPaperKind,
      assetLabelPaperKind: assetLabelPaperKind ?? this.assetLabelPaperKind,
      headerTextAr: headerTextAr ?? this.headerTextAr,
      headerTextEn: headerTextEn ?? this.headerTextEn,
      footerTextAr: footerTextAr ?? this.footerTextAr,
      footerTextEn: footerTextEn ?? this.footerTextEn,
      optionalColumns: optionalColumns ?? this.optionalColumns,
    );
  }

  static Map<String, Map<String, bool>> optionalColumnsFromSettings(
    Map<String, dynamic> json,
  ) {
    final result = <String, Map<String, bool>>{};
    for (final entry in json.entries) {
      if (entry.value is! Map) continue;
      final fields = Map<String, dynamic>.from(entry.value as Map);
      result[entry.key] = {
        for (final field in fields.entries)
          if (field.value is bool) field.key: field.value as bool,
      };
    }
    return result;
  }
}
