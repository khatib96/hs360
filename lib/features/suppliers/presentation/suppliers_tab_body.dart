import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
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
    } else if (state.hasError && state.suppliers.isEmpty) {
      body = _ErrorState(
        message: supplierErrorMessage(l10n, state.errorCode!),
        onRetry: controller.refresh,
      );
    } else if (!state.isLoading && state.suppliers.isEmpty) {
      body = _EmptyState(
        isFiltered: state.filters.hasNonDefaultFilters,
        canCreate: canCreate,
      );
    } else {
      body = SupplierTable(
        suppliers: state.suppliers,
        languageCode: languageCode,
        canEdit: canEdit,
        canDeactivate: canDeactivate,
        onView: (supplier) =>
            context.go(AppRoutes.supplierDetailPath(supplier.id)),
        onEdit: (supplier) => _showFormDialog(context, ref, initial: supplier),
        onDeactivate: (supplier) => _confirmDeactivate(context, ref, supplier),
      );
    }

    return Column(
      key: const Key('suppliers-tab-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Row(
            children: [
              Expanded(
                child: SupplierFiltersBar(
                  filters: state.filters,
                  onSearchSubmitted: controller.setSearch,
                  onActiveChanged: controller.setIsActive,
                  onClear: controller.clearFilters,
                ),
              ),
              if (canCreate) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('supplier-create-button'),
                  onPressed: () => _showFormDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.supplierAdd),
                ),
              ],
            ],
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.supplierDeactivateConfirmTitle),
        content: Text(l10n.supplierDeactivateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.supplierActionDeactivate),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFiltered, required this.canCreate});

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
            Icons.local_shipping_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? l10n.supplierListEmptyFiltered
                : l10n.supplierListEmpty,
          ),
          if (canCreate && !isFiltered) ...[
            const SizedBox(height: 8),
            Text(l10n.supplierAdd, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
