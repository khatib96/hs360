import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../domain/contract_filters.dart';
import '../../domain/contract_status.dart';
import '../../domain/contract_type.dart';
import '../contract_display_helpers.dart';

enum _ContractTypeFilter { all }

class ContractFiltersBar extends StatelessWidget {
  const ContractFiltersBar({
    required this.filters,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.onLowProfitOverrideChanged,
    super.key,
  });

  final ContractFilters filters;
  final ValueChanged<ContractType?> onTypeChanged;
  final ValueChanged<ContractStatus?> onStatusChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;
  final ValueChanged<bool> onLowProfitOverrideChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = InvoiceDesign.isDesktop(context);

    final typeField = DropdownButtonFormField<Object>(
      key: ValueKey('contract-filter-type-${filters.type}'),
      initialValue: filters.type ?? _ContractTypeFilter.all,
      isDense: true,
      decoration: InvoiceDesign.denseField(
        context,
        label: l10n.contractFilterType,
      ),
      items: [
        DropdownMenuItem(
          value: _ContractTypeFilter.all,
          child: Text(l10n.productsFilterAll),
        ),
        for (final type in contractTypeFilterOptions)
          DropdownMenuItem(
            value: type,
            child: Text(contractTypeLabel(l10n, type)),
          ),
      ],
      onChanged: (value) => onTypeChanged(value is ContractType ? value : null),
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
        for (final status in contractStatusFilterOptions)
          _StatusChip(
            label: Text(contractStatusLabel(l10n, status)),
            selected: filters.status == status,
            onSelected: () =>
                onStatusChanged(filters.status == status ? null : status),
          ),
      ],
    );

    final searchField = TextField(
      key: const Key('contract-search-field'),
      decoration: InvoiceDesign.denseField(
        context,
        label: l10n.contractFilterSearchHint,
      ),
      onSubmitted: onSearchChanged,
      onChanged: onSearchChanged,
    );

    final dateRow = Row(
      children: [
        Expanded(
          child: _DateField(
            label: l10n.inventoryMovementsFilterDateFrom,
            value: filters.dateRange.from,
            onChanged: onDateFromChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateField(
            label: l10n.inventoryMovementsFilterDateTo,
            value: filters.dateRange.to,
            onChanged: onDateToChanged,
          ),
        ),
      ],
    );

    final overrideToggle = FilterChip(
      label: Text(l10n.contractFilterLowProfitOverride),
      selected: filters.lowProfitOverrideOnly,
      onSelected: onLowProfitOverrideChanged,
    );

    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: searchField),
              const SizedBox(width: 12),
              SizedBox(width: 180, child: typeField),
            ],
          ),
          const SizedBox(height: 12),
          statusChips,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: dateRow),
              const SizedBox(width: 12),
              overrideToggle,
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        searchField,
        const SizedBox(height: 12),
        typeField,
        const SizedBox(height: 12),
        statusChips,
        const SizedBox(height: 12),
        dateRow,
        const SizedBox(height: 12),
        overrideToggle,
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
    final display = value == null ? '—' : formatContractDate(value!);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: InvoiceDesign.denseField(context, label: label),
        child: Text(display),
      ),
    );
  }
}
