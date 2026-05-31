import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(isFiltered ? l10n.customerListEmptyFiltered : l10n.customerListEmpty),
          if (canCreate && !isFiltered) ...[
            const SizedBox(height: 8),
            Text(l10n.customerAdd, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
