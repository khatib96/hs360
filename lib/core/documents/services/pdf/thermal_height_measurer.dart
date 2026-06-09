import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_page_layout.dart';
import 'pdf_render_context.dart';

/// Measures the exact laid-out thermal content before creating the page.
class ThermalHeightMeasurer {
  const ThermalHeightMeasurer();

  double measure({
    required pw.Document document,
    required PdfRenderContext ctx,
    required pw.Widget content,
  }) {
    final context = pw.Context(
      document: document.document,
    ).inheritFrom(document.theme ?? pw.ThemeData.base());
    final size = pw.Widget.measure(
      content,
      context: context,
      constraints: pw.BoxConstraints(
        maxWidth: ctx.layout.thermalContentWidthMm * PdfPageFormat.mm,
      ),
    );
    final contentHeightMm = size.y / PdfPageFormat.mm;
    return contentHeightMm +
        ctx.layout.marginTopMm +
        ctx.layout.marginBottomMm +
        PdfPageLayout.thermalSafetyMarginMm;
  }
}
