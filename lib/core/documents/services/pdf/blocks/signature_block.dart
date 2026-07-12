import 'package:pdf/widgets.dart' as pw;

import '../pdf_render_context.dart';

class SignatureBlock {
  const SignatureBlock();

  pw.Widget build(PdfRenderContext ctx) {
    final bytes = ctx.signatureBytes;
    if (bytes == null || bytes.isEmpty) {
      return pw.SizedBox(height: 48);
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Image(
          pw.MemoryImage(bytes),
          height: 36,
          fit: pw.BoxFit.contain,
        ),
      ),
    );
  }
}
