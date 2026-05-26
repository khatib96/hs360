import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../products/domain/product_cost_access.dart';
import '../../products/domain/product_permissions.dart';
import 'inventory_error_messages.dart';
import 'inventory_movements_controller.dart';
import 'widgets/inventory_movements_filters_bar.dart';
import 'widgets/inventory_movements_table.dart';

class InventoryMovementsScreen extends ConsumerWidget {
  const InventoryMovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final languageCode = locale.languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(inventoryMovementsControllerProvider);
    final controller = ref.read(inventoryMovementsControllerProvider.notifier);

    final showUnitCost =
        session != null && canViewFullProductCosts(session);
    final showProductsSearchHint =
        session != null && !canViewProductsList(session);

    final visible = state.visibleRows;

    Widget body;
    if (state.isLoading && state.allRows.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loading),
          ],
        ),
      );
    } else if (state.hasError && state.allRows.isEmpty) {
      body = _InventoryMovementsErrorState(
        message: inventoryMovementsErrorMessage(l10n, state.errorCode!),
        onRetry: controller.refresh,
      );
    } else if (!state.isLoading && state.allRows.isEmpty) {
      body = Center(child: Text(l10n.inventoryMovementsEmpty));
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.productLabelsWarningCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MessageBanner(
                variant: MessageBannerVariant.info,
                message: l10n.inventoryMovementsProductLabelsFailed,
              ),
            ),
          if (state.warehouseLabelsWarningCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MessageBanner(
                variant: MessageBannerVariant.info,
                message: l10n.inventoryMovementsWarehouseLabelsFailed,
              ),
            ),
          InventoryMovementsFiltersBar(
            search: state.search,
            warehouseId: state.warehouseId,
            movementType: state.movementType,
            occurredFromDate: state.occurredFromDate,
            occurredToDate: state.occurredToDate,
            limit: state.limit,
            filterWarehouses: state.filterWarehouses,
            languageCode: languageCode,
            showProductsSearchHint: showProductsSearchHint,
            onSearchCommitted: controller.setSearch,
            onWarehouseChanged: controller.setWarehouseId,
            onMovementTypeChanged: controller.setMovementType,
            onOccurredFromChanged: controller.setOccurredFromDate,
            onOccurredToChanged: controller.setOccurredToDate,
            onLimitChanged: controller.setLimit,
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            Expanded(
              child: Center(child: Text(l10n.inventoryMovementsEmpty)),
            )
          else
            Expanded(
              child: InventoryMovementsTable(
                rows: visible,
                languageCode: languageCode,
                inactiveWarehouseSuffix: l10n.warehouseInactive,
                showUnitCost: showUnitCost,
              ),
            ),
        ],
      );
    }

    return AppShell(
      title: l10n.inventoryMovements,
      currentRoute: AppRoutes.inventoryMovements,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.all(24),
              child: body,
            ),
            if (state.isLoading && state.allRows.isNotEmpty)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _InventoryMovementsErrorState extends StatelessWidget {
  const _InventoryMovementsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
