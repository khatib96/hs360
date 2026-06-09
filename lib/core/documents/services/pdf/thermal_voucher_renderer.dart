import 'package:pdf/widgets.dart' as pw;

import '../../domain/document_render_result.dart';
import 'pdf_block_renderer.dart';
import 'pdf_page_layout.dart';
import 'pdf_render_context.dart';
import 'thermal_height_measurer.dart';

/// Renders thermal documents with measured roll height (no Spacer/flex).
class ThermalVoucherRenderer {
  ThermalVoucherRenderer({
    PdfBlockRenderer? blockRenderer,
    ThermalHeightMeasurer? measurer,
  }) : _blockRenderer = blockRenderer ?? PdfBlockRenderer(),
       _measurer = measurer ?? const ThermalHeightMeasurer();

  final PdfBlockRenderer _blockRenderer;
  final ThermalHeightMeasurer _measurer;

  ThermalRenderPlan plan({
    required pw.Document document,
    required PdfRenderContext ctx,
  }) {
    final measuredMm = _measurer.measure(
      document: document,
      ctx: ctx,
      content: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: buildContent(ctx),
      ),
    );
    if (measuredMm > PdfPageLayout.thermalMaxHeightMm) {
      throw const DocumentRenderException(
        DocumentRenderException.thermalContentTooLarge,
      );
    }
    if (measuredMm <= 0 || measuredMm.isNaN || measuredMm.isInfinite) {
      throw const DocumentRenderException(
        DocumentRenderException.thermalContentTooLarge,
      );
    }
    return ThermalRenderPlan(measuredHeightMm: measuredMm);
  }

  List<pw.Widget> buildContent(PdfRenderContext ctx) {
    final widgets = <pw.Widget>[];
    for (final block in ctx.body.blocks) {
      widgets.add(_blockRenderer.renderBlock(ctx, block));
      widgets.add(pw.SizedBox(height: 4));
    }
    if (widgets.isNotEmpty) widgets.removeLast();
    return widgets;
  }
}

class ThermalRenderPlan {
  const ThermalRenderPlan({required this.measuredHeightMm});

  final double measuredHeightMm;
}
