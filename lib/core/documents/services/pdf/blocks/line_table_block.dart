import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../pdf_render_context.dart';
import '../pdf_table_builder.dart';

class LineTableBlock {
  const LineTableBlock();

  pw.Widget build(PdfRenderContext ctx, TemplateBlock block) {
    return const PdfTableBuilder().buildLineTable(ctx: ctx, block: block);
  }
}
