import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../pdf_bilingual_text.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

/// Renders payload notes; empty when null or blank.
class NotesBlock {
  const NotesBlock();

  pw.Widget build(PdfRenderContext ctx, TemplateBlock block) {
    final notes = ctx.resolver.resolveNotes();
    if (notes.isEmpty) return pw.SizedBox.shrink();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: directedPdfText(
        notes,
        languageCode: ctx.languageCode,
        style: PdfFontRegistry.textStyle(
          languageCode: ctx.languageCode,
          fontSize: ctx.layout.baseFontSizePt,
        ),
      ),
    );
  }
}
