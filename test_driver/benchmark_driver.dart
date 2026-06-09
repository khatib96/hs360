import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart' as p;
import 'package:vm_service/vm_service.dart' as vms;

const _benchmarkExtensions = <String>[
  'ext.benchmark.metadata',
  'ext.benchmark.runRender',
  'ext.benchmark.finish',
];
Future<void> waitForBenchmarkExtensions(
  FlutterDriver driver, {
  required List<String> required,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final isolate = await driver.serviceClient.getIsolate(
      driver.appIsolate.id!,
    );
    final rpcs = isolate.extensionRPCs ?? const <String>[];
    if (required.every(rpcs.contains)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  final isolate = await driver.serviceClient.getIsolate(driver.appIsolate.id!);
  final rpcs = isolate.extensionRPCs ?? const <String>[];
  throw StateError(
    'Timed out waiting for benchmark extensions. '
    'Missing: ${required.where((e) => !rpcs.contains(e)).join(', ')}',
  );
}

Future<void> main() async {
  FlutterDriver? driver;
  try {
    driver = await FlutterDriver.connect();

    await waitForBenchmarkExtensions(driver, required: _benchmarkExtensions);

    final metaResponse = await driver.serviceClient.callServiceExtension(
      'ext.benchmark.metadata',
      isolateId: driver.appIsolate.id,
    );
    final meta = _decodeExtensionJson(metaResponse);

    final platform = meta['platform'] as String? ?? Platform.operatingSystem;
    final targetPid = meta['pid'] as int?;
    final statementRowCap = meta['statement_row_cap'] as int? ?? 1000;
    final warmupRuns = meta['warmup_runs'] as int? ?? 1;
    final measuredRuns = meta['measured_runs'] as int? ?? 3;
    final flutterVersion = meta['flutter_version'] as String? ?? 'unknown';
    final gitSha = meta['git_sha'] as String? ?? 'unknown';
    final adbExecutable = meta['adb_path'] as String? ?? 'adb';

    final thresholds = await _loadThresholds();
    final sampler = _MemorySampler(
      platform: platform,
      targetPid: targetPid,
      adbExecutable: adbExecutable,
    );
    final runs = <Map<String, dynamic>>[];

    for (var i = 1; i <= warmupRuns; i++) {
      runs.add(
        await _executeRun(
          driver: driver,
          sampler: sampler,
          run: i,
          kind: 'warmup',
        ),
      );
    }

    for (var i = 1; i <= measuredRuns; i++) {
      runs.add(
        await _executeRun(
          driver: driver,
          sampler: sampler,
          run: i,
          kind: 'measured',
        ),
      );
    }

    final measured = runs.where((r) => r['kind'] == 'measured').toList();
    final durations = measured.map((r) => r['duration_ms'] as int).toList()
      ..sort();
    final durationMedian = durations.isEmpty
        ? 0
        : durations[durations.length ~/ 2];
    final durationMax = durations.isEmpty ? 0 : durations.reduce(max);

    final memoryPeaks = measured
        .map((r) => r['memory_peak_bytes'] as int? ?? 0)
        .toList();
    final memoryPeak = memoryPeaks.isEmpty ? 0 : memoryPeaks.reduce(max);

    final pdfBytesMax = measured
        .map((r) => r['pdf_bytes'] as int? ?? 0)
        .fold<int>(0, max);

    final failures = <String>[];
    if (measured.length != measuredRuns) {
      failures.add(
        'measured run count ${measured.length} != expected $measuredRuns',
      );
    }
    for (final run in measured) {
      final runNumber = run['run'];
      if (run['line_count'] != statementRowCap) {
        failures.add(
          'run $runNumber line_count ${run['line_count']} != '
          '$statementRowCap',
        );
      }
      if ((run['duration_ms'] as int? ?? 0) <= 0) {
        failures.add('run $runNumber has non-positive duration_ms');
      }
      if ((run['pdf_bytes'] as int? ?? 0) <= 0) {
        failures.add('run $runNumber has non-positive pdf_bytes');
      }
      if ((run['page_count'] as int? ?? 0) <= 0) {
        failures.add('run $runNumber has non-positive page_count');
      }
      if ((run['memory_peak_bytes'] as int? ?? 0) <= 0) {
        failures.add('run $runNumber has non-positive memory_peak_bytes');
      }
    }
    if (durationMedian > (thresholds['duration_ms_median'] as num)) {
      failures.add(
        'duration_ms median $durationMedian > ${thresholds['duration_ms_median']}',
      );
    }
    if (durationMax > (thresholds['duration_ms_max'] as num)) {
      failures.add(
        'duration_ms max $durationMax > ${thresholds['duration_ms_max']}',
      );
    }
    if (pdfBytesMax > (thresholds['pdf_bytes_max'] as num)) {
      failures.add(
        'pdf_bytes max $pdfBytesMax > ${thresholds['pdf_bytes_max']}',
      );
    }

    if (platform == 'windows') {
      if (memoryPeak > (thresholds['windows_private_bytes_peak'] as num)) {
        failures.add(
          'windows_private_bytes peak $memoryPeak > '
          '${thresholds['windows_private_bytes_peak']}',
        );
      }
    } else if (platform == 'android') {
      if (memoryPeak > (thresholds['android_pss_bytes_peak'] as num)) {
        failures.add(
          'android_pss_bytes peak $memoryPeak > '
          '${thresholds['android_pss_bytes_peak']}',
        );
      }
    }

    final result = <String, dynamic>{
      'flutter_version': flutterVersion,
      'dart_version': Platform.version.split(' ').first,
      'git_sha': gitSha,
      'statement_row_cap': statementRowCap,
      'platform': platform,
      'warmup_runs': warmupRuns,
      'measured_runs': measuredRuns,
      'runs': runs,
      'duration_ms_median': durationMedian,
      'duration_ms_max': durationMax,
      'memory_peak_bytes': memoryPeak,
      'pdf_bytes_max': pdfBytesMax,
      'passed': failures.isEmpty,
      if (failures.isNotEmpty) 'failures': failures,
    };

    await _writeResultJson(platform: platform, result: result);
    // ignore: avoid_print
    print('BENCHMARK_JSON:${jsonEncode(result)}');

    if (failures.isNotEmpty) {
      throw StateError('Benchmark thresholds exceeded: ${failures.join('; ')}');
    }

    await driver.serviceClient.callServiceExtension(
      'ext.benchmark.finish',
      isolateId: driver.appIsolate.id,
    );

    await integrationDriver(driver: driver, writeResponseOnFailure: true);
  } catch (e, st) {
    await driver?.close();
    stderr.writeln('benchmark_driver failed: $e\n$st');
    rethrow;
  }
}

Future<Map<String, dynamic>> _executeRun({
  required FlutterDriver driver,
  required _MemorySampler sampler,
  required int run,
  required String kind,
}) async {
  await sampler.start();
  try {
    final response = await driver.serviceClient.callServiceExtension(
      'ext.benchmark.runRender',
      isolateId: driver.appIsolate.id,
      args: {'run': '$run', 'kind': kind},
    );
    final data = _decodeExtensionJson(response);
    final memoryPeak = await sampler.stop();
    return {
      'run': data['run'] ?? run,
      'kind': data['kind'] ?? kind,
      'duration_ms': data['duration_ms'] ?? 0,
      'pdf_bytes': data['pdf_bytes'] ?? 0,
      'page_count': data['page_count'] ?? 0,
      'line_count': data['line_count'] ?? 0,
      'memory_peak_bytes': memoryPeak,
    };
  } catch (e) {
    await sampler.stop();
    rethrow;
  }
}

Map<String, dynamic> _decodeExtensionJson(vms.Response response) {
  final json = response.json;
  if (json == null) {
    throw StateError('Benchmark extension returned empty JSON');
  }
  return Map<String, dynamic>.from(json);
}

Future<Map<String, dynamic>> _loadThresholds() async {
  final repoRoot = Directory.current.path;
  final path = p.join(
    repoRoot,
    'test',
    'benchmark',
    'statement_perf_thresholds.json',
  );
  final raw = await File(path).readAsString();
  return jsonDecode(raw) as Map<String, dynamic>;
}

Future<void> _writeResultJson({
  required String platform,
  required Map<String, dynamic> result,
}) async {
  final repoRoot = Directory.current.path;
  final resultsDir = p.join(repoRoot, 'scripts', 'benchmark', 'results');
  await Directory(resultsDir).create(recursive: true);
  final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    ':',
    '-',
  );
  final filePath = p.join(
    resultsDir,
    'statement_perf_${platform}_$timestamp.json',
  );
  await File(
    filePath,
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
}

class _MemorySampler {
  _MemorySampler({
    required this.platform,
    required this.adbExecutable,
    this.targetPid,
  });

  final String platform;
  final String adbExecutable;
  final int? targetPid;

  final List<int> _samples = [];
  bool _sampling = false;
  Future<void>? _samplingLoop;
  Object? _samplingError;

  Future<void> start() async {
    _samples.clear();
    _samplingError = null;
    _sampling = true;
    if (platform == 'windows') {
      await _sampleWindows();
      _samplingLoop = _runLoop(
        interval: const Duration(milliseconds: 50),
        sample: _sampleWindows,
      );
      return;
    }
    if (platform == 'android') {
      await _sampleAndroid();
      _samplingLoop = _runLoop(
        interval: const Duration(milliseconds: 200),
        sample: _sampleAndroid,
      );
      return;
    }
    throw StateError('Unsupported benchmark platform: $platform');
  }

  Future<int> stop() async {
    _sampling = false;
    await _samplingLoop;
    _samplingLoop = null;
    final error = _samplingError;
    if (error != null) {
      throw StateError('Memory sampler failed on $platform: $error');
    }
    if (_samples.isEmpty) {
      throw StateError('Memory sampler collected zero samples on $platform');
    }
    return _samples.reduce(max);
  }

  Future<void> _runLoop({
    required Duration interval,
    required Future<void> Function() sample,
  }) async {
    while (_sampling) {
      await Future<void>.delayed(interval);
      if (!_sampling) break;
      try {
        await sample();
      } catch (error) {
        _samplingError ??= error;
        _sampling = false;
      }
    }
  }

  Future<void> _sampleWindows() async {
    final pid = targetPid;
    if (pid == null) return;
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      '(Get-Process -Id $pid -ErrorAction SilentlyContinue).PrivateMemorySize64',
    ]);
    if (result.exitCode != 0) return;
    final value = int.tryParse((result.stdout as String).trim());
    if (value != null && value > 0) {
      _samples.add(value);
    }
  }

  Future<void> _sampleAndroid() async {
    final pidResult = await Process.run(adbExecutable, [
      'shell',
      'pidof',
      'com.hs360.hs360',
    ]);
    if (pidResult.exitCode != 0) return;
    final devicePid = (pidResult.stdout as String).trim();
    if (devicePid.isEmpty) return;
    if (targetPid != null && devicePid != '${targetPid!}') {
      return;
    }

    final result = await Process.run(adbExecutable, [
      'shell',
      'dumpsys',
      'meminfo',
      'com.hs360.hs360',
    ]);
    if (result.exitCode != 0) {
      throw StateError('adb dumpsys meminfo failed: ${result.stderr}');
    }

    final pssKb = _parseTotalPssKb(result.stdout as String);
    if (pssKb == null) {
      throw StateError('Failed to parse TOTAL PSS from dumpsys meminfo');
    }
    _samples.add(pssKb * 1024);
  }
}

int? _parseTotalPssKb(String meminfo) {
  for (final line in meminfo.split('\n')) {
    final trimmed = line.trim();
    final summary = RegExp(r'^TOTAL PSS:\s*(\d+)').firstMatch(trimmed);
    if (summary != null) return int.tryParse(summary.group(1)!);

    final table = RegExp(r'^TOTAL\s+(\d+)\s+').firstMatch(trimmed);
    if (table != null) return int.tryParse(table.group(1)!);
  }
  return null;
}
