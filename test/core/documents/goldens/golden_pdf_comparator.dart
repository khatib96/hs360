import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'golden_pdf_diff.dart';

/// Host-side golden comparator for rasterized PDF PNGs (M3 plan §11.3).
class GoldenPdfComparator extends LocalFileComparator {
  GoldenPdfComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = await File.fromUri(golden).readAsBytes();
    final result = GoldenPdfDiff.compare(
      expectedBytes: goldenBytes,
      actualBytes: imageBytes,
      goldenLabel: '$golden',
    );
    if (!result.passed) {
      await _writeFailureImage(golden: golden, actualBytes: imageBytes);
      throw FlutterError(result.message ?? 'Golden comparison failed');
    }
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    await File.fromUri(golden).create(recursive: true);
    await File.fromUri(golden).writeAsBytes(imageBytes);
  }

  Future<void> _writeFailureImage({
    required Uri golden,
    required Uint8List actualBytes,
  }) async {
    final goldenPath = p.fromUri(golden);
    final failuresDir = p.join(p.dirname(goldenPath), '..', 'failures');
    await Directory(failuresDir).create(recursive: true);

    final goldenName = p.basenameWithoutExtension(goldenPath);
    final platform = _platformLabel();
    final failurePath = p.normalize(
      p.join(failuresDir, '${goldenName}_$platform.png'),
    );
    await File(failurePath).writeAsBytes(actualBytes);
  }

  String _platformLabel() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return Platform.operatingSystem;
  }
}
