import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../pdf_bilingual_text.dart';
import '../pdf_field_labels.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

class ContractTermsBlock {
  const ContractTermsBlock();

  pw.Widget build(PdfRenderContext ctx, TemplateBlock block) {
    final children = <pw.Widget>[];
    for (final field in block.fields) {
      final value = ctx.resolver.resolve(field);
      if (value.isEmpty) continue;
      final labels = PdfFieldLabels.labelsForField(field);
      final style = PdfFontRegistry.textStyle(
        languageCode: ctx.languageCode,
        fontSize: ctx.layout.baseFontSizePt,
      );
      children.add(
        localizedPdfText(
          languageCode: ctx.languageCode,
          ar: '${labels.ar}: $value',
          en: '${labels.en}: $value',
          style: style,
        ),
      );
    }
    if (children.isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
