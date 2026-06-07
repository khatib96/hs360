import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../errors/scan_exception.dart';
import 'scan_controller.dart';

Future<void> showMobileScanSheet(
  BuildContext context, {
  ValueChanged<String>? onResolved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => MobileScanSheet(onResolved: onResolved),
  );
}

class MobileScanSheet extends ConsumerStatefulWidget {
  const MobileScanSheet({this.onResolved, super.key});

  final ValueChanged<String>? onResolved;

  @override
  ConsumerState<MobileScanSheet> createState() => _MobileScanSheetState();
}

class _MobileScanSheetState extends ConsumerState<MobileScanSheet> {
  final _controller = MobileScannerController();
  var _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .firstOrNull;

    if (raw == null) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(scanControllerProvider.notifier).resolve(raw);
      final state = ref.read(scanControllerProvider);
      if (state is ScanSuccess && mounted) {
        widget.onResolved?.call(raw);
        Navigator.of(context).pop();
      }
    } on ScanException {
      // Failure state is set on the controller; keep sheet open for retry.
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scanState = ref.watch(scanControllerProvider);
    final errorMessage = scanState is ScanFailure
        ? _scanErrorMessage(l10n, scanState.errorCode)
        : null;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.scanMobileTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleBarcode,
            ),
          ),
        ],
      ),
    );
  }

  String _scanErrorMessage(AppLocalizations l10n, String code) {
    return switch (code) {
      ScanException.scanAmbiguous => l10n.scanErrorAmbiguous,
      ScanException.scanNotFound => l10n.scanErrorNotFound,
      ScanException.permissionDenied => l10n.scanErrorPermissionDenied,
      _ => l10n.scanErrorUnknown,
    };
  }
}
