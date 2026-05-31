import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/supplier_filters.dart';

/// Supplier list filters: search commits on submit; status commits on change.
class SupplierFiltersBar extends StatefulWidget {
  const SupplierFiltersBar({
    required this.filters,
    required this.onSearchSubmitted,
    required this.onActiveChanged,
    required this.onClear,
    super.key,
  });

  final SupplierFilters filters;
  final ValueChanged<String?> onSearchSubmitted;
  final ValueChanged<bool?> onActiveChanged;
  final VoidCallback onClear;

  @override
  State<SupplierFiltersBar> createState() => _SupplierFiltersBarState();
}

class _SupplierFiltersBarState extends State<SupplierFiltersBar> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.filters.search ?? '');
  }

  @override
  void didUpdateWidget(SupplierFiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.filters.search ?? '';
    if (_search.text != next) _search.text = next;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = widget.filters;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            key: const Key('supplier-search-field'),
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: l10n.supplierSearchHint,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: MaterialLocalizations.of(context)
                          .cancelButtonLabel,
                      onPressed: () {
                        _search.clear();
                        widget.onSearchSubmitted(null);
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: widget.onSearchSubmitted,
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<bool?>(
            isExpanded: true,
            initialValue: filters.isActive,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.supplierFilterStatus,
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.supplierFilterAll)),
              DropdownMenuItem(
                value: true,
                child: Text(l10n.supplierStatusActive),
              ),
              DropdownMenuItem(
                value: false,
                child: Text(l10n.supplierStatusInactive),
              ),
            ],
            onChanged: widget.onActiveChanged,
          ),
        ),
        TextButton.icon(
          onPressed: widget.onClear,
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: Text(l10n.supplierClearFilters),
        ),
      ],
    );
  }
}
