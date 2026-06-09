import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/decimal_parser.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../products/data/product_repository.dart';
import '../../../../domain/services/cost_engine.dart';
import '../../../../domain/services/stock_engine.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../products/domain/product.dart';
import '../../../products/domain/product_cost_access.dart';
import '../../../products/domain/product_permissions.dart';
import '../../domain/movement_type.dart';
import '../inventory_adjustment_controller.dart';
import '../inventory_adjustment_display_helpers.dart';
import '../inventory_error_messages.dart';
import '../inventory_movement_display_helpers.dart';
import '../warehouse_display_helpers.dart';
import 'inventory_adjustment_product_picker.dart';

Future<bool?> showInventoryAdjustmentDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String languageCode,
  String? prefillWarehouseId,
  String? prefillProductId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => InventoryAdjustmentDialog(
      languageCode: languageCode,
      prefillWarehouseId: prefillWarehouseId,
      prefillProductId: prefillProductId,
    ),
  );
}

class InventoryAdjustmentDialog extends ConsumerStatefulWidget {
  const InventoryAdjustmentDialog({
    required this.languageCode,
    this.prefillWarehouseId,
    this.prefillProductId,
    super.key,
  });

  final String languageCode;
  final String? prefillWarehouseId;
  final String? prefillProductId;

  @override
  ConsumerState<InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends ConsumerState<InventoryAdjustmentDialog> {
  final _qtyController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _notesController = TextEditingController();

  MovementType _movementType = MovementType.adjustmentOut;
  String? _warehouseId;
  Product? _selectedProduct;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _warehouseId = widget.prefillWarehouseId;
    _qtyController.addListener(() => setState(() {}));
    _unitCostController.addListener(() => setState(() {}));
    Future.microtask(() async {
      await ref
          .read(inventoryAdjustmentControllerProvider.notifier)
          .loadWarehouses();
      if (!mounted) return;
      if (widget.prefillProductId != null) {
        final session = ref.read(authControllerProvider).valueOrNull;
        if (session != null && canViewProductsList(session)) {
          final product = await ref
              .read(productRepositoryProvider)
              .fetchProductById(widget.prefillProductId!, session);
          if (product != null && mounted) {
            setState(() => _selectedProduct = product);
            await ref
                .read(inventoryAdjustmentControllerProvider.notifier)
                .selectProduct(product);
            if (_warehouseId != null) {
              await ref
                  .read(inventoryAdjustmentControllerProvider.notifier)
                  .onWarehouseChanged(_warehouseId);
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _unitCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canWriteCosts {
    final session = ref.read(authControllerProvider).valueOrNull;
    return session != null && canWriteProductCosts(session);
  }

  bool get _canViewCosts {
    final session = ref.read(authControllerProvider).valueOrNull;
    return session != null && canViewFullProductCosts(session);
  }

  bool get _canViewProducts {
    final session = ref.read(authControllerProvider).valueOrNull;
    return session != null && canViewProductsList(session);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _inlineError = null);

    if (_warehouseId == null || _warehouseId!.isEmpty) {
      setState(() => _inlineError = l10n.inventoryAdjustmentWarehouseRequired);
      return;
    }
    if (_selectedProduct == null) {
      setState(() => _inlineError = l10n.inventoryAdjustmentProductRequired);
      return;
    }

    final qty = tryParseDecimal(_qtyController.text.trim());
    if (qty == null || qty <= Decimal.zero) {
      setState(() => _inlineError = l10n.productValidationFailed);
      return;
    }

    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      setState(() => _inlineError = l10n.productValidationFailed);
      return;
    }

    Decimal? unitCost;
    if (_movementType == MovementType.adjustmentIn) {
      if (!_canWriteCosts) {
        setState(
          () => _inlineError = l10n.inventoryAdjustmentStockInRequiresCost,
        );
        return;
      }
      unitCost = tryParseDecimal(_unitCostController.text.trim());
      if (unitCost == null || unitCost < Decimal.zero) {
        setState(() => _inlineError = l10n.productValidationFailed);
        return;
      }
    }

    final adjState = ref.read(inventoryAdjustmentControllerProvider);
    if (adjState.isSerialized) {
      setState(
        () =>
            _inlineError = l10n.inventoryErrorSerializedAdjustmentNotSupported,
      );
      return;
    }

    final errorCode = await ref
        .read(inventoryAdjustmentControllerProvider.notifier)
        .submit(
          movementType: _movementType,
          warehouseId: _warehouseId!,
          productId: _selectedProduct!.id,
          qty: qty,
          notes: notes,
          unitCost: unitCost,
        );

    if (!mounted) return;
    if (errorCode == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(
      () => _inlineError = inventoryAdjustmentErrorMessage(l10n, errorCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adjState = ref.watch(inventoryAdjustmentControllerProvider);
    final stockEngine = const StockEngine();
    final costEngine = const CostEngine();

    final qty = tryParseDecimal(_qtyController.text.trim());
    String? deltaPreview;
    if (qty != null && qty > Decimal.zero) {
      final delta = stockEngine.previewAdjustmentDelta(_movementType, qty);
      deltaPreview = formatSignedQuantityDelta(delta);
    }

    String? wacPreview;
    if (_movementType == MovementType.adjustmentIn &&
        _canViewCosts &&
        qty != null &&
        qty > Decimal.zero) {
      final unitCost = tryParseDecimal(_unitCostController.text.trim());
      final oldTotal = adjState.totalQtyAvailable ?? Decimal.zero;
      final oldAvg = adjState.avgCost ?? Decimal.zero;
      if (unitCost != null && unitCost >= Decimal.zero) {
        wacPreview = formatQuantity(
          costEngine.previewWac(
            oldTotalQty: oldTotal,
            oldAvgCost: oldAvg,
            incomingQty: qty,
            incomingUnitCost: unitCost,
          ),
        );
      }
    }

    final movementTypes = _canWriteCosts
        ? [MovementType.adjustmentIn, MovementType.adjustmentOut]
        : [MovementType.adjustmentOut];

    if (!movementTypes.contains(_movementType)) {
      _movementType = MovementType.adjustmentOut;
    }

    return AlertDialog(
      title: Text(l10n.inventoryAdjustmentTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_canWriteCosts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.inventoryAdjustmentStockInRequiresCost,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Text(l10n.inventoryAdjustmentMovementType),
              const SizedBox(height: 4),
              if (movementTypes.length > 1)
                SegmentedButton<MovementType>(
                  segments: movementTypes
                      .map(
                        (t) => ButtonSegment(
                          value: t,
                          label: Text(movementTypeLabel(t, l10n)),
                        ),
                      )
                      .toList(),
                  selected: {_movementType},
                  onSelectionChanged: (selected) {
                    setState(() => _movementType = selected.first);
                  },
                )
              else
                Text(movementTypeLabel(_movementType, l10n)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _warehouseId,
                decoration: InputDecoration(
                  labelText: l10n.inventoryBalancesFilterWarehouse,
                ),
                items: adjState.warehouses
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          localizedWarehouseName(w, widget.languageCode),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  setState(() => _warehouseId = v);
                  await ref
                      .read(inventoryAdjustmentControllerProvider.notifier)
                      .onWarehouseChanged(v);
                },
              ),
              const SizedBox(height: 12),
              InventoryAdjustmentProductPicker(
                languageCode: widget.languageCode,
                canViewProducts: _canViewProducts,
                selectedProduct: _selectedProduct,
                onProductCleared: () {
                  setState(() => _selectedProduct = null);
                  ref
                      .read(inventoryAdjustmentControllerProvider.notifier)
                      .clearProductSelection();
                },
                onProductSelected: (product) async {
                  setState(() => _selectedProduct = product);
                  await ref
                      .read(inventoryAdjustmentControllerProvider.notifier)
                      .selectProduct(product);
                  if (_warehouseId != null) {
                    await ref
                        .read(inventoryAdjustmentControllerProvider.notifier)
                        .onWarehouseChanged(_warehouseId);
                  }
                },
              ),
              if (adjState.isSerialized) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.inventoryErrorSerializedAdjustmentNotSupported,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              AppTextField(
                label: l10n.inventoryAdjustmentQuantity,
                controller: _qtyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              if (_movementType == MovementType.adjustmentIn &&
                  _canWriteCosts) ...[
                const SizedBox(height: 8),
                AppTextField(
                  label: l10n.inventoryAdjustmentUnitCost,
                  controller: _unitCostController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: l10n.inventoryAdjustmentNotes,
                ),
                maxLines: 3,
              ),
              if (deltaPreview != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${l10n.inventoryAdjustmentPreviewDelta}: $deltaPreview',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (wacPreview != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.inventoryAdjustmentPreviewWac}: $wacPreview',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_inlineError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _inlineError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: adjState.isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: adjState.isSubmitting || adjState.isSerialized
              ? null
              : _submit,
          child: adjState.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
