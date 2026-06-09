import 'document_kind.dart';

/// Resolved output from the PDF renderer.
class DocumentRenderResult {
  const DocumentRenderResult({
    required this.bytes,
    required this.pageCount,
    required this.paperKind,
    required this.title,
  });

  final List<int> bytes;
  final int pageCount;
  final PaperKind paperKind;
  final String title;
}

/// Renderer failures with stable codes for localization.
class DocumentRenderException implements Exception {
  const DocumentRenderException(this.code, {this.technicalDetail});

  static const thermalContentTooLarge = 'thermal_content_too_large';
  static const labelContentTooLarge = 'label_content_too_large';
  static const fontLoadFailed = 'font_load_failed';
  static const invalidTemplate = 'invalid_template';
  static const logoLoadFailed = 'logo_load_failed';
  static const unsupportedKind = 'unsupported_document_type';
  static const unknown = 'unknown';

  final String code;
  final String? technicalDetail;

  @override
  String toString() => 'DocumentRenderException($code)';
}
