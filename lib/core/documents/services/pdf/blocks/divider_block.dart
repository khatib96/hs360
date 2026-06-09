import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../pdf_render_context.dart';

class DividerBlock {
  const DividerBlock();

  pw.Widget build(PdfRenderContext ctx) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Divider(color: PdfColors.grey400, thickness: 0.5),
    );
  }
}
