import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../pdf_bilingual_text.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

class DocumentMetaBlock {
  const DocumentMetaBlock();

  pw.Widget build(PdfRenderContext ctx, TemplateBlock block) {
    final children = <pw.Widget>[];
    for (final field in block.fields) {
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
      children: _spaced(children, 4),
    );
  }

  List<pw.Widget> _spaced(List<pw.Widget> widgets, double gap) {
    if (widgets.isEmpty) return widgets;
    final out = <pw.Widget>[widgets.first];
    for (var i = 1; i < widgets.length; i++) {
      out.add(pw.SizedBox(height: gap));
      out.add(widgets[i]);
    }
    return out;
  }
}
