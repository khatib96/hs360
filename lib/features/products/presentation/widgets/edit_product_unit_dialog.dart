import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/product_unit.dart';
import '../../domain/product_unit_form_state.dart';
import '../../domain/product_unit_health_status.dart';
import '../product_unit_display_helpers.dart';

class ProductUnitSafeEditResult {
  const ProductUnitSafeEditResult({required this.input});

  final ProductUnitSafeEditInput input;
}

Future<ProductUnitSafeEditResult?> showEditProductUnitDialog({
  required BuildContext context,
  required ProductUnit unit,
  required AppLocalizations l10n,
}) {
  return showDialog<ProductUnitSafeEditResult>(
    context: context,
    builder: (context) => _EditProductUnitDialog(unit: unit, l10n: l10n),
  );
}

class _EditProductUnitDialog extends StatefulWidget {
  const _EditProductUnitDialog({required this.unit, required this.l10n});

  final ProductUnit unit;
  final AppLocalizations l10n;

  @override
  State<_EditProductUnitDialog> createState() => _EditProductUnitDialogState();
}

class _EditProductUnitDialogState extends State<_EditProductUnitDialog> {
  late final TextEditingController _barcodeController;
  late final TextEditingController _notesController;
  late ProductUnitHealthStatus _health;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.unit.barcode ?? '');
    _notesController = TextEditingController(text: widget.unit.notes ?? '');
    _health = widget.unit.healthStatus;
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return AlertDialog(
      title: Text(l10n.productUnitEdit),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.productUnitFieldSerial}: ${widget.unit.serialNumber}'),
            const SizedBox(height: 12),
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(labelText: l10n.productUnitFieldBarcode),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ProductUnitHealthStatus>(
              initialValue: _health,
              decoration: InputDecoration(labelText: l10n.productUnitFieldHealth),
              items: ProductUnitHealthStatus.values
                  .map(
                    (h) => DropdownMenuItem(
                      value: h,
                      child: Text(unitHealthLabel(l10n, h)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _health = v);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: l10n.productUnitFieldNotes),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            final healthChanged = _health != widget.unit.healthStatus;
            Navigator.pop(
              context,
              ProductUnitSafeEditResult(
                input: ProductUnitSafeEditInput(
                  barcode: _barcodeController.text,
                  notes: _notesController.text,
                  healthStatus: healthChanged ? _health : null,
                ),
              ),
            );
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
