import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../products/domain/product.dart';
import '../../../products/presentation/product_display_helpers.dart';
import '../inventory_adjustment_controller.dart';

class InventoryAdjustmentProductPicker extends ConsumerStatefulWidget {
  const InventoryAdjustmentProductPicker({
    required this.languageCode,
    required this.canViewProducts,
    required this.selectedProduct,
    required this.onProductSelected,
    required this.onProductCleared,
    super.key,
  });

  final String languageCode;
  final bool canViewProducts;
  final Product? selectedProduct;
  final Future<void> Function(Product product) onProductSelected;
  final VoidCallback onProductCleared;

  @override
  ConsumerState<InventoryAdjustmentProductPicker> createState() =>
      _InventoryAdjustmentProductPickerState();
}

class _InventoryAdjustmentProductPickerState
    extends ConsumerState<InventoryAdjustmentProductPicker> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void didUpdateWidget(InventoryAdjustmentProductPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedProduct;
    if (oldWidget.selectedProduct != null &&
        selected == null &&
        _searchController.text.isNotEmpty) {
      _searchController.clear();
      return;
    }

    if (selected != null && selected.id != oldWidget.selectedProduct?.id) {
      _searchController.text = localizedProductName(
        selected,
        widget.languageCode,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref
          .read(inventoryAdjustmentControllerProvider.notifier)
          .searchProducts(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(inventoryAdjustmentControllerProvider);
    final selectedProduct = widget.selectedProduct;

    if (!widget.canViewProducts) {
      return Text(
        l10n.inventoryAdjustmentProductsViewRequired,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: l10n.inventoryAdjustmentSelectProduct,
          ),
          onChanged: _onSearchChanged,
        ),
        if (state.isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (selectedProduct != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              localizedProductName(selectedProduct, widget.languageCode),
            ),
            subtitle: Text(selectedProduct.sku),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onProductCleared,
            ),
          ),
        if (selectedProduct == null && state.searchResults.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.searchResults.length,
              itemBuilder: (context, index) {
                final product = state.searchResults[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    localizedProductName(product, widget.languageCode),
                  ),
                  subtitle: Text(product.sku),
                  onTap: () async {
                    _searchController.text = localizedProductName(
                      product,
                      widget.languageCode,
                    );
                    await widget.onProductSelected(product);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
