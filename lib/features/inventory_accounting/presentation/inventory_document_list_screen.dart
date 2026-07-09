import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../../inventory/data/warehouse_repository.dart';
import '../domain/inventory_document_permissions.dart';
import 'inventory_document_list_controller.dart';
import 'widgets/inventory_document_filters_bar.dart';
import 'widgets/inventory_document_shared_widgets.dart';
import 'widgets/inventory_document_table.dart';

class InventoryDocumentListScreen extends ConsumerWidget {
  const InventoryDocumentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(inventoryDocumentListControllerProvider);
    final controller = ref.read(
      inventoryDocumentListControllerProvider.notifier,
    );

    if (session != null && !canViewInventoryDocuments(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.inventoryDocumentsTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.inventoryDocuments,
      );
    }

    final warehousesAsync = ref.watch(_warehousesProvider);
    final warehouses = warehousesAsync.valueOrNull ?? const [];

    Widget body;
    if (state.isLoading && state.documents.isEmpty) {
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
    } else if (state.hasError && state.documents.isEmpty) {
      body = InventoryDocumentErrorState(
        message: inventoryDocumentErrorMessage(l10n, state.errorCode!),
        onRetry: controller.refresh,
      );
    } else if (!state.isLoading && state.documents.isEmpty) {
      body = Center(
        child: Text(
          state.filters.hasActiveFilters
              ? l10n.inventoryDocumentListEmptyFiltered
              : l10n.inventoryDocumentListEmpty,
        ),
      );
    } else {
      final isWide = MediaQuery.sizeOf(context).width > 768;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InventoryDocumentFiltersBar(
            filters: state.filters,
            warehouses: warehouses,
            onKindChanged: (kind) => controller.setFilters(
              state.filters.copyWith(kind: kind, clearKind: kind == null),
            ),
            onWarehouseChanged: (warehouseId) => controller.setFilters(
              state.filters.copyWith(
                warehouseId: warehouseId,
                clearWarehouse: warehouseId == null,
              ),
            ),
            onDateFromChanged: (from) => controller.setFilters(
              state.filters.copyWith(
                dateRange: state.filters.dateRange.copyWith(from: from),
              ),
            ),
            onDateToChanged: (to) => controller.setFilters(
              state.filters.copyWith(
                dateRange: state.filters.dateRange.copyWith(to: to),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isWide
                ? InventoryDocumentTable(
                    documents: state.documents,
                    languageCode: locale.languageCode,
                  )
                : InventoryDocumentCardList(
                    documents: state.documents,
                    languageCode: locale.languageCode,
                  ),
          ),
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: state.isLoadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: OutlinedButton(
                        onPressed: controller.loadMore,
                        child: Text(l10n.loadMore),
                      ),
                    ),
            ),
        ],
      );
    }

    final actions = <Widget>[];
    if (session != null) {
      final createActions = <({String label, String route})>[];
      if (canCreateOpeningStock(session)) {
        createActions.add((
          label: l10n.inventoryDocumentCreateOpening,
          route: AppRoutes.inventoryDocumentsOpeningStock,
        ));
      }
      if (canCreateInventoryAdjustment(session)) {
        createActions.add((
          label: l10n.inventoryDocumentCreateStockIn,
          route: AppRoutes.inventoryDocumentsStockIn,
        ));
        createActions.add((
          label: l10n.inventoryDocumentCreateStockOut,
          route: AppRoutes.inventoryDocumentsStockOut,
        ));
      }
      if (canCreateStockCount(session)) {
        createActions.add((
          label: l10n.inventoryDocumentCreateStockCount,
          route: AppRoutes.inventoryDocumentsStockCount,
        ));
      }

      if (createActions.isNotEmpty) {
        final isWide = MediaQuery.sizeOf(context).width > 768;
        if (isWide) {
          actions.addAll(
            createActions.map(
              (action) => TextButton(
                onPressed: () => context.go(action.route),
                child: Text(action.label),
              ),
            ),
          );
        } else {
          actions.add(
            PopupMenuButton<String>(
              onSelected: context.go,
              itemBuilder: (context) => [
                for (final action in createActions)
                  PopupMenuItem(value: action.route, child: Text(action.label)),
              ],
            ),
          );
        }
      }
    }

    return AppShell(
      title: l10n.inventoryDocumentsTitle,
      currentRoute: AppRoutes.inventoryDocuments,
      actions: actions.isEmpty ? null : actions,
      body: Stack(
        children: [
          Padding(padding: const EdgeInsetsDirectional.all(24), child: body),
          if (state.isLoading && state.documents.isNotEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

final _warehousesProvider = FutureProvider((ref) async {
  return ref
      .read(warehouseRepositoryProvider)
      .fetchWarehouses(activeOnly: true);
});
