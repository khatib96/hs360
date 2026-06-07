import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../products_error_messages.dart';

class ProductUnitSerialCorrectionCard extends StatefulWidget {
  const ProductUnitSerialCorrectionCard({
    required this.l10n,
    required this.canCorrect,
    required this.isSubmitting,
    required this.errorCode,
    required this.showSuccess,
    required this.onSubmit,
    super.key,
  });

  final AppLocalizations l10n;
  final bool canCorrect;
  final bool isSubmitting;
  final String? errorCode;
  final bool showSuccess;
  final Future<void> Function(String newSerial, String reason) onSubmit;

  @override
  State<ProductUnitSerialCorrectionCard> createState() =>
      _ProductUnitSerialCorrectionCardState();
}

class _ProductUnitSerialCorrectionCardState
    extends State<ProductUnitSerialCorrectionCard> {
  final _serialController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _serialController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.onSubmit(
      _serialController.text,
      _reasonController.text,
    );
    if (widget.showSuccess && mounted) {
      _serialController.clear();
      _reasonController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canCorrect) {
      return const SizedBox.shrink(key: Key('product-unit-serial-correction-hidden'));
    }

    final theme = Theme.of(context);
    return Card(
      key: const Key('product-unit-serial-correction-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.l10n.productUnitSerialCorrectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: widget.l10n.productUnitSerialCorrectionNewSerial,
              controller: _serialController,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: widget.l10n.productUnitSerialCorrectionReason,
              controller: _reasonController,
            ),
            if (widget.errorCode != null) ...[
              const SizedBox(height: 8),
              Text(
                productsErrorMessage(widget.l10n, widget.errorCode!),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (widget.showSuccess) ...[
              const SizedBox(height: 8),
              Text(
                widget.l10n.productUnitSerialCorrectionSuccess,
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: widget.isSubmitting ? null : _submit,
                child: widget.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.l10n.productUnitSerialCorrectionSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
