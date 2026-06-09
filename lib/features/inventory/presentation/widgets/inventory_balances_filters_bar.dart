import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/warehouse.dart';
import '../warehouse_display_helpers.dart';

class InventoryBalancesFiltersBar extends StatefulWidget {
  const InventoryBalancesFiltersBar({
    required this.search,
    required this.warehouseId,
    required this.lowStockOnly,
    required this.activeWarehouses,
    required this.languageCode,
    required this.onSearchCommitted,
    required this.onWarehouseChanged,
    required this.onLowStockChanged,
    super.key,
  });

  final String? search;
  final String? warehouseId;
  final bool lowStockOnly;
  final List<Warehouse> activeWarehouses;
  final String languageCode;
  final ValueChanged<String?> onSearchCommitted;
  final ValueChanged<String?> onWarehouseChanged;
  final ValueChanged<bool> onLowStockChanged;

  @override
  State<InventoryBalancesFiltersBar> createState() =>
      _InventoryBalancesFiltersBarState();
}

class _InventoryBalancesFiltersBarState
    extends State<InventoryBalancesFiltersBar> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search ?? '');
  }

  @override
  void didUpdateWidget(InventoryBalancesFiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSearch = widget.search ?? '';
    if (_searchController.text != newSearch) {
      _searchController.text = newSearch;
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
      final trimmed = value.trim();
      widget.onSearchCommitted(trimmed.isEmpty ? null : trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.inventoryBalancesSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: widget.warehouseId,
            decoration: InputDecoration(
              labelText: l10n.inventoryBalancesFilterWarehouse,
              isDense: true,
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  l10n.inventoryBalancesFilterWarehouseAll,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final warehouse in widget.activeWarehouses)
                DropdownMenuItem<String?>(
                  value: warehouse.id,
                  child: Text(
                    localizedWarehouseName(warehouse, widget.languageCode),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.onWarehouseChanged,
          ),
        ),
        FilterChip(
          label: Text(l10n.inventoryBalancesFilterLowStock),
          selected: widget.lowStockOnly,
          onSelected: widget.onLowStockChanged,
        ),
      ],
    );
  }
}
