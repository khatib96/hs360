import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Encodes QR payloads for asset labels.
abstract class QrEncoder {
  pw.Widget encode(String payload, {double size = 80});
}

class BarcodeQrEncoder implements QrEncoder {
  const BarcodeQrEncoder();

  @override
  pw.Widget encode(String payload, {double size = 80}) {
    return pw.BarcodeWidget(
      barcode: pw.Barcode.qrCode(),
      data: payload,
      width: size,
      height: size,
      drawText: false,
    );
  }
}

class FakeQrEncoder implements QrEncoder {
  const FakeQrEncoder();

  @override
  pw.Widget encode(String payload, {double size = 80}) {
    return pw.Container(
      width: size,
      height: size,
      color: PdfColors.grey300,
      alignment: pw.Alignment.center,
      child: pw.Text(
        payload,
        style: const pw.TextStyle(fontSize: 6),
        maxLines: 4,
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}

/// Returns raw PNG bytes for tests that need binary output.
Uint8List fakeQrPngBytes() =>
    Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]);
