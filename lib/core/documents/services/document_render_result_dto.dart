import 'dart:isolate';
import 'dart:typed_data';

/// Serializable render output returned from the worker isolate.
class DocumentRenderResultDto {
  const DocumentRenderResultDto({
    required this.pdfBytes,
    required this.pageCount,
    required this.paperKind,
    required this.title,
    required this.pageWidthMm,
    required this.pageHeightMm,
    this.thermalHeightMm,
  });

  final TransferableTypedData pdfBytes;
  final int pageCount;
  final String paperKind;
  final String title;
  final double pageWidthMm;
  final double pageHeightMm;
  final double? thermalHeightMm;

  Uint8List materializePdfBytes() => pdfBytes.materialize().asUint8List();
}
