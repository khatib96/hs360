import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';

enum InventoryViewMode { balances, warehouses, movements, transfers }

class InventoryPlaceholderScreen extends ConsumerWidget {
  const InventoryPlaceholderScreen({
    required this.mode,
    super.key,
  });

  final InventoryViewMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canViewMovements =
        session?.isManager == true ||
        (session?.permissions.can('inventory_movements.view') ?? false);
    final canCreateMovements =
        session?.isManager == true ||
        (session?.permissions.can('inventory_movements.create') ?? false);

    final String title;
    final bool showBackButton;
    final Widget bodyContent;

    switch (mode) {
      case InventoryViewMode.balances:
        title = l10n.inventory;
        showBackButton = false;
        bodyContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.inventory,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time inventory levels across all active warehouses.',
              style: theme.textTheme.bodyMedium,
            ),
            if (canCreateMovements || canViewMovements) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (canCreateMovements)
                    ElevatedButton.icon(
                      onPressed: () => context.go(AppRoutes.inventoryTransfers),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l10n.inventoryTransfers),
                    ),
                  if (canViewMovements)
                    OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.inventoryMovements),
                      icon: const Icon(Icons.history),
                      label: Text(l10n.inventoryMovements),
                    ),
                ],
              ),
            ],
          ],
        );
        break;

      case InventoryViewMode.warehouses:
        title = l10n.warehouses;
        showBackButton = false;
        bodyContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.warehouses,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Manage central warehouses and vehicle/van stock repositories.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Main Warehouse: Central Repository (Active)'),
              ),
            ),
          ],
        );
        break;

      case InventoryViewMode.movements:
        title = l10n.inventoryMovements;
        showBackButton = true;
        bodyContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.inventoryMovements,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Immutable log of all operational stock adjustments, inward receipts, and outward movements.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Movements history log is empty (Phase 3 placeholder).'),
              ),
            ),
          ],
        );
        break;

      case InventoryViewMode.transfers:
        title = l10n.inventoryTransfers;
        showBackButton = true;
        bodyContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.inventoryTransfers,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Initiate a secure internal transfer between active stock locations.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Transfer stock wizard placeholder.'),
              ),
            ),
          ],
        );
        break;
    }

    return AppShell(
      title: title,
      currentRoute: switch (mode) {
        InventoryViewMode.balances => AppRoutes.inventory,
        InventoryViewMode.warehouses => AppRoutes.warehouses,
        InventoryViewMode.movements => AppRoutes.inventoryMovements,
        InventoryViewMode.transfers => AppRoutes.inventoryTransfers,
      },
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
                    context.go(_inventoryFallbackRoute(ref));
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

String _inventoryFallbackRoute(WidgetRef ref) {
  final session = ref.read(authControllerProvider).valueOrNull;
  if (session == null) return AppRoutes.login;
  if (session.isManager || session.permissions.can('inventory.view')) {
    return AppRoutes.inventory;
  }
  return resolveHomeRoute(session);
}
