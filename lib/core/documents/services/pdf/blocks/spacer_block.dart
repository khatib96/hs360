import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../pdf_render_context.dart';

class SpacerBlock {
  const SpacerBlock();

  pw.Widget build(PdfRenderContext ctx, TemplateBlock block) {
    final heightMm = block.heightMm ?? 4;
    return pw.SizedBox(height: heightMm * PdfPageFormat.mm);
  }
}
