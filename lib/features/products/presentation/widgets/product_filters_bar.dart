import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/product_filters.dart';
import '../../domain/product_group.dart';
import '../../domain/product_type.dart';
import '../product_display_helpers.dart';

class ProductFiltersBar extends StatefulWidget {
  const ProductFiltersBar({
    required this.filters,
    required this.canViewStock,
    required this.canViewGroups,
    required this.groups,
    required this.languageCode,
    required this.onSearchCommitted,
    required this.onTypeChanged,
    required this.onActiveChanged,
    required this.onStockFilterChanged,
    required this.onClearFilters,
    super.key,
  });

  final ProductFilters filters;
  final bool canViewStock;
  final bool canViewGroups;
  final List<ProductGroup> groups;
  final String languageCode;
  final ValueChanged<String?> onSearchCommitted;
  final ValueChanged<ProductType?> onTypeChanged;
  final ValueChanged<bool?> onActiveChanged;
  final ValueChanged<ProductStockFilter?> onStockFilterChanged;
  final VoidCallback onClearFilters;

  @override
  State<ProductFiltersBar> createState() => _ProductFiltersBarState();
}

class _ProductFiltersBarState extends State<ProductFiltersBar> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.search ?? '');
  }

  @override
  void didUpdateWidget(ProductFiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSearch = widget.filters.search ?? '';
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
              hintText: l10n.productsSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        _TypeFilter(
          value: widget.filters.productType,
          onChanged: widget.onTypeChanged,
        ),
        _ActiveFilter(
          value: widget.filters.isActive,
          onChanged: widget.onActiveChanged,
        ),
        if (widget.canViewStock)
          _StockFilter(
            value: widget.filters.stockFilter,
            onChanged: widget.onStockFilterChanged,
          ),
        TextButton.icon(
          onPressed: widget.onClearFilters,
          icon: const Icon(Icons.filter_alt_off, size: 18),
          label: Text(l10n.productsFilterClear),
        ),
      ],
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.value, required this.onChanged});

  final ProductType? value;
  final ValueChanged<ProductType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DropdownButton<ProductType?>(
      value: value,
      hint: Text(l10n.productsFilterType),
      isDense: true,
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.productsFilterAll)),
        DropdownMenuItem(
          value: ProductType.saleOnly,
          child: Text(l10n.productTypeSaleOnly),
        ),
        DropdownMenuItem(
          value: ProductType.assetRental,
          child: Text(l10n.productTypeAssetRental),
        ),
        DropdownMenuItem(
          value: ProductType.consumableRental,
          child: Text(l10n.productTypeConsumableRental),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ActiveFilter extends StatelessWidget {
  const _ActiveFilter({required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DropdownButton<bool?>(
      value: value,
      hint: Text(l10n.productsFilterActive),
      isDense: true,
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.productsFilterAll)),
        DropdownMenuItem(
          value: true,
          child: Text(l10n.productsFilterActiveOnly),
        ),
        DropdownMenuItem(
          value: false,
          child: Text(l10n.productsFilterInactiveOnly),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _StockFilter extends StatelessWidget {
  const _StockFilter({required this.value, required this.onChanged});

  final ProductStockFilter? value;
  final ValueChanged<ProductStockFilter?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DropdownButton<ProductStockFilter?>(
      value: value,
      hint: Text(l10n.productsFilterStock),
      isDense: true,
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.productsFilterAll)),
        DropdownMenuItem(
          value: ProductStockFilter.inStock,
          child: Text(l10n.productStockIn),
        ),
        DropdownMenuItem(
          value: ProductStockFilter.outOfStock,
          child: Text(l10n.productStockOut),
        ),
        DropdownMenuItem(
          value: ProductStockFilter.lowStock,
          child: Text(l10n.productStockLow),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Group filter dropdown for narrow layout when tree panel is collapsed.
class ProductGroupFilterDropdown extends StatelessWidget {
  const ProductGroupFilterDropdown({
    required this.groups,
    required this.selectedGroupId,
    required this.languageCode,
    required this.onChanged,
    super.key,
  });

  final List<ProductGroup> groups;
  final String? selectedGroupId;
  final String languageCode;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DropdownButton<String?>(
      value: selectedGroupId,
      hint: Text(l10n.productsAllGroups),
      isDense: true,
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.productsAllGroups)),
        ...groups.map(
          (g) => DropdownMenuItem(
            value: g.id,
            child: Text(localizedGroupName(g, languageCode)),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
