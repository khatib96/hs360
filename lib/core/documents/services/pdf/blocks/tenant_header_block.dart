import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../pdf_bilingual_text.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

class TenantHeaderBlock {
  const TenantHeaderBlock();

  pw.Widget build(PdfRenderContext ctx) {
    if (!ctx.layout.showLogo &&
        ctx.companyNames.values.every((v) => v.isEmpty)) {
      return pw.SizedBox.shrink();
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: localizedPdfText(
            languageCode: ctx.languageCode,
            ar: ctx.companyNames['ar'] ?? '',
            en: ctx.companyNames['en'] ?? '',
            style: PdfFontRegistry.textStyle(
              languageCode: ctx.languageCode,
              bold: true,
              fontSize: ctx.layout.baseFontSizePt,
            ),
          ),
        ),
        if (ctx.layout.showLogo && ctx.logoBytes != null)
          pw.Image(
            pw.MemoryImage(ctx.logoBytes!),
            height: ctx.layout.logoMaxHeightMm * PdfPageFormat.mm,
          ),
      ],
    );
  }
}
