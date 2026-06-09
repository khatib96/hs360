import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import 'scan_controller.dart';

/// Keyboard-wedge scanner input: resolves on Enter and clears the field.
class ScanInput extends ConsumerStatefulWidget {
  const ScanInput({this.onResolved, this.autofocus = false, super.key});

  final ValueChanged<String>? onResolved;
  final bool autofocus;

  @override
  ConsumerState<ScanInput> createState() => _ScanInputState();
}

class _ScanInputState extends ConsumerState<ScanInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    await ref.read(scanControllerProvider.notifier).resolve(code);
    widget.onResolved?.call(code);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scanState = ref.watch(scanControllerProvider);

    return TextField(
      key: const Key('scan-input-field'),
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        labelText: l10n.scanInputLabel,
        suffixIcon: scanState is ScanLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(icon: const Icon(Icons.search), onPressed: _submit),
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
    );
  }
}
