import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../pdf_bilingual_text.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

/// Diagonal draft watermark overlay for contract PDFs.
pw.Widget buildDraftWatermark(PdfRenderContext ctx) {
  final labelAr = 'مسودة - غير معتمدة';
  final labelEn = 'Draft - Not Approved';
  final text = ctx.languageCode == 'ar'
      ? labelAr
      : ctx.languageCode == 'en'
      ? labelEn
      : '$labelAr / $labelEn';

  return pw.Transform.rotate(
    angle: -0.5,
    child: pw.Opacity(
      opacity: 0.12,
      child: pw.Center(
        child: directedPdfText(
          text,
          languageCode: ctx.languageCode,
          style: PdfFontRegistry.textStyle(
            languageCode: ctx.languageCode,
            bold: true,
            fontSize: ctx.layout.baseFontSizePt + 28,
          ).copyWith(color: PdfColors.grey700),
        ),
      ),
    ),
  );
}
