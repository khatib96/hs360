import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../pdf_bilingual_text.dart';
import '../pdf_font_registry.dart';
import '../pdf_render_context.dart';

class PaymentDetailsBlock {
  const PaymentDetailsBlock();

  pw.Widget build(PdfRenderContext ctx, TemplateBlock block) {
    final children = <pw.Widget>[];
    for (final field in block.fields) {
      final value = ctx.resolver.resolve(field);
      if (value.isEmpty) continue;
      final isAmount = field == 'payment.amount';
      children.add(
        directedPdfText(
          value,
          languageCode: ctx.languageCode,
          style: PdfFontRegistry.textStyle(
            languageCode: ctx.languageCode,
            fontSize: isAmount
                ? ctx.layout.baseFontSizePt + 6
                : ctx.layout.baseFontSizePt,
            bold: isAmount,
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
