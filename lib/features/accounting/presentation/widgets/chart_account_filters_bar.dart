import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/account_type.dart';
import '../../domain/chart_account_filters.dart';
import '../chart_account_display_helpers.dart';

class ChartAccountFiltersBar extends StatefulWidget {
  const ChartAccountFiltersBar({
    required this.filters,
    required this.onSearchSubmitted,
    required this.onTypeChanged,
    required this.onActiveChanged,
    required this.onClear,
    super.key,
  });

  final ChartAccountFilters filters;
  final ValueChanged<String?> onSearchSubmitted;
  final ValueChanged<AccountType?> onTypeChanged;
  final ValueChanged<bool?> onActiveChanged;
  final VoidCallback onClear;

  @override
  State<ChartAccountFiltersBar> createState() => _ChartAccountFiltersBarState();
}

class _ChartAccountFiltersBarState extends State<ChartAccountFiltersBar> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.filters.search ?? '');
  }

  @override
  void didUpdateWidget(ChartAccountFiltersBar oldWidget) {
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
            key: const Key('chart-account-search-field'),
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: l10n.chartAccountSearchHint,
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
          width: 180,
          child: DropdownButtonFormField<AccountType?>(
            isExpanded: true,
            initialValue: filters.type,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.chartAccountFilterType,
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(l10n.chartAccountFilterAllTypes),
              ),
              ...AccountType.values.map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(localizedAccountType(l10n, type)),
                ),
              ),
            ],
            onChanged: widget.onTypeChanged,
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<bool?>(
            isExpanded: true,
            initialValue: filters.isActive,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.chartAccountFilterStatus,
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.chartAccountFilterAll)),
              DropdownMenuItem(
                value: true,
                child: Text(l10n.chartAccountStatusActive),
              ),
              DropdownMenuItem(
                value: false,
                child: Text(l10n.chartAccountStatusInactive),
              ),
            ],
            onChanged: widget.onActiveChanged,
          ),
        ),
        TextButton.icon(
          onPressed: widget.onClear,
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: Text(l10n.chartAccountClearFilters),
        ),
      ],
    );
  }
}
