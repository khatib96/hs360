import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/document_kind.dart';
import '../../domain/document_render_result.dart';

/// Page format and margin helpers for PDF rendering.
class PdfPageLayout {
  const PdfPageLayout({required this.paperKind, required this.settings});

  final PaperKind paperKind;
  final Map<String, dynamic> settings;

  static const thermalMaxHeightMm = 1200.0;
  static const thermalSafetyMarginMm = 4.0;
  static const labelTextGapMm = 1.0;

  PdfPageFormat pageFormat({double? thermalHeightMm}) {
    return switch (paperKind) {
      PaperKind.a4 => PdfPageFormat.a4,
      PaperKind.thermal80mm => PdfPageFormat(
        80 * PdfPageFormat.mm,
        (thermalHeightMm ?? 200) * PdfPageFormat.mm,
      ),
      PaperKind.labelSheet => PdfPageFormat(
        (_num(settings['label_width_mm']) ?? 50) * PdfPageFormat.mm,
        (_num(settings['label_height_mm']) ?? 30) * PdfPageFormat.mm,
      ),
    };
  }

  double get pageWidthMm => switch (paperKind) {
    PaperKind.a4 => 210,
    PaperKind.thermal80mm => 80,
    PaperKind.labelSheet => _num(settings['label_width_mm']) ?? 50,
  };

  double get pageHeightMm => switch (paperKind) {
    PaperKind.a4 => 297,
    PaperKind.thermal80mm => 200,
    PaperKind.labelSheet => _num(settings['label_height_mm']) ?? 30,
  };

  pw.EdgeInsets get margins {
    final margin = settings['page_margin_mm'];
    if (margin is! Map) return const pw.EdgeInsets.all(12);
    final m = Map<String, dynamic>.from(margin);
    return pw.EdgeInsets.only(
      top: (_num(m['top']) ?? 12) * PdfPageFormat.mm,
      right: (_num(m['right']) ?? 12) * PdfPageFormat.mm,
      bottom: (_num(m['bottom']) ?? 12) * PdfPageFormat.mm,
      left: (_num(m['left']) ?? 12) * PdfPageFormat.mm,
    );
  }

  double get marginTopMm => _marginSide('top');
  double get marginRightMm => _marginSide('right');
  double get marginBottomMm => _marginSide('bottom');
  double get marginLeftMm => _marginSide('left');

  double get baseFontSizePt => _num(settings['base_font_size_pt']) ?? 10;
  double get lineHeight => _num(settings['line_height']) ?? 1.35;
  bool get showLogo => settings['show_logo'] == true;
  double get logoMaxHeightMm => _num(settings['logo_max_height_mm']) ?? 18;
  double get thermalContentWidthMm =>
      _num(settings['thermal_content_width_mm']) ?? 72;
  double get qrSizeMm => _num(settings['qr_size_mm']) ?? 14;

  double get labelWidthMm => _num(settings['label_width_mm']) ?? 50;
  double get labelHeightMm => _num(settings['label_height_mm']) ?? 30;

  double get labelUsableWidthMm =>
      labelWidthMm - marginLeftMm - marginRightMm - qrSizeMm - labelTextGapMm;

  double get labelUsableHeightMm =>
      labelHeightMm - marginTopMm - marginBottomMm;

  void assertLabelGeometry() {
    if (labelUsableWidthMm < 18 || labelUsableHeightMm < 10) {
      throw const DocumentRenderException(
        DocumentRenderException.labelContentTooLarge,
      );
    }
  }

  double _marginSide(String side) {
    final margin = settings['page_margin_mm'];
    if (margin is! Map) return 12;
    return _num(Map<String, dynamic>.from(margin)[side]) ?? 12;
  }

  static double? _num(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }
}
