import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/movement_type.dart';
import '../../domain/warehouse.dart';
import '../inventory_movement_display_helpers.dart';
import '../warehouse_display_helpers.dart';

class InventoryMovementsFiltersBar extends StatefulWidget {
  const InventoryMovementsFiltersBar({
    required this.search,
    required this.warehouseId,
    required this.movementType,
    required this.occurredFromDate,
    required this.occurredToDate,
    required this.limit,
    required this.filterWarehouses,
    required this.languageCode,
    required this.showProductsSearchHint,
    required this.onSearchCommitted,
    required this.onWarehouseChanged,
    required this.onMovementTypeChanged,
    required this.onOccurredFromChanged,
    required this.onOccurredToChanged,
    required this.onLimitChanged,
    super.key,
  });

  final String? search;
  final String? warehouseId;
  final MovementType? movementType;
  final DateTime? occurredFromDate;
  final DateTime? occurredToDate;
  final int limit;
  final List<Warehouse> filterWarehouses;
  final String languageCode;
  final bool showProductsSearchHint;
  final ValueChanged<String?> onSearchCommitted;
  final ValueChanged<String?> onWarehouseChanged;
  final ValueChanged<MovementType?> onMovementTypeChanged;
  final ValueChanged<DateTime?> onOccurredFromChanged;
  final ValueChanged<DateTime?> onOccurredToChanged;
  final ValueChanged<int> onLimitChanged;

  @override
  State<InventoryMovementsFiltersBar> createState() =>
      _InventoryMovementsFiltersBarState();
}

class _InventoryMovementsFiltersBarState extends State<InventoryMovementsFiltersBar> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search ?? '');
  }

  @override
  void didUpdateWidget(InventoryMovementsFiltersBar oldWidget) {
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

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onChanged,
  }) async {
    final now = DateTime.now();
    final initial = current ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (!mounted) return;
    onChanged(picked);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showProductsSearchHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.inventoryMovementsSearchRequiresProducts,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.inventoryMovementsSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: widget.warehouseId,
                decoration: InputDecoration(
                  labelText: l10n.inventoryMovementsFilterWarehouse,
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.inventoryMovementsFilterWarehouseAll),
                  ),
                  for (final warehouse in widget.filterWarehouses)
                    DropdownMenuItem<String?>(
                      value: warehouse.id,
                      child: Text(
                        warehouse.isActive
                            ? localizedWarehouseName(
                                warehouse,
                                widget.languageCode,
                              )
                            : '${localizedWarehouseName(warehouse, widget.languageCode)} '
                                '(${l10n.warehouseInactive})',
                      ),
                    ),
                ],
                onChanged: widget.onWarehouseChanged,
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<MovementType?>(
                initialValue: widget.movementType,
                decoration: InputDecoration(
                  labelText: l10n.inventoryMovementsFilterMovementType,
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<MovementType?>(
                    value: null,
                    child: Text(l10n.inventoryMovementsFilterMovementTypeAll),
                  ),
                  for (final type in MovementType.values)
                    DropdownMenuItem<MovementType?>(
                      value: type,
                      child: Text(movementTypeLabel(type, l10n)),
                    ),
                ],
                onChanged: widget.onMovementTypeChanged,
              ),
            ),
            SizedBox(
              width: 160,
              child: OutlinedButton(
                onPressed: () => _pickDate(
                  current: widget.occurredFromDate,
                  onChanged: widget.onOccurredFromChanged,
                ),
                child: Text(
                  widget.occurredFromDate == null
                      ? l10n.inventoryMovementsFilterDateFrom
                      : _formatDate(widget.occurredFromDate),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: OutlinedButton(
                onPressed: () => _pickDate(
                  current: widget.occurredToDate,
                  onChanged: widget.onOccurredToChanged,
                ),
                child: Text(
                  widget.occurredToDate == null
                      ? l10n.inventoryMovementsFilterDateTo
                      : _formatDate(widget.occurredToDate),
                ),
              ),
            ),
            if (widget.occurredFromDate != null || widget.occurredToDate != null)
              IconButton(
                tooltip: l10n.productsFilterClear,
                onPressed: () {
                  widget.onOccurredFromChanged(null);
                  widget.onOccurredToChanged(null);
                },
                icon: const Icon(Icons.clear),
              ),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<int>(
                initialValue: widget.limit,
                decoration: InputDecoration(
                  labelText: l10n.inventoryMovementsFilterPageSize,
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                  DropdownMenuItem(value: 200, child: Text('200')),
                ],
                onChanged: (value) {
                  if (value != null) widget.onLimitChanged(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
