import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../accounting/domain/journal_source.dart';
import '../../domain/journal_filters.dart';
import '../journal_display_helpers.dart';

class JournalFiltersBar extends StatelessWidget {
  const JournalFiltersBar({
    required this.filters,
    required this.onSourceChanged,
    required this.onSearchChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    super.key,
  });

  final JournalFilters filters;
  final ValueChanged<JournalSource?> onSourceChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width > 768;

    final sourceField = DropdownButtonFormField<JournalSource?>(
      initialValue: filters.source,
      decoration: InputDecoration(labelText: l10n.journalFilterSource),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.productsFilterAll)),
        for (final source in JournalSource.values)
          DropdownMenuItem(
            value: source,
            child: Text(journalSourceLabel(l10n, source)),
          ),
      ],
      onChanged: onSourceChanged,
    );

    final searchField = TextFormField(
      initialValue: filters.search,
      decoration: InputDecoration(
        labelText: l10n.journalFilterSearch,
        prefixIcon: const Icon(Icons.search),
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
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: sourceField),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: searchField),
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
        sourceField,
        const SizedBox(height: 12),
        searchField,
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
