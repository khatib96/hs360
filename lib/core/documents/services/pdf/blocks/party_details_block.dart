import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../pdf_bilingual_text.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

class PartyDetailsBlock {
  const PartyDetailsBlock();

  pw.Widget build(PdfRenderContext ctx, TemplateBlock block) {
    final children = <pw.Widget>[];
    var partyNameAdded = false;
    for (final field in block.fields) {
      if (field == 'party.name_ar' || field == 'party.name_en') {
        if (partyNameAdded) {
          continue;
        }
        partyNameAdded = true;
        final ar = ctx.resolver.resolve('party.name_ar');
        final en = ctx.resolver.resolve('party.name_en');
        if (ar.isNotEmpty || en.isNotEmpty) {
          children.add(
            localizedPdfText(
              languageCode: ctx.languageCode,
              ar: ar,
              en: en,
              style: PdfFontRegistry.textStyle(
                languageCode: ctx.languageCode,
                bold: true,
                fontSize: ctx.layout.baseFontSizePt,
              ),
            ),
          );
        }
        continue;
      }
      final value = ctx.resolver.resolve(field);
      if (value.isEmpty) continue;
      children.add(
        directedPdfText(
          value,
          languageCode: ctx.languageCode,
          style: PdfFontRegistry.textStyle(
            languageCode: ctx.languageCode,
            fontSize: ctx.layout.baseFontSizePt,
          ),
        ),
      );
    }
    if (children.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }
}
