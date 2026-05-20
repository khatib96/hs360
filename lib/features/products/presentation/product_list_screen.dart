import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/products_exception.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/product_cost_access.dart';
import '../domain/product_group.dart';
import 'product_display_helpers.dart';
import 'product_list_controller.dart';
import 'product_list_permissions.dart';
import 'product_list_state.dart';
import 'widgets/product_filters_bar.dart';
import 'widgets/product_group_form_dialog.dart';
import 'widgets/product_group_panel.dart';
import 'widgets/product_list_empty_state.dart';
import 'widgets/product_list_error_state.dart';
import 'widgets/product_table.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final languageCode = locale.languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final listState = ref.watch(productListControllerProvider);
    final controller = ref.read(productListControllerProvider.notifier);

    final canViewCosts =
        session != null && canViewFullProductCosts(session);
    final canViewStock =
        session != null && canViewProductStock(session);
    final canViewGroups =
        session != null && canViewProductGroups(session);
    final showNewProductAction =
        session != null && canCreateProduct(session);
    final canCreateGroup =
        session != null && canCreateProductGroup(session);
    final canEditGroup =
        session != null && canEditProductGroup(session);

    final groupsById = {
      for (final g in listState.groups) g.id: g,
    };

    String groupLabelFor(String groupId) {
      if (!canViewGroups) return l10n.productsGroupUnavailable;
      final group = groupsById[groupId];
      if (group == null) return l10n.productsGroupUnavailable;
      return localizedGroupName(group, languageCode);
    }

    final isWide = MediaQuery.sizeOf(context).width > 768;

    Widget body;
    if (listState.isLoading && listState.products.isEmpty) {
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
    } else if (listState.hasError && listState.products.isEmpty) {
      body = ProductListErrorState(
        message: _errorMessage(l10n, listState.errorCode),
        onRetry: controller.refresh,
      );
    } else if (!listState.isLoading && listState.products.isEmpty) {
      body = ProductListEmptyState(canCreateProduct: showNewProductAction);
    } else {
      body = _ProductListBody(
        listState: listState,
        isWide: isWide,
        canViewGroups: canViewGroups,
        canViewStock: canViewStock,
        canCreateGroup: canCreateGroup,
        canEditGroup: canEditGroup,
        languageCode: languageCode,
        groupLabelFor: groupLabelFor,
        canViewCosts: canViewCosts,
        onGroupSelected: controller.setGroupId,
        onAddGroup: () => _showGroupDialog(context, ref, languageCode),
        onEditGroup: (group) => _showGroupDialog(
          context,
          ref,
          languageCode,
          initial: group,
        ),
        onDeactivateGroup: (group) => _confirmDeactivateGroup(
          context,
          ref,
          group,
        ),
      );
    }

    return AppShell(
      title: l10n.products,
      currentRoute: AppRoutes.products,
      actions: [
        if (showNewProductAction)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.productsNew,
            onPressed: () => context.go(AppRoutes.productsNew),
          ),
      ],
      body: SizedBox.expand(
        child: Stack(
          children: [
            body,
            if (listState.isLoading && listState.products.isNotEmpty)
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

  String _errorMessage(AppLocalizations l10n, String? code) {
    if (code == ProductsException.supabaseNotConfigured) {
      return l10n.authErrorSupabaseNotConfigured;
    }
    return l10n.productsListError;
  }

  Future<void> _showGroupDialog(
    BuildContext context,
    WidgetRef ref,
    String languageCode, {
    ProductGroup? initial,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    final canCreate = canCreateProductGroup(session);
    final canEdit = canEditProductGroup(session);
    if (initial == null && !canCreate) return;
    if (initial != null && !canEdit) return;

    final listState = ref.read(productListControllerProvider);
    final result = await showDialog<ProductGroupFormState>(
      context: context,
      builder: (context) => ProductGroupFormDialog(
        groups: listState.groups,
        languageCode: languageCode,
        initial: initial,
        excludeGroupId: initial?.id,
      ),
    );

    if (result == null || !context.mounted) return;

    final controller = ref.read(productListControllerProvider.notifier);
    if (initial == null) {
      await controller.createGroup(result);
    } else {
      await controller.updateGroup(initial.id, result);
    }
  }

  Future<void> _confirmDeactivateGroup(
    BuildContext context,
    WidgetRef ref,
    ProductGroup group,
  ) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canEditProductGroup(session)) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.productGroupDeactivate),
        content: Text(l10n.productGroupDeactivateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.productGroupDeactivate),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(productListControllerProvider.notifier).deactivateGroup(
            group.id,
          );
    }
  }
}

class _ProductListBody extends ConsumerWidget {
  const _ProductListBody({
    required this.listState,
    required this.isWide,
    required this.canViewGroups,
    required this.canViewStock,
    required this.canCreateGroup,
    required this.canEditGroup,
    required this.languageCode,
    required this.groupLabelFor,
    required this.canViewCosts,
    required this.onGroupSelected,
    required this.onAddGroup,
    required this.onEditGroup,
    required this.onDeactivateGroup,
  });

  final ProductListState listState;
  final bool isWide;
  final bool canViewGroups;
  final bool canViewStock;
  final bool canCreateGroup;
  final bool canEditGroup;
  final String languageCode;
  final String Function(String groupId) groupLabelFor;
  final bool canViewCosts;
  final ValueChanged<String?> onGroupSelected;
  final VoidCallback onAddGroup;
  final ValueChanged<ProductGroup> onEditGroup;
  final ValueChanged<ProductGroup> onDeactivateGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(productListControllerProvider.notifier);

    final listContent = Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isWide && canViewGroups)
            ProductGroupPanelCompact(
              groups: listState.groups,
              selectedGroupId: listState.filters.groupId,
              languageCode: languageCode,
              canCreateGroup: canCreateGroup,
              canEditGroup: canEditGroup,
              onGroupSelected: onGroupSelected,
              onAddGroup: onAddGroup,
              onEditGroup: onEditGroup,
              onDeactivateGroup: onDeactivateGroup,
            ),
          if (!isWide && canViewGroups) const SizedBox(height: 8),
          ProductFiltersBar(
            filters: listState.filters,
            canViewStock: canViewStock,
            canViewGroups: canViewGroups,
            groups: listState.groups,
            languageCode: languageCode,
            onSearchCommitted: controller.setSearch,
            onTypeChanged: controller.setProductType,
            onActiveChanged: controller.setIsActive,
            onStockFilterChanged: controller.setStockFilter,
            onClearFilters: controller.clearFilters,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ProductTable(
              products: listState.products,
              stockByProductId: listState.stockByProductId,
              groupLabelFor: groupLabelFor,
              canViewCosts: canViewCosts,
              canViewStock: canViewStock,
              languageCode: languageCode,
            ),
          ),
        ],
      ),
    );

    if (!canViewGroups || !isWide) {
      return SizedBox.expand(child: listContent);
    }

    return SizedBox.expand(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProductGroupPanel(
            groups: listState.groups,
            selectedGroupId: listState.filters.groupId,
            languageCode: languageCode,
            canCreateGroup: canCreateGroup,
            canEditGroup: canEditGroup,
            onGroupSelected: onGroupSelected,
            onAddGroup: onAddGroup,
            onEditGroup: onEditGroup,
            onDeactivateGroup: onDeactivateGroup,
          ),
          Expanded(child: listContent),
        ],
      ),
    );
  }
}
