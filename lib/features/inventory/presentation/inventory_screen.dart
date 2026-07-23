import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/quantity_formatter.dart';
import '../../../shared/widgets/app_filter_bar.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_state_view.dart';
import '../../../shared/widgets/app_table_frame.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/inventory_balance_row.dart';
import '../../inventory_accounting/domain/inventory_document_permissions.dart';
import '../domain/inventory_permissions.dart';
import 'inventory_balances_controller.dart';
import 'inventory_error_messages.dart';
import 'widgets/inventory_adjustment_dialog.dart';
import 'widgets/inventory_balance_table.dart';
import 'widgets/inventory_balances_filters_bar.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({this.initialWarehouseId, super.key});

  final String? initialWarehouseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final languageCode = locale.languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(inventoryBalancesControllerProvider);
    final controller = ref.read(inventoryBalancesControllerProvider.notifier);

    final canViewMovements =
        session != null && canViewInventoryMovements(session);
    final canCreateMovements =
        session != null && canCreateInventoryMovements(session);
    final canViewFinancialDocuments =
        session != null && canViewInventoryDocuments(session);

    final filtered = state.filteredRows;
    final initialFilter = initialWarehouseId;
    if (initialFilter != null &&
        initialFilter.isNotEmpty &&
        state.warehouseId != initialFilter) {
      Future.microtask(() => controller.setWarehouseId(initialFilter));
    }

    Widget body;
    if (state.isLoading && state.allRows.isEmpty) {
      body = AppStateView.loading(message: l10n.loading);
    } else if (state.hasError && state.allRows.isEmpty) {
      body = AppStateView.error(
        message: inventoryErrorMessage(l10n, state.errorCode!),
        action: FilledButton(
          onPressed: controller.refresh,
          child: Text(l10n.retry),
        ),
      );
    } else if (!state.isLoading && state.allRows.isEmpty) {
      body = AppStateView.empty(
        icon: Icons.inventory_2_outlined,
        message: l10n.inventoryBalancesEmpty,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.productLabelsWarningCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MessageBanner(
                variant: MessageBannerVariant.info,
                message: l10n.inventoryBalancesProductLabelsFailed,
              ),
            ),
          if (state.warehouseLabelsWarningCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MessageBanner(
                variant: MessageBannerVariant.info,
                message: l10n.inventoryBalancesWarehouseLabelsFailed,
              ),
            ),
          AppFilterBar(
            compact: true,
            child: InventoryBalancesFiltersBar(
              search: state.search,
              warehouseId: state.warehouseId,
              lowStockOnly: state.lowStockOnly,
              activeWarehouses: state.activeWarehouses,
              languageCode: languageCode,
              onSearchCommitted: controller.setSearch,
              onWarehouseChanged: controller.setWarehouseId,
              onLowStockChanged: controller.setLowStockOnly,
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Expanded(
              child: AppStateView.empty(
                icon: Icons.filter_alt_off_outlined,
                message: l10n.inventoryBalancesEmpty,
              ),
            )
          else ...[
            _SummaryBar(rows: filtered, l10n: l10n),
            const SizedBox(height: 12),
            Expanded(
              child: AppTableFrame(
                child: InventoryBalanceTable(
                  rows: filtered,
                  languageCode: languageCode,
                ),
              ),
            ),
          ],
          if (canCreateMovements ||
              canViewMovements ||
              canViewFinancialDocuments) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (canViewFinancialDocuments)
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.inventoryDocuments),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(l10n.inventoryDocumentsLink),
                  ),
                if (canCreateMovements)
                  FilledButton.icon(
                    onPressed: () => _openManualAdjustment(
                      context,
                      ref,
                      languageCode,
                      warehouseId: state.warehouseId,
                    ),
                    icon: const Icon(Icons.tune),
                    label: Text(l10n.inventoryManualAdjustment),
                  ),
                if (canCreateMovements)
                  TextButton.icon(
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
    }

    return AppShell(
      title: l10n.inventory,
      currentRoute: AppRoutes.inventory,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Padding(padding: const EdgeInsetsDirectional.all(24), child: body),
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

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.rows, required this.l10n});

  final List<InventoryBalanceRow> rows;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    var available = Decimal.zero;
    var rented = Decimal.zero;
    var trial = Decimal.zero;
    var maintenance = Decimal.zero;
    var damaged = Decimal.zero;
    for (final row in rows) {
      available += row.qtyAvailable;
      rented += row.qtyRented;
      trial += row.qtyTrial;
      maintenance += row.qtyMaintenance;
      damaged += row.qtyDamaged;
    }

    return Text(
      '${l10n.inventoryBalancesSummaryTotal}: '
      '${l10n.inventoryBalanceAvailable} ${formatQuantity(available)}, '
      '${l10n.inventoryBalanceRented} ${formatQuantity(rented)}, '
      '${l10n.inventoryBalanceTrial} ${formatQuantity(trial)}, '
      '${l10n.inventoryBalanceMaintenance} ${formatQuantity(maintenance)}, '
      '${l10n.inventoryBalanceDamaged} ${formatQuantity(damaged)}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

Future<void> _openManualAdjustment(
  BuildContext context,
  WidgetRef ref,
  String languageCode, {
  String? warehouseId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final success = await showInventoryAdjustmentDialog(
    context: context,
    ref: ref,
    languageCode: languageCode,
    prefillWarehouseId: warehouseId,
  );
  if (success == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.inventoryAdjustmentSuccess)));
  }
}
