import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_filter_bar.dart';
import '../../../shared/widgets/app_state_view.dart';
import '../../../shared/widgets/app_table_frame.dart';
import '../../../shared/widgets/app_lifecycle_action_dialog.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/supplier.dart';
import '../domain/supplier_permissions.dart';
import 'supplier_error_messages.dart';
import 'supplier_list_controller.dart';
import 'widgets/supplier_filters_bar.dart';
import 'widgets/supplier_form_dialog.dart';
import 'widgets/supplier_table.dart';

/// Suppliers tab content: filters, create action, list/loading/error/empty.
class SuppliersTabBody extends ConsumerWidget {
  const SuppliersTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(supplierListControllerProvider);
    final controller = ref.read(supplierListControllerProvider.notifier);

    final canCreate = session != null && canCreateSupplier(session);
    final canEdit = session != null && canEditSupplier(session);
    final canDeactivate = session != null && canDeactivateSupplier(session);

    Widget body;
    if (state.isLoading && state.suppliers.isEmpty) {
      body = AppStateView.loading(message: l10n.loading);
    } else if (state.hasError && state.suppliers.isEmpty) {
      body = AppStateView.error(
        message: supplierErrorMessage(l10n, state.errorCode!),
        action: FilledButton(
          onPressed: controller.refresh,
          child: Text(l10n.retry),
        ),
      );
    } else if (!state.isLoading && state.suppliers.isEmpty) {
      body = AppStateView.empty(
        icon: Icons.local_shipping_outlined,
        message: state.filters.hasNonDefaultFilters
            ? l10n.supplierListEmptyFiltered
            : l10n.supplierListEmpty,
      );
    } else {
      body = Column(
        children: [
          Expanded(
            child: AppTableFrame(
              child: SupplierTable(
                suppliers: state.suppliers,
                languageCode: languageCode,
                canEdit: canEdit,
                canDeactivate: canDeactivate,
                onView: (supplier) =>
                    context.go(AppRoutes.supplierDetailPath(supplier.id)),
                onEdit: (supplier) =>
                    _showFormDialog(context, ref, initial: supplier),
                onDeactivate: (supplier) =>
                    _confirmDeactivate(context, ref, supplier),
              ),
            ),
          ),
          if (state.loadMoreErrorCode != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 12),
              child: Text(
                supplierErrorMessage(l10n, state.loadMoreErrorCode!),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.hasMore ||
              state.isLoadingMore ||
              state.loadMoreErrorCode != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 12),
              child: OutlinedButton.icon(
                key: const Key('supplier-load-more'),
                onPressed: state.isLoadingMore ? null : controller.loadMore,
                icon: state.isLoadingMore
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(
                  state.loadMoreErrorCode == null ? l10n.loadMore : l10n.retry,
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      key: const Key('suppliers-tab-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: AppFilterBar(
            compact: true,
            trailing: canCreate
                ? FilledButton.icon(
                    key: const Key('supplier-create-button'),
                    onPressed: () => _showFormDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.supplierAdd),
                  )
                : null,
            child: SupplierFiltersBar(
              filters: state.filters,
              onSearchSubmitted: controller.setSearch,
              onActiveChanged: controller.setIsActive,
              onClear: controller.clearFilters,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                child: body,
              ),
              if (state.isLoading && state.suppliers.isNotEmpty)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _showFormDialog(
    BuildContext context,
    WidgetRef ref, {
    Supplier? initial,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    final isCreate = initial == null;
    if (isCreate && !canCreateSupplier(session)) return;
    if (!isCreate && !canEditSupplier(session)) return;

    await showDialog<void>(
      context: context,
      builder: (_) => SupplierFormDialog(initial: initial),
    );
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    Supplier supplier,
  ) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canDeactivateSupplier(session)) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppLifecycleActionDialog(
      context: context,
      title: l10n.supplierDeactivateConfirmTitle,
      consequence: l10n.supplierDeactivateConfirmBody,
      confirmLabel: l10n.supplierActionDeactivate,
    );
    if (confirmed == null || !context.mounted) return;

    final errorCode = await ref
        .read(supplierListControllerProvider.notifier)
        .deactivateSupplier(supplier.id);

    if (!context.mounted) return;
    final messageL10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorCode == null
              ? messageL10n.supplierDeactivated
              : supplierErrorMessage(messageL10n, errorCode),
        ),
      ),
    );
  }
}
