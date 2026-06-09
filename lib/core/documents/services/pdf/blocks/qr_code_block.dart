import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../domain/document_template.dart';
import '../../qr_encoder.dart';
import '../pdf_render_context.dart';

class QrCodeBlock {
  const QrCodeBlock({QrEncoder? encoder})
    : _encoder = encoder ?? const BarcodeQrEncoder();

  final QrEncoder _encoder;

  pw.Widget build(PdfRenderContext ctx, TemplateBlock block) {
    final serial = ctx.resolver.resolve('unit.serial');
    if (serial.isEmpty) return pw.SizedBox.shrink();
    final size = ctx.layout.qrSizeMm * PdfPageFormat.mm;
    return pw.Center(child: _encoder.encode(serial, size: size));
  }
}
