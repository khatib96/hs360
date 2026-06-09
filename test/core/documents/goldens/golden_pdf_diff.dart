import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'golden_policy.dart';

abstract final class GoldenPdfDiff {
  static GoldenPdfDiffResult compare({
    required Uint8List expectedBytes,
    required Uint8List actualBytes,
    required String goldenLabel,
  }) {
    final expected = img.decodePng(expectedBytes);
    final actual = img.decodePng(actualBytes);
    if (expected == null || actual == null) {
      return GoldenPdfDiffResult.failed(
        'Could not decode PNG for $goldenLabel',
      );
    }
    if (expected.width != actual.width || expected.height != actual.height) {
      return GoldenPdfDiffResult.failed(
        'Dimension mismatch for $goldenLabel: '
        'expected ${expected.width}x${expected.height}, '
        'actual ${actual.width}x${actual.height}',
      );
    }

    var differentPixels = 0;
    final totalPixels = expected.width * expected.height;
    for (var y = 0; y < expected.height; y++) {
      for (var x = 0; x < expected.width; x++) {
        final expectedPixel = expected.getPixel(x, y);
        final actualPixel = actual.getPixel(x, y);
        if ((expectedPixel.r - actualPixel.r).abs() >
                GoldenPolicy.channelDeltaTolerance ||
            (expectedPixel.g - actualPixel.g).abs() >
                GoldenPolicy.channelDeltaTolerance ||
            (expectedPixel.b - actualPixel.b).abs() >
                GoldenPolicy.channelDeltaTolerance ||
            (expectedPixel.a - actualPixel.a).abs() >
                GoldenPolicy.channelDeltaTolerance) {
          differentPixels++;
        }
      }
    }

    final percent = (differentPixels / totalPixels) * 100;
    if (percent > GoldenPolicy.maxDifferentPixelPercent) {
      return GoldenPdfDiffResult.failed(
        'Pixel diff for $goldenLabel: $differentPixels/$totalPixels '
        '(${percent.toStringAsFixed(3)}%) exceeds '
        '${GoldenPolicy.maxDifferentPixelPercent}%',
      );
    }
    return GoldenPdfDiffResult.passed();
  }
}

class GoldenPdfDiffResult {
  const GoldenPdfDiffResult._({required this.passed, this.message});

  factory GoldenPdfDiffResult.passed() =>
      const GoldenPdfDiffResult._(passed: true);

  factory GoldenPdfDiffResult.failed(String message) =>
      GoldenPdfDiffResult._(passed: false, message: message);

  final bool passed;
  final String? message;
}
