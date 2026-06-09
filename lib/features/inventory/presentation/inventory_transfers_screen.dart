import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/decimal_parser.dart';
import '../../../core/utils/quantity_formatter.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../domain/transfer_product_option.dart';
import '../domain/transfer_warehouse_option.dart';
import 'inventory_error_messages.dart';
import 'inventory_transfer_controller.dart';
import 'inventory_transfer_display_helpers.dart';

class InventoryTransfersScreen extends ConsumerStatefulWidget {
  const InventoryTransfersScreen({super.key});

  @override
  ConsumerState<InventoryTransfersScreen> createState() =>
      _InventoryTransfersScreenState();
}

class _InventoryTransfersScreenState
    extends ConsumerState<InventoryTransfersScreen> {
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  final _productSearchController = TextEditingController();
  Timer? _searchDebounce;

  String? _fromWarehouseId;
  String? _toWarehouseId;
  TransferProductOption? _selectedProduct;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _qtyController.addListener(() => setState(() {}));
    _productSearchController.addListener(_onProductSearchControllerChanged);
    Future.microtask(
      () => ref
          .read(inventoryTransferControllerProvider.notifier)
          .loadWarehouses(),
    );
  }

  void _onProductSearchControllerChanged() {
    _onSearchChanged(_productSearchController.text);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _productSearchController.removeListener(_onProductSearchControllerChanged);
    _qtyController.dispose();
    _notesController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref
          .read(inventoryTransferControllerProvider.notifier)
          .searchProducts(value);
    });
  }

  void _setProductSearchText(String value) {
    _searchDebounce?.cancel();
    _productSearchController.removeListener(_onProductSearchControllerChanged);
    _productSearchController.text = value;
    _productSearchController.addListener(_onProductSearchControllerChanged);
  }

  Future<void> _onFromWarehouseChanged(String? id) async {
    setState(() => _fromWarehouseId = id);
    await ref
        .read(inventoryTransferControllerProvider.notifier)
        .hydrateSourceQty(id);
  }

  Future<void> _selectProduct(TransferProductOption product) async {
    if (product.isSerialized) {
      final l10n = AppLocalizations.of(context)!;
      ref
          .read(inventoryTransferControllerProvider.notifier)
          .clearProductSelection();
      setState(() {
        _selectedProduct = null;
        _inlineError = l10n.inventoryErrorSerializedTransferNotSupported;
      });
      _setProductSearchText('');
      return;
    }

    setState(() {
      _selectedProduct = product;
      _productSearchController.text =
          '${product.sku} — ${localizedTransferProductName(product, ref.read(localeProvider).languageCode)}';
      _inlineError = null;
    });
    _setProductSearchText(
      '${product.sku} - ${localizedTransferProductName(product, ref.read(localeProvider).languageCode)}',
    );
    await ref
        .read(inventoryTransferControllerProvider.notifier)
        .selectProduct(product);
    await _onFromWarehouseChanged(_fromWarehouseId);
  }

  void _clearProductFields() {
    setState(() {
      _selectedProduct = null;
      _qtyController.clear();
      _notesController.clear();
      _inlineError = null;
    });
    _setProductSearchText('');
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _inlineError = null);

    if (_fromWarehouseId == null || _fromWarehouseId!.isEmpty) {
      setState(() => _inlineError = l10n.inventorySourceWarehouseRequired);
      return;
    }
    if (_toWarehouseId == null || _toWarehouseId!.isEmpty) {
      setState(() => _inlineError = l10n.inventoryDestinationWarehouseRequired);
      return;
    }
    if (_fromWarehouseId == _toWarehouseId) {
      setState(() => _inlineError = l10n.inventoryTransferSameWarehouse);
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

    final errorCode = await ref
        .read(inventoryTransferControllerProvider.notifier)
        .submit(
          fromWarehouseId: _fromWarehouseId!,
          toWarehouseId: _toWarehouseId!,
          productId: _selectedProduct!.id,
          qty: qty,
          notes: notes,
        );

    if (!mounted) return;
    if (errorCode == null) {
      _clearProductFields();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.inventoryTransferSuccess)));
      return;
    }
    setState(
      () => _inlineError = inventoryTransferErrorMessage(l10n, errorCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final state = ref.watch(inventoryTransferControllerProvider);
    final qty = tryParseDecimal(_qtyController.text.trim());

    return AppShell(
      title: l10n.inventoryTransferTitle,
      currentRoute: AppRoutes.inventoryTransfers,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_inlineError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _inlineError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  _warehouseDropdown(
                    label: l10n.inventoryTransferSourceWarehouse,
                    value: _fromWarehouseId,
                    warehouses: state.warehouses,
                    languageCode: languageCode,
                    onChanged: _onFromWarehouseChanged,
                  ),
                  const SizedBox(height: 12),
                  _warehouseDropdown(
                    label: l10n.inventoryTransferDestinationWarehouse,
                    value: _toWarehouseId,
                    warehouses: state.warehouses,
                    languageCode: languageCode,
                    onChanged: (id) => setState(() => _toWarehouseId = id),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _productSearchController,
                    label: l10n.inventoryTransferSelectProduct,
                  ),
                  if (state.isSearching)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (state.searchResults.isNotEmpty)
                    ...state.searchResults.map(
                      (p) => ListTile(
                        dense: true,
                        title: Text(
                          '${p.sku} — ${localizedTransferProductName(p, languageCode)}',
                        ),
                        subtitle: p.isSerialized
                            ? Text(
                                l10n.inventoryErrorSerializedTransferNotSupported,
                              )
                            : null,
                        onTap: () => _selectProduct(p),
                      ),
                    ),
                  if (state.sourceQtyAvailable != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${l10n.inventoryAdjustmentPreviewDelta}: ${formatQuantity(state.sourceQtyAvailable!)}',
                      ),
                    ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _qtyController,
                    label: l10n.inventoryTransferQuantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  if (qty != null && qty > Decimal.zero) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.inventoryTransferPreviewSource}: ${formatTransferSourceDelta(qty)}',
                    ),
                    Text(
                      '${l10n.inventoryTransferPreviewDestination}: ${formatTransferDestinationDelta(qty)}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    l10n.inventoryTransferNotes,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => context.go(AppRoutes.inventory),
                        child: Text(l10n.productWizardBack),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: state.isSubmitting ? null : _submit,
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.inventoryTransferTitle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _warehouseDropdown({
    required String label,
    required String? value,
    required List<TransferWarehouseOption> warehouses,
    required String languageCode,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      initialValue: value,
      items: warehouses
          .map(
            (w) => DropdownMenuItem(
              value: w.id,
              child: Text(localizedTransferWarehouseName(w, languageCode)),
            ),
          )
          .toList(),
      onChanged: warehouses.isEmpty ? null : onChanged,
    );
  }
}
