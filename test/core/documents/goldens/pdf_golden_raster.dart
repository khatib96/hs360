import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'golden_policy.dart';

/// Rasterizes the first PDF page to PNG at the locked golden DPI.
abstract final class PdfGoldenRaster {
  static Future<Uint8List> rasterFirstPage({
    required Uint8List pdfBytes,
    required int expectedWidth,
    required int expectedHeight,
  }) async {
    await for (final page in Printing.raster(
      pdfBytes,
      pages: const [0],
      dpi: GoldenPolicy.dpi.toDouble(),
    )) {
      if (page.width != expectedWidth || page.height != expectedHeight) {
        throw StateError(
          'Raster size ${page.width}x${page.height} does not match '
          'expected ${expectedWidth}x$expectedHeight at ${GoldenPolicy.dpi} DPI',
        );
      }
      return page.toPng();
    }
    throw StateError('PDF has no pages to rasterize');
  }

  /// Rasterizes the first PDF page without dimension pre-check (thermal).
  static Future<Uint8List> rasterFirstPageBytes(Uint8List pdfBytes) async {
    await for (final page in Printing.raster(
      pdfBytes,
      pages: const [0],
      dpi: GoldenPolicy.dpi.toDouble(),
    )) {
      return page.toPng();
    }
    throw StateError('PDF has no pages to rasterize');
  }
}
