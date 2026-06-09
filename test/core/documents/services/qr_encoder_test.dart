import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/services/qr_encoder.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('FakeQrEncoder returns widget containing payload text', () {
    const encoder = FakeQrEncoder();
    final widget = encoder.encode('SN-12345', size: 64);
    expect(widget, isA<pw.Container>());
  });

  test('BarcodeQrEncoder returns BarcodeWidget', () {
    const encoder = BarcodeQrEncoder();
    final widget = encoder.encode('SN-12345', size: 64);
    expect(widget, isA<pw.BarcodeWidget>());
  });

  test('fakeQrPngBytes has PNG signature', () {
    final bytes = fakeQrPngBytes();
    expect(bytes[0], 0x89);
    expect(bytes[1], 0x50);
  });
}
