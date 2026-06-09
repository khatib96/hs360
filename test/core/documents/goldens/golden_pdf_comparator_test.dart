import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'golden_pdf_comparator.dart';

void main() {
  test('accepts a pixel difference within the 0.5 percent policy', () async {
    final temp = await Directory.systemTemp.createTemp('hs360_golden_');
    addTearDown(() => temp.delete(recursive: true));

    final expected = img.Image(width: 20, height: 20)
      ..clear(img.ColorRgba8(255, 255, 255, 255));
    final actual = img.Image.from(expected)..setPixelRgba(0, 0, 0, 0, 0, 255);
    final golden = File(p.join(temp.path, 'expected.png'));
    await golden.writeAsBytes(img.encodePng(expected));

    final comparator = GoldenPdfComparator(
      Uri.file(p.join(temp.path, 'golden_test.dart')),
    );
    expect(await comparator.compare(img.encodePng(actual), golden.uri), isTrue);
  });

  test('rejects dimension mismatch immediately', () async {
    final temp = await Directory.systemTemp.createTemp('hs360_golden_');
    addTearDown(() => temp.delete(recursive: true));

    final expected = img.Image(width: 20, height: 20);
    final actual = img.Image(width: 21, height: 20);
    final golden = File(p.join(temp.path, 'expected.png'));
    await golden.writeAsBytes(img.encodePng(expected));

    final comparator = GoldenPdfComparator(
      Uri.file(p.join(temp.path, 'golden_test.dart')),
    );
    expect(
      () => comparator.compare(img.encodePng(actual), golden.uri),
      throwsA(isA<FlutterError>()),
    );
  });
}
