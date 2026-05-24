import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/decimal_parser.dart';
import '../../../inventory/domain/warehouse.dart';
import '../../domain/product_unit_form_state.dart';
import '../../domain/product_unit_health_status.dart';
import '../product_unit_display_helpers.dart';

class AddProductUnitResult {
  const AddProductUnitResult({
    required this.warehouseId,
    required this.input,
  });

  final String warehouseId;
  final ProductUnitCreateInput input;
}

Future<AddProductUnitResult?> showAddProductUnitDialog({
  required BuildContext context,
  required List<Warehouse> warehouses,
  required String languageCode,
  required bool canViewCosts,
  required AppLocalizations l10n,
}) {
  return showDialog<AddProductUnitResult>(
    context: context,
    builder: (context) => _AddProductUnitDialog(
      warehouses: warehouses,
      languageCode: languageCode,
      canViewCosts: canViewCosts,
      l10n: l10n,
    ),
  );
}

class _AddProductUnitDialog extends StatefulWidget {
  const _AddProductUnitDialog({
    required this.warehouses,
    required this.languageCode,
    required this.canViewCosts,
    required this.l10n,
  });

  final List<Warehouse> warehouses;
  final String languageCode;
  final bool canViewCosts;
  final AppLocalizations l10n;

  @override
  State<_AddProductUnitDialog> createState() => _AddProductUnitDialogState();
}

class _AddProductUnitDialogState extends State<_AddProductUnitDialog> {
  final _serialController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  String? _warehouseId;
  DateTime _acquired = DateTime.now();
  ProductUnitHealthStatus _health = ProductUnitHealthStatus.good;
  String? _error;

  @override
  void dispose() {
    _serialController.dispose();
    _barcodeController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return AlertDialog(
      title: Text(l10n.productUnitAdd),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _serialController,
                decoration: InputDecoration(
                  labelText: l10n.productUnitFieldSerial,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: l10n.productUnitFieldBarcode,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _warehouseId,
                decoration: InputDecoration(
                  labelText: l10n.productUnitFieldWarehouse,
                ),
                items: widget.warehouses
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          localizedWarehouseName(w, widget.languageCode),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _warehouseId = v),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.productUnitFieldAcquired),
                subtitle: Text(_formatDate(_acquired)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _acquired,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _acquired = picked);
                    }
                  },
                ),
              ),
              if (widget.canViewCosts) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _costController,
                  decoration: InputDecoration(
                    labelText: l10n.productUnitFieldPurchaseCost,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<ProductUnitHealthStatus>(
                initialValue: _health,
                decoration: InputDecoration(
                  labelText: l10n.productUnitFieldHealth,
                ),
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
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }

  void _submit() {
    final l10n = widget.l10n;
    final serial = _serialController.text.trim();
    if (serial.isEmpty) {
      setState(() => _error = l10n.productUnitParserEmptySerial);
      return;
    }
    if (_warehouseId == null) {
      setState(() => _error = l10n.productValidationFailed);
      return;
    }

    Decimal? cost;
    if (widget.canViewCosts && _costController.text.trim().isNotEmpty) {
      cost = tryParseDecimal(_costController.text.trim());
      if (cost == null || cost < Decimal.zero) {
        setState(() => _error = l10n.productUnitParserInvalidCost);
        return;
      }
    }

    Navigator.pop(
      context,
      AddProductUnitResult(
        warehouseId: _warehouseId!,
        input: ProductUnitCreateInput(
          serialNumber: serial,
          barcode: _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim(),
          purchaseCost: cost,
          acquiredAt: _acquired,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          healthStatus: _health,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
