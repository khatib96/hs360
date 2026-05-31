import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/customer_filters.dart';
import '../../domain/customer_type.dart';

/// Customer list filters. Search/area/city commit on submit (no debounce);
/// dropdowns commit on change.
class CustomerFiltersBar extends StatefulWidget {
  const CustomerFiltersBar({
    required this.filters,
    required this.onSearchSubmitted,
    required this.onActiveChanged,
    required this.onVipChanged,
    required this.onTypeChanged,
    required this.onAreaSubmitted,
    required this.onCitySubmitted,
    required this.onClear,
    super.key,
  });

  final CustomerFilters filters;
  final ValueChanged<String?> onSearchSubmitted;
  final ValueChanged<bool?> onActiveChanged;
  final ValueChanged<bool?> onVipChanged;
  final ValueChanged<CustomerType?> onTypeChanged;
  final ValueChanged<String?> onAreaSubmitted;
  final ValueChanged<String?> onCitySubmitted;
  final VoidCallback onClear;

  @override
  State<CustomerFiltersBar> createState() => _CustomerFiltersBarState();
}

class _CustomerFiltersBarState extends State<CustomerFiltersBar> {
  late final TextEditingController _search;
  late final TextEditingController _area;
  late final TextEditingController _city;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.filters.search ?? '');
    _area = TextEditingController(text: widget.filters.area ?? '');
    _city = TextEditingController(text: widget.filters.city ?? '');
  }

  @override
  void didUpdateWidget(CustomerFiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_search, widget.filters.search);
    _syncController(_area, widget.filters.area);
    _syncController(_city, widget.filters.city);
  }

  void _syncController(TextEditingController controller, String? value) {
    final next = value ?? '';
    if (controller.text != next) controller.text = next;
  }

  @override
  void dispose() {
    _search.dispose();
    _area.dispose();
    _city.dispose();
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
            key: const Key('customer-search-field'),
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: l10n.customerSearchHint,
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
              labelText: l10n.customerFilterStatus,
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.customerFilterAll)),
              DropdownMenuItem(
                value: true,
                child: Text(l10n.customerStatusActive),
              ),
              DropdownMenuItem(
                value: false,
                child: Text(l10n.customerStatusInactive),
              ),
            ],
            onChanged: widget.onActiveChanged,
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<bool?>(
            isExpanded: true,
            initialValue: filters.isVip,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.customerFilterVip,
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.customerFilterAll)),
              DropdownMenuItem(value: true, child: Text(l10n.customerVip)),
              DropdownMenuItem(
                value: false,
                child: Text(l10n.customerNonVip),
              ),
            ],
            onChanged: widget.onVipChanged,
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<CustomerType?>(
            isExpanded: true,
            initialValue: filters.customerType,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.customerTypeLabel,
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.customerFilterAll)),
              DropdownMenuItem(
                value: CustomerType.individual,
                child: Text(l10n.customerTypeIndividual),
              ),
              DropdownMenuItem(
                value: CustomerType.company,
                child: Text(l10n.customerTypeCompany),
              ),
            ],
            onChanged: widget.onTypeChanged,
          ),
        ),
        SizedBox(
          width: 150,
          child: TextField(
            controller: _area,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.customerFieldArea,
            ),
            onSubmitted: widget.onAreaSubmitted,
          ),
        ),
        SizedBox(
          width: 150,
          child: TextField(
            controller: _city,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.customerFieldCity,
            ),
            onSubmitted: widget.onCitySubmitted,
          ),
        ),
        TextButton.icon(
          onPressed: widget.onClear,
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: Text(l10n.customerClearFilters),
        ),
      ],
    );
  }
}
