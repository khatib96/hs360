import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test/core/documents/goldens/golden_pdf_comparator.dart';

/// Host-only golden comparator for PDF raster tests (M3 plan §11.1).
Future<void> testExecutable(Future<void> Function() testMain) async {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    final testUri = Platform.script;
    goldenFileComparator = GoldenPdfComparator(testUri);
  }
  await testMain();
}
