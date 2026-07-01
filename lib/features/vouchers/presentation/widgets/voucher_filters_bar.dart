import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/voucher_filters.dart';
import '../../domain/voucher_status.dart';
import '../../domain/voucher_type.dart';
import '../voucher_display_helpers.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';

enum _VoucherTypeFilter { all }

class VoucherFiltersBar extends StatelessWidget {
  const VoucherFiltersBar({
    required this.filters,
    required this.availableTypes,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    super.key,
  });

  final VoucherFilters filters;
  final List<VoucherType> availableTypes;
  final ValueChanged<VoucherType?> onTypeChanged;
  final ValueChanged<VoucherStatus?> onStatusChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = InvoiceDesign.isDesktop(context);

    final typeField = availableTypes.length <= 1
        ? const SizedBox.shrink()
        : DropdownButtonFormField<Object>(
            key: ValueKey('voucher-filter-type-${filters.type}'),
            initialValue: filters.type ?? _VoucherTypeFilter.all,
            isDense: true,
            decoration: InvoiceDesign.denseField(
              context,
              label: l10n.voucherFilterType,
            ),
            items: [
              DropdownMenuItem(
                value: _VoucherTypeFilter.all,
                child: Text(l10n.productsFilterAll),
              ),
              for (final type in availableTypes)
                DropdownMenuItem(
                  value: type,
                  child: Text(voucherTypeLabel(l10n, type)),
                ),
            ],
            onChanged: (value) =>
                onTypeChanged(value is VoucherType ? value : null),
          );

    final statusChips = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StatusChip(
          label: Text(l10n.productsFilterAll),
          selected: filters.status == null,
          onSelected: () => onStatusChanged(null),
        ),
        for (final status in voucherStatusFilterOptions)
          _StatusChip(
            label: Text(voucherStatusLabel(l10n, status)),
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
        label: l10n.voucherFilterSearch,
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

  final Widget label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: label,
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
