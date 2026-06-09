import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:integration_test/integration_test_driver.dart';
import 'package:path/path.dart' as p;

import '../test/core/documents/goldens/golden_pdf_diff.dart';

const _expectedGoldenNames = <String>{
  'sales_invoice_a4_no_logo',
  'sales_invoice_a4_with_logo',
  'customer_statement_a4_no_logo',
  'customer_statement_a4_with_logo',
  'customer_statement_a4_ar',
  'receipt_voucher_thermal_no_logo',
  'receipt_voucher_thermal_with_logo',
  'asset_tag_label_no_logo',
  'asset_tag_label_with_logo',
  'asset_tag_label_ar',
};

Future<void> main() async {
  await integrationDriver(
    responseDataCallback: _processGoldens,
    writeResponseOnFailure: true,
  );
}

Future<void> _processGoldens(Map<String, dynamic>? data) async {
  if (data == null) {
    throw StateError('PDF golden driver received no response data');
  }

  final platform = data['golden_platform'] as String?;
  if (platform != 'windows' && platform != 'android') {
    throw StateError('Unsupported or missing golden platform: $platform');
  }
  final updateGoldens = data['update_goldens'] as bool? ?? false;
  final rawGoldens = data['pdf_goldens'];
  if (rawGoldens is! Map) {
    throw StateError('PDF golden response is missing pdf_goldens');
  }

  final encodedGoldens = rawGoldens.cast<String, dynamic>();
  final actualNames = encodedGoldens.keys.toSet();
  if (actualNames.length != _expectedGoldenNames.length ||
      !actualNames.containsAll(_expectedGoldenNames)) {
    throw StateError(
      'PDF golden set mismatch: expected '
      '${_expectedGoldenNames.toList()..sort()}, '
      'received ${actualNames.toList()..sort()}',
    );
  }

  final repoRoot = Directory.current.path;
  final baselineDir = Directory(
    p.join(repoRoot, 'test', 'core', 'documents', 'goldens', platform),
  );
  await baselineDir.create(recursive: true);

  final failures = <String>[];
  for (final name in _expectedGoldenNames.toList()..sort()) {
    final encoded = encodedGoldens[name];
    if (encoded is! String || encoded.isEmpty) {
      failures.add('$name: missing PNG bytes');
      continue;
    }

    final actualBytes = base64Decode(encoded);
    final baselineFile = File(p.join(baselineDir.path, '$name.png'));
    if (updateGoldens) {
      await baselineFile.writeAsBytes(actualBytes, flush: true);
      continue;
    }
    if (!await baselineFile.exists()) {
      failures.add('$name: baseline does not exist at ${baselineFile.path}');
      continue;
    }

    final result = GoldenPdfDiff.compare(
      expectedBytes: Uint8List.fromList(await baselineFile.readAsBytes()),
      actualBytes: actualBytes,
      goldenLabel: baselineFile.path,
    );
    if (!result.passed) {
      final failureDir = Directory(p.join(baselineDir.parent.path, 'failures'));
      await failureDir.create(recursive: true);
      await File(
        p.join(failureDir.path, '${name}_$platform.png'),
      ).writeAsBytes(actualBytes, flush: true);
      failures.add('$name: ${result.message}');
    }
  }

  if (failures.isNotEmpty) {
    throw StateError('PDF golden comparison failed:\n${failures.join('\n')}');
  }
}
