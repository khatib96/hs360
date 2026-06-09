import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'blocks/asset_identity_block.dart';
import 'blocks/qr_code_block.dart';
import 'blocks/spacer_block.dart';
import 'blocks/tenant_header_block.dart';
import 'pdf_page_layout.dart';
import 'pdf_render_context.dart';
import '../qr_encoder.dart';

/// Horizontal label layout: text column + 1 mm gap + QR.
class LabelRenderer {
  LabelRenderer({QrEncoder? qrEncoder})
    : _qrEncoder = qrEncoder ?? const BarcodeQrEncoder();

  final QrEncoder _qrEncoder;

  final _tenantHeader = const TenantHeaderBlock();
  final _assetIdentity = const AssetIdentityBlock();
  final _spacer = const SpacerBlock();

  void assertGeometry(PdfRenderContext ctx) {
    ctx.layout.assertLabelGeometry();
  }

  pw.Widget build(PdfRenderContext ctx) {
    assertGeometry(ctx);

    final textBlocks = <pw.Widget>[];
    pw.Widget? qrWidget;
    final hasTenantHeader = ctx.body.blocks.any(
      (block) => block.type == 'tenant_header',
    );

    for (final block in ctx.body.blocks) {
      switch (block.type) {
        case 'tenant_header':
          textBlocks.add(_tenantHeader.build(ctx));
        case 'asset_identity':
          textBlocks.add(
            _assetIdentity.build(
              ctx,
              block,
              includeTenantName: !hasTenantHeader,
            ),
          );
        case 'qr_code':
          qrWidget = QrCodeBlock(encoder: _qrEncoder).build(ctx, block);
        case 'spacer':
          textBlocks.add(_spacer.build(ctx, block));
        case 'divider':
          textBlocks.add(pw.SizedBox(height: 2 * PdfPageFormat.mm));
      }
    }

    final gap = PdfPageLayout.labelTextGapMm * PdfPageFormat.mm;
    final qrSize = ctx.layout.qrSizeMm * PdfPageFormat.mm;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: textBlocks,
          ),
        ),
        pw.SizedBox(width: gap),
        qrWidget ?? pw.SizedBox(width: qrSize, height: qrSize),
      ],
    );
  }
}
