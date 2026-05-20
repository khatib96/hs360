import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';

class ProductListEmptyState extends StatelessWidget {
  const ProductListEmptyState({
    required this.canCreateProduct,
    super.key,
  });

  final bool canCreateProduct;

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
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.productsNew),
                icon: const Icon(Icons.add),
                label: Text(l10n.productsNew),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
