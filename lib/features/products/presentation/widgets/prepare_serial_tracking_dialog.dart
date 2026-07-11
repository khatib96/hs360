import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../inventory/domain/inventory_balance.dart';
import '../../../inventory/domain/warehouse.dart';
import '../../domain/product.dart';
import '../../domain/product_stock_summary.dart';
import '../product_unit_display_helpers.dart';

class PrepareSerialTrackingResult {
  const PrepareSerialTrackingResult({
    required this.warehouseId,
    required this.serials,
    required this.reason,
  });

  final String warehouseId;
  final List<String> serials;
  final String reason;
}

Future<PrepareSerialTrackingResult?> showPrepareSerialTrackingDialog({
  required BuildContext context,
  required Product product,
  required ProductStockSummary? stock,
  required List<Warehouse> warehouses,
  required String languageCode,
  required AppLocalizations l10n,
}) {
  return showDialog<PrepareSerialTrackingResult>(
    context: context,
    builder: (context) => _PrepareSerialTrackingDialog(
      product: product,
      stock: stock,
      warehouses: warehouses,
      languageCode: languageCode,
      l10n: l10n,
    ),
  );
}

class _PrepareSerialTrackingDialog extends StatefulWidget {
  const _PrepareSerialTrackingDialog({
    required this.product,
    required this.stock,
    required this.warehouses,
    required this.languageCode,
    required this.l10n,
  });

  final Product product;
  final ProductStockSummary? stock;
  final List<Warehouse> warehouses;
  final String languageCode;
  final AppLocalizations l10n;

  @override
  State<_PrepareSerialTrackingDialog> createState() =>
      _PrepareSerialTrackingDialogState();
}

class _PrepareSerialTrackingDialogState
    extends State<_PrepareSerialTrackingDialog> {
  final _prefixController = TextEditingController();
  final _startController = TextEditingController(text: '1');
  final _countController = TextEditingController();
  final _serialsController = TextEditingController();
  final _reasonController = TextEditingController();

  String? _warehouseId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefixController.text = widget.product.sku.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '',
    );
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _startController.dispose();
    _countController.dispose();
    _serialsController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _selectWarehouse(String? warehouseId) {
    final qty = _availableQty(warehouseId);
    setState(() {
      _warehouseId = warehouseId;
      _countController.text = qty?.toString() ?? '';
      _error = null;
    });
  }

  void _generate() {
    final l10n = widget.l10n;
    final prefix = _prefixController.text.trim();
    final start = int.tryParse(_startController.text.trim());
    final count = int.tryParse(_countController.text.trim());
    final expected = _availableQty(_warehouseId);

    if (_warehouseId == null ||
        prefix.isEmpty ||
        start == null ||
        count == null ||
        count < 1 ||
        expected == null ||
        count != expected ||
        count > 500) {
      setState(() => _error = l10n.productSerialTrackingValidation);
      return;
    }

    final width = (start + count - 1).toString().length < 4
        ? 4
        : (start + count - 1).toString().length;
    final serials = [
      for (var i = 0; i < count; i++)
        '$prefix-${(start + i).toString().padLeft(width, '0')}',
    ];
    setState(() {
      _serialsController.text = serials.join('\n');
      _error = null;
    });
  }

  void _submit() {
    final l10n = widget.l10n;
    final warehouseId = _warehouseId;
    final expected = _availableQty(warehouseId);
    final serials = _serialsController.text
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final reason = _reasonController.text.trim();

    if (warehouseId == null ||
        expected == null ||
        serials.length != expected ||
        serials.length > 500 ||
        reason.isEmpty ||
        serials.toSet().length != serials.length) {
      setState(() => _error = l10n.productSerialTrackingValidation);
      return;
    }

    Navigator.pop(
      context,
      PrepareSerialTrackingResult(
        warehouseId: warehouseId,
        serials: serials,
        reason: reason,
      ),
    );
  }

  int? _availableQty(String? warehouseId) {
    if (warehouseId == null) return null;
    final balance = _balanceForWarehouse(warehouseId);
    if (balance == null) return null;
    return _wholeNumber(balance.qtyAvailable);
  }

  InventoryBalance? _balanceForWarehouse(String warehouseId) {
    final stock = widget.stock;
    if (stock == null) return null;
    for (final balance in stock.balances) {
      if (balance.warehouseId == warehouseId) return balance;
    }
    return null;
  }

  int? _wholeNumber(Decimal qty) {
    final text = qty.toString();
    final parts = text.split('.');
    if (parts.length == 1) return int.tryParse(parts.first);
    if (parts.length == 2 && RegExp(r'^0+$').hasMatch(parts.last)) {
      return int.tryParse(parts.first);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final stockWarehouses =
        widget.stock?.balances
            .where((b) => _wholeNumber(b.qtyAvailable) != null)
            .where((b) => _wholeNumber(b.qtyAvailable)! > 0)
            .map((b) => b.warehouseId)
            .toSet() ??
        const <String>{};
    final warehouses = widget.warehouses
        .where((w) => stockWarehouses.contains(w.id))
        .toList();

    return AlertDialog(
      title: Text(l10n.productSerialTrackingPrepare),
      content: SizedBox(
        width: 560,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _warehouseId,
              decoration: InputDecoration(
                labelText: l10n.productUnitFieldWarehouse,
              ),
              items: warehouses
                  .map(
                    (w) => DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        localizedWarehouseName(w, widget.languageCode),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _selectWarehouse,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _prefixController,
                    decoration: InputDecoration(
                      labelText: l10n.productSerialTrackingPrefix,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _startController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.productSerialTrackingStart,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _countController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: l10n.productSerialTrackingCount,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(l10n.productSerialTrackingGenerate),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _serialsController,
                expands: true,
                maxLines: null,
                decoration: InputDecoration(
                  labelText: l10n.productSerialTrackingSerials,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: l10n.productSerialTrackingReason,
              ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.financeActionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.productSerialTrackingConfirm),
        ),
      ],
    );
  }
}
