import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';

enum ProductsViewMode { list, create, detail }

class ProductsPlaceholderScreen extends ConsumerWidget {
  const ProductsPlaceholderScreen({
    required this.mode,
    this.productId,
    super.key,
  });

  final ProductsViewMode mode;
  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canCreateProduct =
        session?.isManager == true ||
        (session?.permissions.can('products.create') ?? false);

    final String title;
    final bool showBackButton;
    final Widget bodyContent;

    switch (mode) {
      case ProductsViewMode.list:
        title = l10n.products;
        showBackButton = false;
        bodyContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.products,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your premium fragrance and assets catalog.',
              style: theme.textTheme.bodyMedium,
            ),
            if (canCreateProduct) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.productsNew),
                icon: const Icon(Icons.add),
                label: Text(l10n.productsNew),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Sample Product 1 (Double Rose Oud)'),
                subtitle: const Text('SKU: HS-ROSE-001'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/products/HS-ROSE-001'),
              ),
            ),
          ],
        );
        break;

      case ProductsViewMode.create:
        title = l10n.productsNew;
        showBackButton = true;
        bodyContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.productsNew,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a new premium product or rental asset.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Add product wizard placeholder...'),
              ),
            ),
          ],
        );
        break;

      case ProductsViewMode.detail:
        title = l10n.productsDetail;
        showBackButton = true;
        bodyContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.productsDetail}: $productId',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Detailed view, serialized units, and stock summary placeholder.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Product SKU/ID: $productId'),
              ),
            ),
          ],
        );
        break;
    }

    return AppShell(
      title: title,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBackButton) ...[
              BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(_productsFallbackRoute(ref));
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            bodyContent,
          ],
        ),
      ),
    );
  }
}

String _productsFallbackRoute(WidgetRef ref) {
  final session = ref.read(authControllerProvider).valueOrNull;
  if (session == null) return AppRoutes.login;
  if (session.isManager || session.permissions.can('products.view')) {
    return AppRoutes.products;
  }
  return resolveHomeRoute(session);
}
