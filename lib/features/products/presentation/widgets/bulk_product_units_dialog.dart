import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/decimal_parser.dart';
import '../../../inventory/domain/warehouse.dart';
import '../../domain/product_unit_bulk_parser.dart';
import '../../domain/product_unit_form_state.dart';
import '../product_unit_display_helpers.dart';

class BulkProductUnitsResult {
  const BulkProductUnitsResult({
    required this.warehouseId,
    required this.units,
    this.defaultPurchaseCost,
    this.acquiredAt,
  });

  final String warehouseId;
  final List<ProductUnitCreateInput> units;
  final Decimal? defaultPurchaseCost;
  final DateTime? acquiredAt;
}

Future<BulkProductUnitsResult?> showBulkProductUnitsDialog({
  required BuildContext context,
  required List<Warehouse> warehouses,
  required String languageCode,
  required bool canViewCosts,
  required AppLocalizations l10n,
}) {
  return showDialog<BulkProductUnitsResult>(
    context: context,
    builder: (context) => _BulkProductUnitsDialog(
      warehouses: warehouses,
      languageCode: languageCode,
      canViewCosts: canViewCosts,
      l10n: l10n,
    ),
  );
}

class _BulkProductUnitsDialog extends StatefulWidget {
  const _BulkProductUnitsDialog({
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
  State<_BulkProductUnitsDialog> createState() =>
      _BulkProductUnitsDialogState();
}

class _BulkProductUnitsDialogState extends State<_BulkProductUnitsDialog> {
  final _pasteController = TextEditingController();
  final _defaultCostController = TextEditingController();
  final _parser = const ProductUnitBulkParser();

  String? _warehouseId;
  final DateTime _acquired = DateTime.now();
  ProductUnitBulkParseResult? _preview;
  String? _error;

  @override
  void dispose() {
    _pasteController.dispose();
    _defaultCostController.dispose();
    super.dispose();
  }

  void _runPreview() {
    final l10n = widget.l10n;
    final result = _parser.parse(_pasteController.text);
    if (result.hasErrors) {
      setState(() {
        _preview = result;
        _error = _parserErrorMessage(l10n, result.errors.first);
      });
      return;
    }
    if (result.isEmpty) {
      setState(() {
        _preview = result;
        _error = l10n.productUnitParserEmptySerial;
      });
      return;
    }
    setState(() {
      _preview = result;
      _error = null;
    });
  }

  String _parserErrorMessage(AppLocalizations l10n, String code) {
    if (code.startsWith('duplicate_serial_in_input')) {
      return l10n.productUnitParserDuplicate;
    }
    if (code.startsWith('empty_serial')) {
      return l10n.productUnitParserEmptySerial;
    }
    if (code.contains('invalid_cost') || code.contains('negative_cost')) {
      return l10n.productUnitParserInvalidCost;
    }
    if (code == 'bulk_limit_exceeded') {
      return l10n.productUnitErrorBulkLimit;
    }
    return l10n.productValidationFailed;
  }

  void _submit() {
    final l10n = widget.l10n;
    if (_warehouseId == null) {
      setState(() => _error = l10n.productValidationFailed);
      return;
    }

    final preview = _preview ?? _parser.parse(_pasteController.text);
    if (preview.hasErrors || preview.isEmpty) {
      _runPreview();
      return;
    }

    Decimal? defaultCost;
    if (widget.canViewCosts && _defaultCostController.text.trim().isNotEmpty) {
      defaultCost = tryParseDecimal(_defaultCostController.text.trim());
      if (defaultCost == null || defaultCost < Decimal.zero) {
        setState(() => _error = l10n.productUnitParserInvalidCost);
        return;
      }
    }

    final units = preview.rows
        .map(
          (row) => ProductUnitCreateInput(
            serialNumber: row.serialNumber,
            barcode: row.barcode,
            purchaseCost: row.purchaseCost ?? defaultCost,
            acquiredAt: _acquired,
          ),
        )
        .toList();

    Navigator.pop(
      context,
      BulkProductUnitsResult(
        warehouseId: _warehouseId!,
        units: units,
        defaultPurchaseCost: defaultCost,
        acquiredAt: _acquired,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return AlertDialog(
      title: Text(l10n.productUnitBulkAdd),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.productUnitBulkPasteHint),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _pasteController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _runPreview,
                  child: Text(l10n.productUnitBulkPreview),
                ),
              ],
            ),
            if (widget.canViewCosts) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _defaultCostController,
                decoration: InputDecoration(
                  labelText: l10n.productUnitFieldPurchaseCost,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            if (_preview != null && _preview!.rows.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.productUnitBulkPreview}: ${_preview!.rows.length}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  itemCount: _preview!.rows.length,
                  itemBuilder: (context, index) {
                    final row = _preview!.rows[index];
                    return ListTile(
                      dense: true,
                      title: Text(row.serialNumber),
                      subtitle: Text(row.barcode ?? ''),
                    );
                  },
                ),
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          onPressed: _submit,
          child: Text(l10n.productUnitBulkConfirm),
        ),
      ],
    );
  }
}
