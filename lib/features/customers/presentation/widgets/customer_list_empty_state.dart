import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_state_view.dart';

/// Empty state for the customer list, with an optional create hint.
class CustomerListEmptyState extends StatelessWidget {
  const CustomerListEmptyState({
    required this.isFiltered,
    required this.canCreate,
    super.key,
  });

  final bool isFiltered;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppStateView.empty(
      icon: isFiltered ? Icons.filter_alt_off_outlined : Icons.people_outline,
      message: isFiltered
          ? l10n.customerListEmptyFiltered
          : l10n.customerListEmpty,
      action: canCreate && !isFiltered
          ? Text(l10n.customerAdd, style: Theme.of(context).textTheme.bodySmall)
          : null,
    );
  }
}
