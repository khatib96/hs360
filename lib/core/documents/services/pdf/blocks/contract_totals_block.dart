import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../pdf_bilingual_text.dart';
import '../pdf_field_labels.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

class ContractTotalsBlock {
  const ContractTotalsBlock();

  pw.Widget build(PdfRenderContext ctx, TemplateBlock block) {
    final children = <pw.Widget>[];
    for (final field in block.fields) {
      final labels = PdfFieldLabels.labelsForField(field);
      final style = PdfFontRegistry.textStyle(
        languageCode: ctx.languageCode,
        fontSize: ctx.layout.baseFontSizePt,
      );
      if (field == 'totals.is_trial') {
        final value = ctx.resolver.resolve(field);
        if (value.isEmpty) continue;
        children.add(
          localizedPdfText(
            languageCode: ctx.languageCode,
            ar: '${labels.ar}: $value',
            en: '${labels.en}: $value',
            style: style,
            textAlign: pw.TextAlign.end,
          ),
        );
        continue;
      }
      final arValue = ctx.resolver.resolveMoney(field, languageCode: 'ar');
      final enValue = ctx.resolver.resolveMoney(field, languageCode: 'en');
      if (arValue.isEmpty && enValue.isEmpty) continue;
      children.add(
        localizedPdfText(
          languageCode: ctx.languageCode,
          ar: '${labels.ar}: $arValue',
          en: '${labels.en}: $enValue',
          style: style,
          textAlign: pw.TextAlign.end,
        ),
      );
    }
    if (children.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: children,
    );
  }
}
