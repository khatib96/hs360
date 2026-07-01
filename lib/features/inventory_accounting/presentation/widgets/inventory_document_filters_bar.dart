import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../inventory/domain/warehouse.dart';
import '../../domain/inventory_document_filters.dart';
import '../../domain/inventory_document_summary.dart';
import '../inventory_document_display_helpers.dart';

class InventoryDocumentFiltersBar extends StatelessWidget {
  const InventoryDocumentFiltersBar({
    required this.filters,
    required this.warehouses,
    required this.onKindChanged,
    required this.onWarehouseChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    super.key,
  });

  final InventoryDocumentFilters filters;
  final List<Warehouse> warehouses;
  final ValueChanged<InventoryDocumentKind?> onKindChanged;
  final ValueChanged<String?> onWarehouseChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width > 768;

    final kindField = DropdownButtonFormField<InventoryDocumentKind?>(
      initialValue: filters.kind,
      decoration: InputDecoration(labelText: l10n.inventoryDocumentFilterKind),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.productsFilterAll)),
        ...InventoryDocumentKind.values.map(
          (kind) => DropdownMenuItem(
            value: kind,
            child: Text(inventoryDocumentKindLabel(l10n, kind)),
          ),
        ),
      ],
      onChanged: onKindChanged,
    );

    final warehouseField = DropdownButtonFormField<String?>(
      initialValue: filters.warehouseId,
      decoration: InputDecoration(
        labelText: l10n.inventoryDocumentFilterWarehouse,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.productsFilterAll)),
        ...warehouses.map(
          (w) => DropdownMenuItem(value: w.id, child: Text(w.nameEn)),
        ),
      ],
      onChanged: onWarehouseChanged,
    );

    final fromField = _DateField(
      label: l10n.inventoryMovementsFilterDateFrom,
      value: filters.dateRange.from,
      onChanged: onDateFromChanged,
    );
    final toField = _DateField(
      label: l10n.inventoryMovementsFilterDateTo,
      value: filters.dateRange.to,
      onChanged: onDateToChanged,
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: kindField),
          const SizedBox(width: 12),
          Expanded(child: warehouseField),
          const SizedBox(width: 12),
          Expanded(child: fromField),
          const SizedBox(width: 12),
          Expanded(child: toField),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        kindField,
        const SizedBox(height: 12),
        warehouseField,
        const SizedBox(height: 12),
        fromField,
        const SizedBox(height: 12),
        toField,
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? ''
        : MaterialLocalizations.of(context).formatMediumDate(value!);
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              )
            : const Icon(Icons.calendar_today_outlined),
      ),
      controller: TextEditingController(text: text),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
