import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

class ProductListEmptyState extends StatelessWidget {
  const ProductListEmptyState({
    required this.canCreateProduct,
    this.onClearFilters,
    super.key,
  });

  final bool canCreateProduct;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.productsListEmpty,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (canCreateProduct) ...[
              const SizedBox(height: 8),
              Text(l10n.productsNew, style: theme.textTheme.bodySmall),
            ],
            if (onClearFilters != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: Text(l10n.productsFilterClear),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
