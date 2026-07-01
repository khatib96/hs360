import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/invoice_filters.dart';
import '../../domain/invoice_status.dart';
import '../../domain/invoice_type.dart';
import '../invoice_display_helpers.dart';
import 'invoice_design.dart';

enum _InvoiceTypeFilter { all }

/// Compact filter bar for the invoice list.
class InvoiceFiltersBar extends StatelessWidget {
  const InvoiceFiltersBar({
    required this.filters,
    required this.availableTypes,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    super.key,
  });

  final InvoiceFilters filters;
  final List<InvoiceType> availableTypes;
  final ValueChanged<InvoiceType?> onTypeChanged;
  final ValueChanged<InvoiceStatus?> onStatusChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = InvoiceDesign.isDesktop(context);
    final type = filters.type;

    final typeField = availableTypes.length <= 1
        ? const SizedBox.shrink()
        : DropdownButtonFormField<Object>(
            key: ValueKey('invoice-filter-type-${filters.type}'),
            initialValue: filters.type ?? _InvoiceTypeFilter.all,
            isDense: true,
            decoration: InvoiceDesign.denseField(
              context,
              label: l10n.invoiceFilterType,
            ),
            items: [
              DropdownMenuItem(
                value: _InvoiceTypeFilter.all,
                child: Text(l10n.productsFilterAll),
              ),
              for (final t in availableTypes)
                DropdownMenuItem(
                  value: t,
                  child: Text(invoiceTypeLabel(l10n, t)),
                ),
            ],
            onChanged: (value) =>
                onTypeChanged(value is InvoiceType ? value : null),
          );

    final statusOptions = type == null
        ? statusFilterOptionsForTypes(availableTypes)
        : statusFilterOptionsForType(type);

    final statusChips = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StatusChip(
          label: l10n.productsFilterAll,
          selected: filters.status == null,
          onSelected: () => onStatusChanged(null),
        ),
        for (final status in statusOptions)
          _StatusChip(
            label: invoiceStatusLabel(l10n, status),
            selected: filters.status == status,
            onSelected: () =>
                onStatusChanged(filters.status == status ? null : status),
          ),
      ],
    );

    final searchField = TextFormField(
      initialValue: filters.search,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InvoiceDesign.denseField(
        context,
        label: l10n.invoiceFilterSearch,
        prefixIcon: const Icon(Icons.search, size: 18),
      ),
      onFieldSubmitted: onSearchChanged,
      onChanged: onSearchChanged,
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (availableTypes.length > 1) ...[
                Expanded(child: typeField),
                const SizedBox(width: 10),
              ],
              Expanded(flex: 2, child: searchField),
              const SizedBox(width: 10),
              Expanded(child: fromField),
              const SizedBox(width: 10),
              Expanded(child: toField),
            ],
          ),
          const SizedBox(height: 10),
          statusChips,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (availableTypes.length > 1) ...[
          typeField,
          const SizedBox(height: 10),
        ],
        searchField,
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: fromField),
            const SizedBox(width: 10),
            Expanded(child: toField),
          ],
        ),
        const SizedBox(height: 10),
        statusChips,
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: Theme.of(context).textTheme.labelMedium,
      onSelected: (_) => onSelected(),
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
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InvoiceDesign.denseField(
        context,
        label: label,
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () => onChanged(null),
              )
            : const Icon(Icons.calendar_today_outlined, size: 16),
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
