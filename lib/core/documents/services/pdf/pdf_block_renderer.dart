import 'package:pdf/widgets.dart' as pw;

import '../../domain/document_template.dart';
import 'blocks/asset_identity_block.dart';
import 'blocks/divider_block.dart';
import 'blocks/document_meta_block.dart';
import 'blocks/footer_block.dart';
import 'blocks/line_table_block.dart';
import 'blocks/notes_block.dart';
import 'blocks/party_details_block.dart';
import 'blocks/payment_details_block.dart';
import 'blocks/qr_code_block.dart';
import 'blocks/spacer_block.dart';
import 'blocks/tenant_header_block.dart';
import 'blocks/totals_block.dart';
import '../qr_encoder.dart';
import 'pdf_render_context.dart';

/// Dispatches template blocks to specialized renderers.
class PdfBlockRenderer {
  PdfBlockRenderer({QrEncoder? qrEncoder})
    : _qrEncoder = qrEncoder ?? const BarcodeQrEncoder();

  final QrEncoder _qrEncoder;

  final _tenantHeader = const TenantHeaderBlock();
  final _documentMeta = const DocumentMetaBlock();
  final _partyDetails = const PartyDetailsBlock();
  final _lineTable = const LineTableBlock();
  final _totals = const TotalsBlock();
  final _paymentDetails = const PaymentDetailsBlock();
  final _notes = const NotesBlock();
  final _footer = const FooterBlock();
  final _assetIdentity = const AssetIdentityBlock();
  final _spacer = const SpacerBlock();
  final _divider = const DividerBlock();

  pw.Widget renderBlock(PdfRenderContext ctx, TemplateBlock block) {
    return switch (block.type) {
      'tenant_header' => _tenantHeader.build(ctx),
      'document_meta' => _documentMeta.build(ctx, block),
      'party_details' => _partyDetails.build(ctx, block),
      'line_table' => _lineTable.build(ctx, block),
      'totals' => _totals.build(ctx, block),
      'payment_details' => _paymentDetails.build(ctx, block),
      'notes' => _notes.build(ctx, block),
      'footer' => _footer.build(ctx),
      'asset_identity' => _assetIdentity.build(ctx, block),
      'qr_code' => QrCodeBlock(encoder: _qrEncoder).build(ctx, block),
      'spacer' => _spacer.build(ctx, block),
      'divider' => _divider.build(ctx),
      _ => pw.SizedBox.shrink(),
    };
  }

  List<pw.Widget> renderBlocks(
    PdfRenderContext ctx,
    List<TemplateBlock> blocks, {
    Set<String> exclude = const {},
  }) {
    final widgets = <pw.Widget>[];
    for (final block in blocks) {
      if (exclude.contains(block.type)) continue;
      widgets.add(renderBlock(ctx, block));
    }
    return widgets;
  }
}
