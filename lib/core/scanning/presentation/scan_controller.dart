import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../errors/scan_exception.dart';
import '../data/scan_repository.dart';
import '../domain/scan_result.dart';

part 'scan_controller.g.dart';

sealed class ScanState {
  const ScanState();
}

class ScanIdle extends ScanState {
  const ScanIdle();
}

class ScanLoading extends ScanState {
  const ScanLoading();
}

class ScanSuccess extends ScanState {
  const ScanSuccess(this.result);

  final ScanResult result;
}

class ScanFailure extends ScanState {
  const ScanFailure(this.errorCode);

  final String errorCode;
}

@riverpod
class ScanController extends _$ScanController {
  @override
  ScanState build() => const ScanIdle();

  Future<void> resolve(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      state = const ScanFailure(ScanException.validationFailed);
      return;
    }

    state = const ScanLoading();
    try {
      final result = await ref
          .read(scanRepositoryProvider)
          .resolveScanCode(trimmed);
      state = ScanSuccess(result);
    } on ScanException catch (e) {
      state = ScanFailure(e.code);
    } catch (_) {
      state = const ScanFailure(ScanException.unknown);
    }
  }

  void reset() {
    state = const ScanIdle();
  }
}
