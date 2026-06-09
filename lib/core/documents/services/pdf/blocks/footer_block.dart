import 'package:pdf/widgets.dart' as pw;

import '../pdf_bilingual_text.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

class FooterBlock {
  const FooterBlock();

  pw.Widget build(PdfRenderContext ctx) {
    final footer = ctx.tenantSettings['footer_json'];
    final ar = footer is Map ? footer['text_ar']?.toString() ?? '' : '';
    final en = footer is Map ? footer['text_en']?.toString() ?? '' : '';
    if (ar.isEmpty && en.isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: localizedPdfText(
        languageCode: ctx.languageCode,
        ar: ar,
        en: en,
        style: PdfFontRegistry.textStyle(
          languageCode: ctx.languageCode,
          fontSize: ctx.layout.baseFontSizePt - 2,
        ),
      ),
    );
  }
}
