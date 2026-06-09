import 'document_kind.dart';

/// Resolves the effective document language for rendering.
///
/// Priority: preview override → tenant default (when template is bilingual) →
/// template clamp. Bilingual is never resolved from UI locale alone.
String resolveEffectiveLanguage({
  required DocumentLanguageMode templateMode,
  DocumentLanguageMode? tenantDefault,
  String? previewLanguageOverride,
  String? userLocale,
}) {
  final override = previewLanguageOverride?.split('_').first.toLowerCase();
  if (override == 'ar') {
    return _clampToTemplate('ar', templateMode);
  }
  if (override == 'en') {
    return _clampToTemplate('en', templateMode);
  }

  var effective = templateMode;
  if (templateMode == DocumentLanguageMode.bilingual) {
    effective = tenantDefault ?? DocumentLanguageMode.bilingual;
  }

  return switch (effective) {
    DocumentLanguageMode.ar => 'ar',
    DocumentLanguageMode.en => 'en',
    DocumentLanguageMode.bilingual => 'bilingual',
  };
}

String _clampToTemplate(String language, DocumentLanguageMode templateMode) {
  return switch (templateMode) {
    DocumentLanguageMode.ar => 'ar',
    DocumentLanguageMode.en => 'en',
    DocumentLanguageMode.bilingual => language,
  };
}

bool isRtlLanguage(String languageCode) => languageCode == 'ar';

/// Locale for intl formatters (bilingual uses Western date formatting).
String intlLocaleFor(String languageCode) {
  if (languageCode == 'ar') return 'ar';
  return 'en';
}

/// Primary PDF font locale (bilingual prefers Arabic font for mixed glyphs).
String fontLocaleFor(String languageCode) {
  if (languageCode == 'bilingual' || languageCode == 'ar') return 'ar';
  return 'en';
}

String pickLocalized({
  required String languageCode,
  required String ar,
  required String en,
}) {
  if (languageCode == 'bilingual') {
    final arTrim = ar.trim();
    final enTrim = en.trim();
    if (arTrim.isNotEmpty && enTrim.isNotEmpty) return '$arTrim / $enTrim';
    if (arTrim.isNotEmpty) return arTrim;
    return enTrim;
  }
  if (languageCode.startsWith('ar') && ar.trim().isNotEmpty) return ar;
  if (en.trim().isNotEmpty) return en;
  return ar;
}
