import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Gate F / integration host driver.
///
/// Saves `binding.takeScreenshot` bytes to `P7M12_EVIDENCE_DIR` on the Mac.
/// Rejects empty PNG buffers so zero-byte evidence cannot pass.
Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (String name, List<int> image, [Map<String, Object?>? args]) async {
          if (image.isEmpty) {
            stderr.writeln('Gate F screenshot rejected (empty): $name');
            return false;
          }
          // PNG signature
          if (image.length < 8 ||
              image[0] != 0x89 ||
              image[1] != 0x50 ||
              image[2] != 0x4E ||
              image[3] != 0x47) {
            stderr.writeln('Gate F screenshot rejected (not PNG): $name');
            return false;
          }
          // Minimum useful size for a phone frame (~2KB).
          if (image.length < 2048) {
            stderr.writeln(
              'Gate F screenshot rejected (too small ${image.length}B): $name',
            );
            return false;
          }

          final dir = Platform.environment['P7M12_EVIDENCE_DIR'];
          if (dir == null || dir.isEmpty) {
            stderr.writeln('P7M12_EVIDENCE_DIR missing; cannot save $name');
            return false;
          }
          final outDir = Directory(dir)..createSync(recursive: true);
          final file = File('${outDir.path}/$name.png');
          await file.writeAsBytes(image, flush: true);
          stdout.writeln('P7M12_EVIDENCE_PNG=${file.path}');
          return file.lengthSync() >= 2048;
        },
  );
}
